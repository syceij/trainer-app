import Foundation

// MARK: - Leaderboard data

/// Cached leaderboard score blob stored in `profiles.leaderboard_data` (jsonb).
/// Mirrors the shape `calculateLeaderboardScore` returns in src/lib/db.js.
struct LeaderboardData: Codable, Hashable {
    var score: Int
    var setsCompleted: Int
    var setsProgrammed: Int
    var improvementPct: Int
    var month: String        // "YYYY-MM"
    var updatedAt: String?   // ISO timestamp

    enum CodingKeys: String, CodingKey {
        case score, month, updatedAt = "updatedAt"
        case setsCompleted, setsProgrammed, improvementPct
    }

    // Some legacy rows may have snake_case — accept both.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        func int(_ keys: String...) -> Int {
            for k in keys {
                if let v = try? c.decode(Int.self, forKey: AnyKey(k)) { return v }
                if let d = try? c.decode(Double.self, forKey: AnyKey(k)) { return Int(d) }
            }
            return 0
        }
        func str(_ keys: String...) -> String? {
            for k in keys {
                if let v = try? c.decode(String.self, forKey: AnyKey(k)) { return v }
            }
            return nil
        }
        self.score          = int("score")
        self.setsCompleted  = int("setsCompleted", "sets_completed")
        self.setsProgrammed = int("setsProgrammed", "sets_programmed")
        self.improvementPct = int("improvementPct", "improvement_pct")
        self.month          = str("month") ?? ""
        self.updatedAt      = str("updatedAt", "updated_at")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        try c.encode(score,          forKey: AnyKey("score"))
        try c.encode(setsCompleted,  forKey: AnyKey("setsCompleted"))
        try c.encode(setsProgrammed, forKey: AnyKey("setsProgrammed"))
        try c.encode(improvementPct, forKey: AnyKey("improvementPct"))
        try c.encode(month,          forKey: AnyKey("month"))
        if let u = updatedAt { try c.encode(u, forKey: AnyKey("updatedAt")) }
    }

    /// Convenience init for AppState.calculateLeaderboardScore.
    init(score: Int, setsCompleted: Int, setsProgrammed: Int,
         improvementPct: Int, month: String, updatedAt: String?) {
        self.score          = score
        self.setsCompleted  = setsCompleted
        self.setsProgrammed = setsProgrammed
        self.improvementPct = improvementPct
        self.month          = month
        self.updatedAt      = updatedAt
    }

    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ s: String) { self.stringValue = s }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
}

// MARK: - Friend list entry

/// Row returned by `loadFriends` in JS. Decoded straight from the `profiles`
/// select that powers the friends list.
struct FriendListEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String?
    var username: String?
    var avatarURL: String?
    var leaderboardData: LeaderboardData?

    enum CodingKeys: String, CodingKey {
        case id, name, username
        case avatarURL        = "avatar_url"
        case leaderboardData  = "leaderboard_data"
    }
}

// MARK: - Pending friend request

/// Friend request someone has sent TO the current user.
struct PendingRequest: Identifiable, Hashable {
    let friendshipId: UUID
    let userId: UUID
    var name: String
    var username: String?
    var avatarURL: String?
    var id: UUID { friendshipId }
}

// MARK: - User search result

struct UserSearchResult: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String?
    var username: String?
    var avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name, username
        case avatarURL = "avatar_url"
    }
}

// MARK: - Invite link

struct InviteLink: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let code: String
    var expiresAt: Date?
    var used: Bool
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, code, used
        case userId    = "user_id"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }

    init(id: UUID, userId: UUID, code: String, expiresAt: Date?,
         used: Bool, createdAt: Date?) {
        self.id = id; self.userId = userId; self.code = code
        self.expiresAt = expiresAt; self.used = used; self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id        = try c.decode(UUID.self,   forKey: .id)
        self.userId    = try c.decode(UUID.self,   forKey: .userId)
        self.code      = (try? c.decode(String.self, forKey: .code)) ?? ""
        self.used      = (try? c.decode(Bool.self,   forKey: .used)) ?? false
        self.expiresAt = LenientDate.optional(c, .expiresAt)
        self.createdAt = LenientDate.optional(c, .createdAt)
    }
}

