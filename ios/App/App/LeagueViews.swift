import SwiftUI

// MARK: - LEAGUES section card (rendered in CrewView)

/// Compact league card that lives in the Bros tab between the
/// recent-activity list and the bottom of the page. Visual reference
/// is the design the user sent: a tall card with an outlined border
/// in the accent colour, "LEAGUENAME" in bold at top-left, "MVP:
/// (LAST MONTHS WINNER)" on the right, and a numbered list of
/// members ranked by current-month score.
///
/// Tapping the card opens `LeagueDetailView` for the full leaderboard
/// + admin actions.
struct LeagueListCard: View {
    let league: LeagueWithMembers
    let ar: Bool
    var onTap: () -> Void

    /// Card padding budget — leagues now support up to 25 members.
    /// We render the populated leaderboard PLUS empty placeholder
    /// slots up to a stable visible count so the card height stays
    /// predictable. 7 slots fits the "preview" look from the user's
    /// mockup; the full 25 lives in LeagueDetailView.
    private static let previewSlots = 7
    /// Max league size — per user spec, 1 to 25 players.
    static let maxMembers = 25

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            VStack(spacing: 0) {
                // Header row: name + MVP
                HStack(alignment: .firstTextBaseline) {
                    Text(league.league.name.uppercased())
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(HexTheme.text)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(mvpLine)
                        .font(.system(size: 10, weight: .heavy))
                        .kerning(0.6)
                        .foregroundColor(HexTheme.dim)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

                // Outlined inner panel with `previewSlots` ranked rows.
                // The divider sits BETWEEN every adjacent pair of rows
                // (no per-section gap that broke when the populated
                // count crossed a boundary in the old code).
                VStack(spacing: 0) {
                    let preview = Array(league.leaderboard.prefix(Self.previewSlots))
                    let total = Self.previewSlots
                    ForEach(0..<total, id: \.self) { idx in
                        let entry = idx < preview.count ? preview[idx] : nil
                        rankRow(rank: idx + 1, entry: entry)
                        if idx < total - 1 {
                            Rectangle()
                                .fill(HexTheme.accent.opacity(0.35))
                                .frame(height: 1)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .background(HexTheme.bg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(HexTheme.accent, lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(HexTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(HexTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// "MVP : <name>" line above the leaderboard. "MVP" is kept
    /// untranslated in Arabic per user preference (it's a known
    /// acronym in sports contexts globally — translating it loses
    /// the brand feel). Falls back to "—" when last month's winner
    /// hasn't been computed yet (Ship A — needs historical
    /// snapshot infra that lands in a later ship).
    private var mvpLine: String {
        if let mvp = league.lastMonthMVP {
            return "MVP : \(mvp.name ?? "—")"
        }
        return "MVP : —"
    }

    /// One numbered row in the leaderboard panel. `entry == nil`
    /// renders an empty placeholder slot so the card height stays
    /// consistent whether the league has 1 member or 7+.
    private func rankRow(rank: Int, entry: LeagueLeaderboardEntry?) -> some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(HexTheme.text)
                .frame(width: 22, alignment: .leading)
            if let e = entry {
                let initial = String((e.name ?? e.username ?? "?").prefix(1)).uppercased()
                AvatarCircle(
                    initial: initial,
                    url: e.avatarURL,
                    size: 28,
                    ring: HexTheme.border
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(e.name ?? e.username ?? "—")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(HexTheme.text)
                        .lineLimit(1)
                    // Secondary stats: sets + improvement % packed
                    // into one dim line so the card row stays
                    // compact. "144 sets · +54%" reads at a glance
                    // without needing to open the detail page.
                    Text(secondaryLine(for: e))
                        .font(.system(size: 10))
                        .foregroundColor(HexTheme.mute)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(e.score)")
                    .font(.system(size: 13, weight: .heavy).monospacedDigit())
                    .foregroundColor(HexTheme.accent)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "144 sets · +54%" — secondary stats line on each row. The
    /// number agrees with the leaderboard_data blob the user's
    /// score was computed from, so taps that drill into the friend
    /// page show the same numbers in the points card.
    private func secondaryLine(for e: LeagueLeaderboardEntry) -> String {
        let setsLabel = ar ? "\(e.setsCompleted) مجموعة" : "\(e.setsCompleted) sets"
        let impSign = e.improvementPct >= 0 ? "+" : ""
        return "\(setsLabel) · \(impSign)\(e.improvementPct)%"
    }
}

// MARK: - League detail view (full page)

/// Opened when the user taps a league card in the Bros tab. Shows
/// the same leaderboard at full size + admin controls (add member,
/// kick, delete league) when the signed-in user is the admin.
struct LeagueDetailView: View {
    let league: LeagueWithMembers
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showInviteSheet = false
    @State private var confirmLeave = false
    @State private var confirmDelete = false
    @State private var memberToKick: LeagueLeaderboardEntry?
    @State private var busy = false
    /// Tapped row → navigates into the friend-profile page for that
    /// member. Reuses FriendProfilePage with a synthetic
    /// FriendListEntry so we don't need a separate "public profile"
    /// view; FriendProfilePage already hides the Remove button when
    /// the user isn't actually a friend (see header rewrite below).
    @State private var memberProfileDestination: FriendListEntry?

    private var ar: Bool { app.language == "ar" }
    private var isAdmin: Bool {
        league.league.adminId == app.currentProfile?.id
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header — league name big + MVP line
                VStack(alignment: .leading, spacing: 6) {
                    Text(league.league.name.uppercased())
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(HexTheme.text)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(HexTheme.accent)
                        Text(mvpLine)
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(HexTheme.dim)
                    }
                }
                .padding(.top, 8)

                // Admin-only quick action: invite member
                if isAdmin {
                    Button {
                        showInviteSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 14, weight: .heavy))
                            Text(ar ? "إضافة لاعب" : "Add member")
                                .font(.system(size: 14, weight: .heavy))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(HexTheme.accentFill)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Full leaderboard
                leaderboardCard

                // Bottom danger zone — leave or delete
                bottomActions
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 60)
        }
        .background(HexTheme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(ar ? "الدوري" : "League")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(HexTheme.text)
            }
            // Custom topBarLeading back-button removed — NavigationStack
            // provides one already, and stacking ours on top caused the
            // double-chevron the user spotted in the screenshot.
        }
        .sheet(isPresented: $showInviteSheet) {
            LeagueInviteSheet(leagueId: league.league.id,
                              existingMemberIds: Set(league.leaderboard.map(\.id)),
                              ar: ar)
        }
        // Navigate into a member's profile when their row is tapped.
        // Uses an item-binding so the same navigation works for any
        // entry; FriendProfilePage already hides admin actions
        // (Remove button) for non-friends.
        .navigationDestination(
            isPresented: Binding(
                get: { memberProfileDestination != nil },
                set: { if !$0 { memberProfileDestination = nil } }
            )
        ) {
            if let friend = memberProfileDestination {
                FriendProfilePage(friend: friend)
                    .environmentObject(app)
            }
        }
        .confirmationDialog(
            ar ? "مغادرة الدوري؟" : "Leave league?",
            isPresented: $confirmLeave,
            titleVisibility: .visible
        ) {
            Button(ar ? "مغادرة" : "Leave", role: .destructive) {
                Task { await leave() }
            }
            Button(ar ? "إلغاء" : "Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            ar ? "حذف الدوري؟" : "Delete league?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button(ar ? "حذف" : "Delete", role: .destructive) {
                Task { await deleteLeague() }
            }
            Button(ar ? "إلغاء" : "Cancel", role: .cancel) {}
        } message: {
            Text(ar
                 ? "سيتم إزالة جميع الأعضاء — لا يمكن التراجع."
                 : "Every member will be removed. This can't be undone.")
        }
        .confirmationDialog(
            ar ? "طرد العضو؟" : "Kick member?",
            isPresented: Binding(
                get: { memberToKick != nil },
                set: { if !$0 { memberToKick = nil } }
            ),
            titleVisibility: .visible,
            presenting: memberToKick
        ) { member in
            Button(ar ? "طرد" : "Kick", role: .destructive) {
                Task { await kick(member) }
            }
            Button(ar ? "إلغاء" : "Cancel", role: .cancel) {
                memberToKick = nil
            }
        } message: { member in
            Text(ar
                 ? "إزالة \(member.name ?? "—") من الدوري"
                 : "Remove \(member.name ?? "—") from the league")
        }
    }

    /// "MVP last month : <name>" — top of LeagueDetailView under the
    /// big title. Keeps "MVP" untranslated even in Arabic (same
    /// convention as the card; the acronym is recognized globally
    /// and translating loses brand feel). Falls back to "—" until
    /// the historical-snapshot computation lands.
    private var mvpLine: String {
        let prefix = ar ? "MVP الشهر السابق" : "MVP last month"
        if let mvp = league.lastMonthMVP {
            return "\(prefix) : \(mvp.name ?? "—")"
        }
        return "\(prefix) : —"
    }

    /// Full-width outlined leaderboard card.
    private var leaderboardCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(league.leaderboard.enumerated()), id: \.element.id) { idx, entry in
                row(rank: idx + 1, entry: entry)
                if idx < league.leaderboard.count - 1 {
                    Rectangle()
                        .fill(HexTheme.accent.opacity(0.35))
                        .frame(height: 1)
                }
            }
            if league.leaderboard.isEmpty {
                Text(ar ? "لا يوجد أعضاء بعد" : "No members yet")
                    .font(.system(size: 13))
                    .foregroundColor(HexTheme.mute)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity)
            }
        }
        .background(HexTheme.bg)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HexTheme.accent, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func row(rank: Int, entry: LeagueLeaderboardEntry) -> some View {
        let initial = String((entry.name ?? entry.username ?? "?").prefix(1)).uppercased()
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            // Tap → push the friend-profile page for this member.
            // We synthesise a FriendListEntry from the leaderboard
            // row so FriendProfilePage works for non-friends too.
            // The "self" row is skipped — your own profile is the
            // Profile tab, no point opening it from here.
            guard !entry.isMe else { return }
            memberProfileDestination = FriendListEntry(
                id: entry.id,
                name: entry.name,
                username: entry.username,
                avatarURL: entry.avatarURL,
                leaderboardData: nil
            )
        } label: {
            HStack(spacing: 12) {
                Text("\(rank)")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(HexTheme.text)
                    .frame(width: 26, alignment: .leading)

                AvatarCircle(
                    initial: initial,
                    url: entry.avatarURL,
                    size: 36,
                    ring: HexTheme.border
                )

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(entry.name ?? entry.username ?? "—")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(HexTheme.text)
                            .lineLimit(1)
                        if entry.role == "admin" {
                            Text(ar ? "مسؤول" : "admin")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(HexTheme.accent)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(HexTheme.accent.opacity(0.12))
                                )
                        }
                        if entry.isMe {
                            Text(ar ? "أنت" : "you")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(HexTheme.dim)
                        }
                    }
                    HStack(spacing: 4) {
                        if let u = entry.username {
                            Text("@\(u)")
                                .font(.system(size: 11))
                                .foregroundColor(HexTheme.mute)
                            Text("·")
                                .font(.system(size: 11))
                                .foregroundColor(HexTheme.mute)
                        }
                        // Sets + improvement — same numbers the
                        // points card on the user's own profile
                        // shows. "144 sets · +54%".
                        Text(detailSecondaryLine(for: entry))
                            .font(.system(size: 11))
                            .foregroundColor(HexTheme.dim)
                            .lineLimit(1)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(entry.score)")
                        .font(.system(size: 16, weight: .heavy).monospacedDigit())
                        .foregroundColor(HexTheme.accent)
                    Text(ar ? "نقطة" : "pts")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(HexTheme.mute)
                }
                if isAdmin && !entry.isMe {
                    Button {
                        memberToKick = entry
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(HexTheme.danger)
                            .padding(7)
                            .background(Circle().fill(HexTheme.danger.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var bottomActions: some View {
        if isAdmin {
            Button { confirmDelete = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .heavy))
                    Text(ar ? "حذف الدوري" : "Delete league")
                        .font(.system(size: 13, weight: .heavy))
                }
                .foregroundColor(HexTheme.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(HexTheme.danger.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(HexTheme.danger.opacity(0.30), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        } else {
            Button { confirmLeave = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 13, weight: .heavy))
                    Text(ar ? "مغادرة الدوري" : "Leave league")
                        .font(.system(size: 13, weight: .heavy))
                }
                .foregroundColor(HexTheme.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(HexTheme.danger.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(HexTheme.danger.opacity(0.30), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
    }

    /// "144 sets · +54%" formatter — bilingual, signed.
    private func detailSecondaryLine(for e: LeagueLeaderboardEntry) -> String {
        let setsLabel = ar ? "\(e.setsCompleted) مجموعة" : "\(e.setsCompleted) sets"
        let impSign = e.improvementPct >= 0 ? "+" : ""
        return "\(setsLabel) · \(impSign)\(e.improvementPct)%"
    }

    // MARK: - Mutation handlers

    private func leave() async {
        busy = true
        defer { busy = false }
        do {
            try await SupabaseManager.shared.leaveLeague(leagueId: league.league.id)
            await app.loadLeagues()
            app.toast = ar ? "تمت المغادرة" : "Left league"
            await MainActor.run { dismiss() }
        } catch {
            print("[LeagueDetail] leave failed:", error)
            app.toast = ar ? "تعذّر المغادرة" : "Couldn't leave"
        }
    }

    private func deleteLeague() async {
        busy = true
        defer { busy = false }
        do {
            try await SupabaseManager.shared.deleteLeague(leagueId: league.league.id)
            await app.loadLeagues()
            app.toast = ar ? "تم حذف الدوري" : "League deleted"
            await MainActor.run { dismiss() }
        } catch {
            print("[LeagueDetail] delete failed:", error)
            app.toast = ar ? "تعذّر الحذف" : "Couldn't delete"
        }
    }

    private func kick(_ member: LeagueLeaderboardEntry) async {
        busy = true
        defer { busy = false }
        do {
            try await SupabaseManager.shared.kickLeagueMember(
                leagueId: league.league.id,
                userId: member.id
            )
            await app.loadLeagues()
            app.toast = ar ? "تم الطرد" : "Kicked"
        } catch {
            print("[LeagueDetail] kick failed:", error)
            app.toast = ar ? "تعذّر الطرد" : "Couldn't kick"
        }
        memberToKick = nil
    }
}

// MARK: - Create league sheet

/// Modal that drops over the Bros tab when the user taps the
/// "Create league" button. Single text field for the league name,
/// confirm button creates the league + auto-adds the user as admin.
struct CreateLeagueSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool

    @State private var name: String = ""
    @State private var saving = false

    private var ar: Bool { app.language == "ar" }
    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !saving
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(ar
                     ? "اختر اسماً للدوري الجديد. يمكنك دعوة الأعضاء بعد الإنشاء."
                     : "Name your new league. You can invite members after creating it.")
                    .font(.system(size: 13))
                    .foregroundColor(HexTheme.dim)
                    .lineSpacing(3)
                    .padding(.top, 4)

                TextField("",
                          text: $name,
                          prompt: Text(ar ? "اسم الدوري" : "League name")
                            .foregroundColor(HexTheme.mute))
                    .font(.system(size: 16))
                    .foregroundColor(HexTheme.text)
                    .textInputAutocapitalization(.words)
                    .focused($nameFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(HexTheme.surface2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(HexTheme.border, lineWidth: 1.5)
                    )

                Button {
                    Task { await create() }
                } label: {
                    HStack {
                        if saving {
                            ProgressView().tint(.black).scaleEffect(0.85)
                        } else {
                            Text(ar ? "إنشاء" : "Create")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundColor(canCreate ? .black : HexTheme.mute)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(canCreate ? HexTheme.accentFill : AnyShapeStyle(HexTheme.surface2))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canCreate)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .background(HexTheme.bg.ignoresSafeArea())
            .navigationTitle(ar ? "دوري جديد" : "New league")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(ar ? "إلغاء" : "Cancel") { dismiss() }
                        .foregroundColor(HexTheme.accent)
                }
            }
            .onAppear { nameFocused = true }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    @MainActor
    private func create() async {
        saving = true
        defer { saving = false }
        do {
            _ = try await SupabaseManager.shared.createLeague(name: name)
            await app.loadLeagues()
            app.toast = ar ? "تم إنشاء الدوري ✓" : "League created ✓"
            dismiss()
        } catch {
            // Surface the actual error message so we can diagnose
            // when the create call fails — was hitting a generic
            // "Couldn't create" toast with the root cause buried in
            // Xcode logs the user can't see.
            print("[CreateLeagueSheet] failed:", error)
            let msg = (error as NSError).localizedDescription
            app.toast = ar
                ? "تعذّر الإنشاء: \(msg)"
                : "Create failed: \(msg)"
        }
    }
}

// MARK: - Invite member sheet

/// Admin-only — search users by username and tap to add them. Reuses
/// the existing `searchUsers(query:)` API. Members already in the
/// league are visually marked and tap is a no-op for them.
struct LeagueInviteSheet: View {
    let leagueId: UUID
    let existingMemberIds: Set<UUID>
    let ar: Bool

    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused: Bool

    @State private var query: String = ""
    @State private var results: [UserSearchResult] = []
    @State private var searching = false
    @State private var addingId: UUID?
    @State private var addedIds: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    // Search field
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(HexTheme.dim)
                        TextField(
                            "",
                            text: $query,
                            prompt: Text(ar
                                         ? "ابحث باسم المستخدم"
                                         : "Search by username")
                                .foregroundColor(HexTheme.mute)
                        )
                            .font(.system(size: 16))
                            .foregroundColor(HexTheme.text)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($searchFocused)
                            .onChange(of: query) { _ in
                                Task { await runSearch() }
                            }
                        if searching {
                            ProgressView().scaleEffect(0.6).tint(HexTheme.mute)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(HexTheme.surface2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(HexTheme.border, lineWidth: 1.5)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    if results.isEmpty && !query.isEmpty && !searching {
                        Text(ar ? "لا توجد نتائج" : "No matches")
                            .font(.system(size: 13))
                            .foregroundColor(HexTheme.mute)
                            .padding(.vertical, 28)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(results) { user in
                                resultRow(user)
                                if user.id != results.last?.id {
                                    Rectangle()
                                        .fill(HexTheme.border)
                                        .frame(height: 1)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(HexTheme.surface2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(HexTheme.border, lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                    }
                }
            }
            .background(HexTheme.bg.ignoresSafeArea())
            .navigationTitle(ar ? "دعوة لاعب" : "Invite member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(ar ? "تم" : "Done") { dismiss() }
                        .foregroundColor(HexTheme.accent)
                }
            }
            .onAppear { searchFocused = true }
        }
        .presentationDetents([.large])
    }

    private func resultRow(_ user: UserSearchResult) -> some View {
        let alreadyMember = existingMemberIds.contains(user.id) || addedIds.contains(user.id)
        return Button {
            guard !alreadyMember else { return }
            Task { await add(user) }
        } label: {
            HStack(spacing: 12) {
                AvatarCircle(initial: String((user.name ?? user.username ?? "?").prefix(1)).uppercased(),
                             url: user.avatarURL,
                             size: 36,
                             ring: HexTheme.border)
                VStack(alignment: .leading, spacing: 1) {
                    Text(user.name ?? user.username ?? "—")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(HexTheme.text)
                        .lineLimit(1)
                    if let u = user.username {
                        Text("@\(u)")
                            .font(.system(size: 11))
                            .foregroundColor(HexTheme.mute)
                    }
                }
                Spacer()
                if alreadyMember {
                    Text(ar ? "عضو" : "Member")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(HexTheme.mute)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(HexTheme.surface))
                } else if addingId == user.id {
                    ProgressView().scaleEffect(0.7).tint(HexTheme.accent)
                } else {
                    Text(ar ? "دعوة" : "Invite")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(HexTheme.accent))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(alreadyMember || addingId == user.id)
    }

    @MainActor
    private func runSearch() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else {
            results = []
            return
        }
        searching = true
        defer { searching = false }
        do {
            results = try await SupabaseManager.shared.searchUsers(query: q)
        } catch {
            print("[LeagueInvite] search failed:", error)
            results = []
        }
    }

    @MainActor
    private func add(_ user: UserSearchResult) async {
        addingId = user.id
        defer { addingId = nil }
        do {
            try await SupabaseManager.shared.addLeagueMember(
                leagueId: leagueId,
                userId: user.id
            )
            addedIds.insert(user.id)
            await app.loadLeagues()
            app.toast = ar ? "تمت الإضافة" : "Added"

            // Notify the invitee. Best-effort. Look up the league name
            // from the freshly-reloaded myLeagues — we just inserted as
            // admin so the league is guaranteed in the list.
            let leagueName = app.myLeagues.first { $0.id == leagueId }?.name
                ?? (ar ? "دوريك" : "a league")
            let me = app.currentProfile?.name
                ?? app.currentProfile?.username
                ?? (ar ? "صديقك" : "Someone")
            await SupabaseManager.shared.sendPush(
                toUserIds: [user.id],
                category:  "league_invite",
                title:     ar ? "دعوة لدوري 🏆" : "League invite 🏆",
                body:      ar
                    ? "\(me) دعاك إلى \"\(leagueName)\""
                    : "\(me) invited you to \"\(leagueName)\""
            )
        } catch {
            print("[LeagueInvite] add failed:", error)
            app.toast = ar ? "تعذّرت الإضافة" : "Couldn't add"
        }
    }
}
