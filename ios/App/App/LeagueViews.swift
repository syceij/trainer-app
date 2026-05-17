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
                        .kerning(ar ? 0 : 0.6)
                        .foregroundColor(HexTheme.dim)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

                // Outlined inner panel with up to 7 ranked rows
                VStack(spacing: 0) {
                    let preview = Array(league.leaderboard.prefix(7))
                    ForEach(Array(preview.enumerated()), id: \.offset) { idx, entry in
                        rankRow(rank: idx + 1, entry: entry)
                        if idx < preview.count - 1 {
                            Rectangle()
                                .fill(HexTheme.accent.opacity(0.35))
                                .frame(height: 1)
                        }
                    }
                    // Pad to 7 rows so the card height is stable
                    // whether you have 2 members or 7+.
                    if preview.count < 7 {
                        ForEach(preview.count..<7, id: \.self) { i in
                            rankRow(rank: i + 1, entry: nil)
                            if i < 6 {
                                Rectangle()
                                    .fill(HexTheme.accent.opacity(0.35))
                                    .frame(height: 1)
                            }
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

    /// "MVP : <name>" line. Falls back to a placeholder when the
    /// last-month winner hasn't been computed yet (Ship A — the
    /// historical-snapshot computation lands in Ship B).
    private var mvpLine: String {
        let prefix = ar ? "أفضل لاعب" : "MVP"
        if let mvp = league.lastMonthMVP {
            return "\(prefix) : \(mvp.name ?? "—")"
        }
        return ar
            ? "\(prefix) : (الفائز السابق)"
            : "\(prefix) : (LAST MONTHS WINNER)"
    }

    /// One numbered row in the leaderboard panel. `entry == nil`
    /// renders an empty placeholder slot.
    private func rankRow(rank: Int, entry: LeagueLeaderboardEntry?) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 17, weight: .heavy))
                .foregroundColor(HexTheme.text)
                .frame(width: 28, alignment: .leading)
            if let e = entry {
                Text(e.name ?? e.username ?? "—")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(HexTheme.text)
                    .lineLimit(1)
                Spacer()
                Text("\(e.score)")
                    .font(.system(size: 13, weight: .heavy).monospacedDigit())
                    .foregroundColor(HexTheme.dim)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
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
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: ar ? "chevron.right" : "chevron.left")
                        .foregroundColor(HexTheme.text)
                }
            }
        }
        .sheet(isPresented: $showInviteSheet) {
            LeagueInviteSheet(leagueId: league.league.id,
                              existingMemberIds: Set(league.leaderboard.map(\.id)),
                              ar: ar)
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

    private var mvpLine: String {
        let prefix = ar ? "أفضل لاعب الشهر السابق" : "MVP last month"
        if let mvp = league.lastMonthMVP {
            return "\(prefix) : \(mvp.name ?? "—")"
        }
        return ar ? "\(prefix) : (قيد التطوير)" : "\(prefix) : (coming soon)"
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
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(HexTheme.text)
                .frame(width: 26, alignment: .leading)
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
                if let u = entry.username {
                    Text("@\(u)")
                        .font(.system(size: 11))
                        .foregroundColor(HexTheme.mute)
                }
            }
            Spacer()
            Text("\(entry.score)")
                .font(.system(size: 14, weight: .heavy).monospacedDigit())
                .foregroundColor(HexTheme.accent)
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
            print("[CreateLeagueSheet] failed:", error)
            app.toast = ar ? "تعذّر الإنشاء" : "Couldn't create"
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
        } catch {
            print("[LeagueInvite] add failed:", error)
            app.toast = ar ? "تعذّرت الإضافة" : "Couldn't add"
        }
    }
}