// MARK: - Friend session (truncated view for FriendProfilePage)

/// A small projection of `workout_sessions` rows used by FriendProfilePage.
/// Pulled directly from the JSONB `data.exercises` field so we don't need
/// to read individual set rows for a friend.
struct FriendSession: Identifiable, Hashable {
    let id: UUID
    var date: Date
    var name: String
    var exercises: [Exercise]

    /// Total tonnage for the session — the same number that gets
    /// written to the activity_feed row when the session is saved
    /// (see AppState.saveSession's `let volume = sets.reduce…`).
    ///
    /// Formula: Σ weight × reps × sets across non-bodyweight
    /// exercises. Previously this missed the reps multiplier and
    /// returned `weight × sets` only — which is why the friend
    /// profile detail sheet showed 525 while the activity feed
    /// showed 5250 for the exact same session (off by exactly 10×
    /// — the upper bound of the "8-10" rep range).
    ///
    /// Reps are stored as a string ("8-10" / "12" / etc.). We
    /// use the upper bound for the multiplier so the value lines
    /// up with what the user actually logged on a session they
    /// completed at the top of the range, which is the common case.
    /// If the reps string can't be parsed at all (empty / unusual
    /// format), we fall back to 8.
    var volume: Double {
        exercises.reduce(0) { acc, ex in
            if ex.bodyweight { return acc }
            guard let w = ex.weight, w > 0 else { return acc }
            let reps = Self.upperRepCount(ex.reps)
            return acc + w * Double(reps) * Double(max(ex.sets, 1))
        }
    }

    /// Parse the upper end of a rep prescription string.
    ///   "8-10"  → 10
    ///   "12"    → 12
    ///   ""      → 8 (sensible default for hypertrophy)
    ///   "10-12 each side" → 12 (takes the last integer it finds)
    private static func upperRepCount(_ s: String) -> Int {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return 8 }
        // Pull every integer-looking chunk, take the largest.
        // Handles "10", "8-10", "10-12 each side", "AMRAP 8" etc.
        let digitChunks = trimmed
            .split { !$0.isNumber }
            .compactMap { Int($0) }
        return digitChunks.max() ?? 8
    }
}

// MARK: - Leaderboard rendering entry

/// Composed in CrewView to render the leaderboard rows. Wraps a friend (or
/// the current user) with their cached score blob + display fields.
struct LeaderboardEntry: Identifiable, Hashable {
    let id: UUID
    var rank: Int
    var name: String?
    var username: String?
    var avatarURL: String?
    var score: Int
    var setsCompleted: Int
    var improvementPct: Int
    var isMe: Bool
}

// MARK: - Custom exercise

/// User-created exercise. Persisted as a JSON array on `profiles.custom_exercises`.
/// Shape mirrors the React `CustomExercise` shape from src/components/ExercisePickerSheet.jsx.
struct CustomExercise: Codable, Identifiable, Hashable {
    var name: String
    var key: String           // generated from name (slug)
    var muscle: String        // primary muscle slug
    var category: String      // category label (matches picker categories)
    var isCustom: Bool        // always true; preserved so JSON roundtrips cleanly
    var equipment: String     // "custom" by default
    var createdAt: String?

    /// Use the slug-style key for SwiftUI identity.
    var id: String { key }

    init(name: String, muscle: String, category: String) {
        self.name = name
        self.key = "custom_" + name
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        self.muscle = muscle
        self.category = category
        self.isCustom = true
        self.equipment = "custom"
        self.createdAt = ISO8601DateFormatter().string(from: Date())
    }
}

// MARK: - Activity feed enriched row

