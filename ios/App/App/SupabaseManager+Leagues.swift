import Foundation
import Supabase

/// All league-related Supabase queries live here. Mirrors the
/// `+Friends.swift` extension pattern so the main SupabaseManager
/// stays focused on auth + base config.
///
/// Schema (see supabase/migrations/2026-05-17-leagues.sql):
///   • leagues          — id, name, admin_id, created_at
///   • league_members   — league_id, user_id, role, status, invited_by, joined_at
///
/// `status` on league_members is 'pending' / 'accepted' / 'declined' —
/// Ship A adds members instantly with status='accepted' (no separate
/// invite/accept loop). Ship B will introduce a real invite inbox.
extension SupabaseManager {

    // MARK: - List + create

    /// Fetch every league the current user is an ACCEPTED member of,
    /// each pre-bundled with its full leaderboard (member rows
    /// joined to profile + leaderboard_data). One round-trip per
    /// league after the membership list — acceptable for now since
    /// users typically belong to <5 leagues.
    func fetchMyLeagues() async throws -> [LeagueWithMembers] {
        guard let uid = currentUser?.id else { return [] }

        // 1) Get my accepted memberships → list of league IDs
        struct MyMembership: Decodable {
            let leagueId: UUID
            enum CodingKeys: String, CodingKey { case leagueId = "league_id" }
        }
        let memberships: [MyMembership] = try await client
            .from("league_members")
            .select("league_id")
            .eq("user_id", value: uid)
            .eq("status", value: "accepted")
            .execute()
            .value
        let leagueIds = memberships.map(\.leagueId)
        guard !leagueIds.isEmpty else { return [] }

        // 2) Fetch the leagues themselves
        let leagues: [League] = try await client
            .from("leagues")
            .select("id, name, admin_id, created_at")
            .in("id", values: leagueIds)
            .execute()
            .value
        guard !leagues.isEmpty else { return [] }

        // 3) Fetch every member row for those leagues
        let allMembers: [LeagueMember] = try await client
            .from("league_members")
            .select("league_id, user_id, role, status, invited_by, joined_at")
            .in("league_id", values: leagueIds)
            .eq("status", value: "accepted")
            .execute()
            .value
        let memberUserIds = Set(allMembers.map(\.userId))

        // 4) Join to profiles for name / avatar / score
        struct ProfileRow: Decodable {
            let id: UUID
            let name: String?
            let username: String?
            let avatarURL: String?
            let leaderboardData: LeaderboardData?
            enum CodingKeys: String, CodingKey {
                case id, name, username
                case avatarURL       = "avatar_url"
                case leaderboardData = "leaderboard_data"
            }
        }
        let profiles: [ProfileRow] = memberUserIds.isEmpty ? [] : try await client
            .from("profiles")
            .select("id, name, username, avatar_url, leaderboard_data")
            .in("id", values: Array(memberUserIds))
            .execute()
            .value
        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        // 5) Build the LeagueWithMembers payload per league. Score
        //    sort uses the current month's cached leaderboard_data;
        //    stale rows (wrong month) read as 0 — same defensive
        //    treatment AppState.rebuildLeaderboard already uses.
        let monthKey: String = {
            let cal = Calendar(identifier: .gregorian)
            let comps = cal.dateComponents([.year, .month], from: Date())
            return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
        }()

        return leagues.map { league in
            let members = allMembers.filter { $0.leagueId == league.id }
            let rows: [LeagueLeaderboardEntry] = members.map { m in
                let p = profileMap[m.userId]
                // Only read the cached leaderboard blob when it's for
                // the current month — stale rows from past months
                // would otherwise inflate the leaderboard with
                // outdated numbers.
                let ld    = (p?.leaderboardData?.month == monthKey) ? p?.leaderboardData : nil
                let score = ld?.score          ?? 0
                let sets  = ld?.setsCompleted  ?? 0
                let imp   = ld?.improvementPct ?? 0
                return LeagueLeaderboardEntry(
                    id:             m.userId,
                    rank:           0,
                    name:           p?.name,
                    username:       p?.username,
                    avatarURL:      p?.avatarURL,
                    score:          score,
                    setsCompleted:  sets,
                    improvementPct: imp,
                    role:           m.role,
                    status:         m.status,
                    isMe:           m.userId == uid
                )
            }
            // Sort by score desc; ties broken by name
            let sorted = rows.sorted { a, b in
                if a.score != b.score { return a.score > b.score }
                return (a.name ?? "").localizedCaseInsensitiveCompare(b.name ?? "") == .orderedAscending
            }
            var ranked = sorted
            for i in ranked.indices { ranked[i].rank = i + 1 }

            return LeagueWithMembers(
                league: league,
                leaderboard: ranked,
                lastMonthMVP: nil  // Ship B will compute this from history
            )
        }
    }