/// `ActivityFeedItem` plus the attached profile data the React app joins
/// in JavaScript. Used directly by CrewView's activity list.
struct ActivityRow: Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var type: String
    var createdAt: Date
    var data: [String: AnyCodable]?

    var profileName: String?
    var profileUsername: String?
    var avatarURL: String?

    /// Pull a string field out of the embedded `data` jsonb, if present.
    func stringField(_ key: String) -> String? {
        guard let v = data?[key]?.value as? String else { return nil }
        return v
    }
    func doubleField(_ key: String) -> Double? {
        if let d = data?[key]?.value as? Double { return d }
        if let i = data?[key]?.value as? Int    { return Double(i) }
        return nil
    }
}

// MARK: - Leagues

/// A league row from the `leagues` table. Admin-owned, has a free-text
/// name and a set of members joined via `league_members`.
struct League: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var adminId: UUID
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case adminId   = "admin_id"
        case createdAt = "created_at"
    }

    // Custom decoder uses `LenientDate.optional` because Supabase
    // sometimes returns `created_at` in formats the default ISO8601
    // decoder rejects. Matches the pattern other Codable structs in
    // this codebase use (Programme, WorkoutSession, etc.).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id        = try c.decode(UUID.self,   forKey: .id)
        self.name      = try c.decode(String.self, forKey: .name)
        self.adminId   = try c.decode(UUID.self,   forKey: .adminId)
        self.createdAt = LenientDate.optional(c, .createdAt)
    }
}

/// Join-row from `league_members` — combines invite + member states
/// in a single `status` field.
struct LeagueMember: Codable, Hashable {
    let leagueId: UUID
    let userId: UUID
    var role: String          // "admin" | "member"
    var status: String        // "pending" | "accepted" | "declined"
    var invitedBy: UUID?
    var joinedAt: Date?

    enum CodingKeys: String, CodingKey {
        case leagueId   = "league_id"
        case userId     = "user_id"
        case role
        case status
        case invitedBy  = "invited_by"
        case joinedAt   = "joined_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.leagueId  = try c.decode(UUID.self,   forKey: .leagueId)
        self.userId    = try c.decode(UUID.self,   forKey: .userId)
        self.role      = (try? c.decode(String.self, forKey: .role))   ?? "member"
        self.status    = (try? c.decode(String.self, forKey: .status)) ?? "accepted"
        self.invitedBy = try? c.decode(UUID.self, forKey: .invitedBy)
        self.joinedAt  = LenientDate.optional(c, .joinedAt)
    }
}

/// One row rendered in the league leaderboard list — joins the
/// member row to the user's profile (name + avatar + this month's
/// cached score / sets / improvement).
struct LeagueLeaderboardEntry: Identifiable, Hashable {
    let id: UUID              // user id (also row id for SwiftUI lists)
    var rank: Int
    var name: String?
    var username: String?
    var avatarURL: String?
    var score: Int
    /// Sets completed this month — surfaces on the row as "144 sets".
    /// Same source as `score` (the user's cached leaderboard_data).
    var setsCompleted: Int
    /// Average improvement % across tracked lifts this month —
    /// renders as "+54%". Stale-month rows read as 0.
    var improvementPct: Int
    var role: String          // "admin" | "member"
    var status: String        // mostly "accepted" here; included for future invite handling
    var isMe: Bool
}

/// What the leagues-list section in CrewView consumes. Wraps the
/// raw `League` with a precomputed leaderboard so the section can
/// render without a per-card secondary fetch.
struct LeagueWithMembers: Identifiable, Hashable {
    let league: League
    var leaderboard: [LeagueLeaderboardEntry]
    /// Last month's MVP — winner of the previous calendar month.
    /// Ship A leaves this nil (placeholder copy in the UI); Ship B
    /// will compute it from historical snapshots.
    var lastMonthMVP: LeagueLeaderboardEntry?

    var id: UUID { league.id }
}