    /// Create a new league and auto-add the creator as the admin
    /// (status: accepted). The two writes happen sequentially —
    /// if the membership insert fails, the league row is left in
    /// the database; the caller can choose to clean up or live with
    /// the orphan (admin can delete later via the leagues UI).
    @discardableResult
    func createLeague(name: String) async throws -> League {
        guard let uid = currentUser?.id else {
            throw NSError(domain: "createLeague", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }

        struct InsertPayload: Encodable {
            let name: String
            let admin_id: UUID
        }
        let inserted: [League] = try await client
            .from("leagues")
            .insert(InsertPayload(name: name.trimmingCharacters(in: .whitespaces),
                                  admin_id: uid))
            .select()
            .execute()
            .value
        guard let league = inserted.first else {
            throw NSError(domain: "createLeague", code: 500,
                          userInfo: [NSLocalizedDescriptionKey: "League row missing from response"])
        }

        // Insert the admin as an accepted member so the leaderboard
        // query can find them. Status is 'accepted' from day one.
        struct AdminInsert: Encodable {
            let league_id: UUID
            let user_id: UUID
            let role: String
            let status: String
            let invited_by: UUID
        }
        _ = try await client
            .from("league_members")
            .insert(AdminInsert(
                league_id: league.id,
                user_id:   uid,
                role:      "admin",
                status:    "accepted",
                invited_by: uid
            ))
            .execute()

        return league
    }

    // MARK: - Add / leave / kick

    /// Admin invites a user to the league. Ship A inserts the row
    /// directly with status='accepted' so the invitee shows up on
    /// the leaderboard immediately. Ship B will change this to
    /// 'pending' + introduce an invite inbox.
    func addLeagueMember(leagueId: UUID, userId: UUID) async throws {
        guard let inviter = currentUser?.id else { return }
        struct Payload: Encodable {
            let league_id: UUID
            let user_id: UUID
            let role: String
            let status: String
            let invited_by: UUID
        }
        _ = try await client
            .from("league_members")
            .insert(Payload(
                league_id: leagueId,
                user_id:   userId,
                role:      "member",
                status:    "accepted",
                invited_by: inviter
            ))
            .execute()
    }

    /// Member leaves a league. Removes their row entirely. If the
    /// caller is the admin, the row deletion succeeds but the
    /// league itself stays — admin needs to explicitly delete the
    /// league via `deleteLeague` to clean up the rest.
    func leaveLeague(leagueId: UUID) async throws {
        guard let uid = currentUser?.id else { return }
        _ = try await client
            .from("league_members")
            .delete()
            .eq("league_id", value: leagueId)
            .eq("user_id", value: uid)
            .execute()
    }

    /// Admin kicks a member. RLS policy allows this only when the
    /// caller is the league's admin.
    func kickLeagueMember(leagueId: UUID, userId: UUID) async throws {
        _ = try await client
            .from("league_members")
            .delete()
            .eq("league_id", value: leagueId)
            .eq("user_id", value: userId)
            .execute()
    }

    /// Admin deletes the league entirely. Cascade on `leagues.id`
    /// wipes all league_members rows too.
    func deleteLeague(leagueId: UUID) async throws {
        _ = try await client
            .from("leagues")
            .delete()
            .eq("id", value: leagueId)
            .execute()
    }
}
