import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Bros tab — port of `src/components/GymBrosTab.jsx`. Renders:
///   • header with title + add-bro button (sheet)
///   • horizontal friend bubbles (ring lit if they trained today)
///   • pending request list (accept / decline)
///   • leaderboard (me + friends ranked by score)
///   • activity feed
struct CrewView: View {
    @EnvironmentObject var app: AppState

    @State private var showAddSheet  = false
    @State private var showAllFriends = false
    @State private var pointsInfoShown = false
    @State private var friendDestination: FriendListEntry? = nil

    /// Drives the "Create league" modal opened from the LEAGUES
    /// section header. Sheet wraps a single text-field form that
    /// creates the league + auto-joins the user as admin.
    @State private var showCreateLeagueSheet = false
    /// Currently-tapped league card — when non-nil, navigates to
    /// LeagueDetailView for the full leaderboard + admin actions.
    @State private var leagueDestination: LeagueWithMembers? = nil

    private var ar: Bool { app.language == "ar" }
    private static let lime = HexTheme.accent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header — title + add button ───────────────────
                header.padding(.bottom, 12)

                // ── Friend bubbles row ────────────────────────────
                bubblesSection.padding(.bottom, 18)

                // ── Pending requests ──────────────────────────────
                if !app.pendingRequests.isEmpty {
                    sectionLabel(
                        ar ? "الطلبات (\(app.pendingRequests.count))"
                           : "REQUESTS (\(app.pendingRequests.count))"
                    ).padding(.bottom, 8)
                    VStack(spacing: 6) {
                        ForEach(app.pendingRequests) { req in
                            requestRow(req)
                        }
                    }
                    .padding(.bottom, 18)
                }

                // ── Leaderboard ───────────────────────────────────
                if app.leaderboard.count > 1 {
                    HStack {
                        sectionLabel(ar
                                     ? "المتصدرون · هذا الشهر"
                                     : "LEADERBOARD · THIS MONTH")
                        Spacer()
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            pointsInfoShown = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(ar ? "كيف تعمل النقاط؟" : "How points work")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundColor(HexTheme.mute)
                                Image(systemName: "info.circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(HexTheme.mute)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 8)

                    VStack(spacing: 0) {
                        ForEach(app.leaderboard) { entry in
                            leaderboardRow(entry)
                            if entry.id != app.leaderboard.last?.id {
                                Divider().background(HexTheme.border)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(HexTheme.surface)
                    )
                    // Clip child content (incl. the "me" indicator bar
                    // each row draws on its leading edge) to the same
                    // rounded shape as the background. Without this the
                    // bar paints past the top/bottom rounded corners,
                    // visible as a yellow tab sticking out of the card.
                    .clipShape(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(HexTheme.border, lineWidth: 1)
                    )
                    .padding(.bottom, 18)
                }

                // ── Activity feed ─────────────────────────────────
                // Activity rows older than 7 days drop off — per user
                // spec, recent activity should feel like a rolling
                // week, not a permanent log.
                //
                // The feed is constrained to a ~7-row visible window
                // and becomes internally scrollable when there's more
                // — keeps the page from stretching to a wall of text
                // when the user has many friends posting every day.
                // No visible border: the box edges blend into the
                // page background, so it just feels like the section
                // is shorter than it really is.
                let recentFeed = app.activityFeed.filter { item in
                    item.createdAt.timeIntervalSinceNow > -7 * 24 * 60 * 60
                }
                if !recentFeed.isEmpty {
                    sectionLabel(ar ? "النشاط الأخير" : "RECENT ACTIVITY")
                        .padding(.bottom, 6)
                    // Approx 7 activity rows fit in 420pt (each row
                    // ~60pt with its padding + the bottom divider).
                    // When the feed is shorter than that, the
                    // container shrinks to fit so we don't show a
                    // blank scroll area.
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            ForEach(recentFeed.prefix(50)) { item in
                                activityRow(item)
                            }
                        }
                    }
                    .frame(maxHeight: 420)
                    .padding(.bottom, 12)
                }

                // ── Leagues ─────────────────────────────────────────
                leaguesSection
                    .padding(.bottom, 18)

                // ── Empty state ───────────────────────────────────
                if app.friends.isEmpty && app.pendingRequests.isEmpty {
                    emptyState
                }

                Spacer(minLength: 100) // room for floating tab bar
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(HexTheme.bg.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showAddSheet) {
            AddBroSheet().environmentObject(app)
        }
        .sheet(isPresented: $pointsInfoShown) {
            pointsInfoSheetView
        }
        .navigationDestination(isPresented: Binding(
            get: { friendDestination != nil },
            set: { if !$0 { friendDestination = nil } }
        )) {
            if let friend = friendDestination {
                FriendProfilePage(friend: friend)
                    .environmentObject(app)
            }
        }
        .navigationDestination(isPresented: $showAllFriends) {
            AllFriendsPage(onTap: { friend in
                showAllFriends = false
                friendDestination = friend
            })
            .environmentObject(app)
        }
        .refreshable {
            await app.loadSocial()
            app.rebuildLeaderboard()
        }
        .task {
            // First visit — refresh in case CrewView is opened before sign-in
            // data loads finish.
            if app.friends.isEmpty && app.pendingRequests.isEmpty
                && app.activityFeed.isEmpty {
                await app.loadSocial()
                app.rebuildLeaderboard()
            }
        }
    }

    // MARK: - Points-info sheet presentation
    //
    // Split out so we can apply iOS 16.4+ modifiers
    // (`.presentationCornerRadius`) conditionally without polluting
    // the main `.sheet` closure. Deployment target is iOS 16.2 — the
    // sheet itself works on 16.2; the corner radius is the only
    // 16.4-gated detail (16.2/16.3 fall back to the system default,
    // which still looks fine).
    @ViewBuilder
    private var pointsInfoSheetView: some View {
        if #available(iOS 16.4, *) {
            PointsInfoSheet()
                .environmentObject(app)
                // `.large` matches React's `maxHeight: 88vh` feel —
                // the sheet covers most of the screen. The system's
                // swipe-to-dismiss gesture is contained inside the
                // sheet surface and does NOT bleed onto the CrewView
                // underneath, so it can't accidentally trigger the
                // `.refreshable` pull-to-refresh below.
                .presentationDetents([.large])
                // Hide the system drag handle since our header has a
                // close X button. Users can still swipe down anywhere
                // on the sheet to dismiss.
                .presentationDragIndicator(.hidden)
                // Match React `borderRadius: '20px 20px 0 0'`.
                .presentationCornerRadius(20)
        } else {
            // iOS 16.2 / 16.3 fallback — no `.presentationCornerRadius`.
            PointsInfoSheet()
                .environmentObject(app)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text(ar ? "أصدقاء الصالة" : "Gym Bros")
                .font(.system(size: 22, weight: .heavy))
                .kerning(ar ? 0 : -0.6)
                .foregroundColor(HexTheme.text)
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(.black)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(HexTheme.accentFill))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Bubble row

    private var bubblesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel(ar ? "أصدقاؤك" : "YOUR BROS")
                Spacer()
                if !app.friends.isEmpty {
                    Button {
                        showAllFriends = true
                    } label: {
                        Text(ar ? "← عرض الكل" : "See all →")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(HexTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(app.friends) { f in
                        FriendBubble(
                            friend: f,
                            trainedToday: app.friendsTrainedToday.contains(f.id)
                        ) {
                            friendDestination = f
                        }
                    }
                    AddBubble(ar: ar) { showAddSheet = true }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Request row

    private func requestRow(_ req: PendingRequest) -> some View {
        HStack(spacing: 10) {
            AvatarCircle(initial: initial(req.name, req.username),
                         url: req.avatarURL, size: 34, ring: HexTheme.border)
            VStack(alignment: .leading, spacing: 1) {
                Text(req.name)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(HexTheme.text)
                Text(ar ? "يريد أن يكون صديقاً لك" : "Wants to be your Bro")
                    .font(.system(size: 11))
                    .foregroundColor(HexTheme.mute)
            }
            Spacer()
            Button {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                Task { await app.respondToRequest(req, accept: true) }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(HexTheme.accent)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(HexTheme.accent.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(HexTheme.accent, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task { await app.respondToRequest(req, accept: false) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(HexTheme.mute)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(HexTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(HexTheme.border, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(HexTheme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Leaderboard row

    private func leaderboardRow(_ e: LeaderboardEntry) -> some View {
        Button {
            if !e.isMe, let friend = app.friends.first(where: { $0.id == e.id }) {
                friendDestination = friend
            }
        } label: {
            HStack(spacing: 8) {
                Text("\(e.rank)")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(rankColor(e))
                    .frame(width: 18, alignment: .center)
                AvatarCircle(
                    initial: initial(e.name, e.username),
                    url: e.avatarURL,
                    size: 28,
                    ring: e.isMe ? HexTheme.accent.opacity(0.5) : HexTheme.border,
                    bg: e.isMe ? HexTheme.accent.opacity(0.13) : HexTheme.surface,
                    textColor: e.isMe ? HexTheme.accent : HexTheme.mute,
                    fontSize: 11
                )
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(e.name ?? (e.username.map { "@\($0)" } ?? "Gym Bro"))
                            .font(.system(size: 13,
                                          weight: e.isMe ? .heavy : .semibold))
                            .foregroundColor(e.isMe ? HexTheme.accent : HexTheme.text)
                            .lineLimit(1)
                        if let u = e.username {
                            Text("@\(u)")
                                .font(.system(size: 10))
                                .foregroundColor(e.isMe
                                                 ? HexTheme.accent.opacity(0.6)
                                                 : HexTheme.mute)
                                .lineLimit(1)
                        }
                    }
                    Text("\(e.setsCompleted) sets · +\(e.improvementPct)% volume")
                        .font(.system(size: 10))
                        .foregroundColor(HexTheme.mute)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(e.score)")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(e.isMe ? HexTheme.accent : HexTheme.text)
                    Text(ar ? "نقطة" : "pts")
                        .font(.system(size: 10))
                        .foregroundColor(HexTheme.mute)
                }
                if !e.isMe {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(HexTheme.mute)
                } else {
                    Color.clear.frame(width: 11)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(e.isMe ? HexTheme.accent.opacity(0.08) : Color.clear)
            .overlay(
                Rectangle()
                    .fill(e.isMe ? HexTheme.accent : Color.clear)
                    .frame(width: 2),
                alignment: .leading
            )
        }
        .buttonStyle(.plain)
        .disabled(e.isMe)
    }

    private func rankColor(_ e: LeaderboardEntry) -> Color {
        if e.isMe { return HexTheme.accent }
        switch e.rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)   // gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75) // silver
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20) // bronze
        default: return HexTheme.mute
        }
    }

    // MARK: - Activity row

    private func activityRow(_ item: ActivityRow) -> some View {
        let isMe = item.userId == app.currentProfile?.id
        let display = activityDisplayName(item, isMe: isMe)
        let body    = activityBody(item, isMe: isMe)
        let time    = relativeTime(item.createdAt)

        // Use the shared AvatarCircle helper so the activity feed shows
        // the actual user's photo when one is set, instead of always
        // rendering a generic "S/A/D" initial circle. The avatar URL
        // is already carried on the ActivityRow (joined from profiles
        // in fetchActivityFeed) — we just weren't using it.
        let initialLetter = String(
            (item.profileName ?? display.replacingOccurrences(of: "@", with: ""))
                .prefix(1)
                .uppercased()
        )
        return HStack(alignment: .top, spacing: 10) {
            AvatarCircle(
                initial: initialLetter,
                url: item.avatarURL,
                size: 34,
                ring: isMe ? HexTheme.accent.opacity(0.4) : HexTheme.border,
                bg: isMe ? HexTheme.accent.opacity(0.12) : HexTheme.surface2,
                textColor: isMe ? HexTheme.accent : HexTheme.dim
            )

            VStack(alignment: .leading, spacing: 3) {
                (Text(display)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(HexTheme.text)
                 + Text(" \(body)")
                    .font(.system(size: 13))
                    .foregroundColor(HexTheme.dim))
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Image(systemName: item.type == "new_pr" ? "trophy.fill" : "dumbbell.fill")
                        .font(.system(size: 10))
                        .foregroundColor(item.type == "new_pr"
                                         ? HexTheme.accent
                                         : HexTheme.mute)
                    Text(time)
                        .font(.system(size: 10))
                        .foregroundColor(HexTheme.mute)
                }
            }
            Spacer()
        }
        .padding(.vertical, 11)
        .overlay(
            Rectangle().fill(HexTheme.border).frame(height: 1),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !isMe, let friend = app.friends.first(where: { $0.id == item.userId }) {
                friendDestination = friend
            }
        }
    }

    private func activityDisplayName(_ item: ActivityRow, isMe: Bool) -> String {
        if isMe { return ar ? "أنت" : "You" }
        if let u = item.profileUsername, !u.isEmpty { return "@\(u)" }
        return item.profileName ?? (ar ? "صديق صالة" : "Gym Bro")
    }

    private func activityBody(_ item: ActivityRow, isMe: Bool) -> String {
        switch item.type {
        case "session_completed":
            let vol = item.doubleField("volume") ?? 0
            let name = item.stringField("session_name") ?? (ar ? "جلسة" : "a session")
            // Volume = sum of (weight × reps) across every completed
            // set — standard strength-training "tonnage" metric.
            // Format with thousands separator (matches React's
            // toLocaleString) so big numbers read cleanly: "5,250 kg"
            // not "5250 kg". Uses Gregorian/en_US locale on the
            // number formatter so the comma stays as a comma even
            // when the rest of the UI is Arabic.
            let volStr: String = {
                guard vol > 0 else { return "" }
                let nf = NumberFormatter()
                nf.numberStyle = .decimal
                nf.maximumFractionDigits = 0
                nf.locale = Locale(identifier: "en_US_POSIX")
                let formatted = nf.string(from: NSNumber(value: Int(vol))) ?? "\(Int(vol))"
                return " · \(formatted) \(ar ? "كجم" : "kg")"
            }()
            return ar ? "أتم \"\(name)\"\(volStr)" : "completed \"\(name)\"\(volStr)"
        case "new_pr":
            let ex = item.stringField("exercise_name") ?? (ar ? "تمرين" : "an exercise")
            let weight = item.doubleField("weight") ?? 0
            let prev   = item.doubleField("previous_weight") ?? 0
            let was = prev > 0 ? " (was \(Int(prev)))" : ""
            return ar
                ? "رقم قياسي في \(ex): \(Int(weight)) كجم\(was)"
                : "PR on \(ex): \(Int(weight)) kg\(was)"
        default:
            return ar ? "أنجز شيئاً رائعاً" : "did something impressive"
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return ar ? "الآن" : "just now" }
        if diff < 3600 { return ar ? "منذ \(Int(diff/60))د" : "\(Int(diff/60))m ago" }
        if diff < 86_400 { return ar ? "منذ \(Int(diff/3600))س" : "\(Int(diff/3600))h ago" }
        let df = DateFormatter()
        df.locale = Locale(identifier: ar ? "ar_SA" : "en_GB")
        // Pin to Gregorian so the Arabic locale doesn't default to
        // Islamic Civil (which produced "ذو الحجة ٣" for May 2026).
        // Localised month names still get rendered in Arabic — just
        // from the Gregorian calendar, e.g. "مايو ٣".
        df.calendar = Calendar(identifier: .gregorian)
        df.dateFormat = "MMM d"
        return df.string(from: date)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🏋️").font(.system(size: 44))
            Text(ar ? "لا أصدقاء بعد" : "No Bros yet")
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(HexTheme.text)
            Text(ar
                 ? "ادعُ أصدقاء الصالة وتنافسوا على قائمة المتصدرين"
                 : "Invite your gym friends and compete on the leaderboard")
                .font(.system(size: 13))
                .foregroundColor(HexTheme.dim)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Button {
                showAddSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 13, weight: .heavy))
                    Text(ar ? "أضف أول صديق" : "Add your first Bro")
                        .font(.system(size: 14, weight: .heavy))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 28)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(HexTheme.accentFill)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }

    // MARK: - Pieces

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .kerning(ar ? 0 : 0.9)
            .foregroundColor(HexTheme.dim)
    }

    private func initial(_ name: String?, _ username: String?) -> String {
        if let n = name?.first { return String(n).uppercased() }
        if let u = username?.first { return String(u).uppercased() }
        return "?"
    }

    // MARK: - Leagues section

    /// Section that sits below "Recent Activity" on the Bros tab.
    /// Header has "LEAGUES" + a "+ New" button to create one. Body
    /// renders a `LeagueListCard` per league the user belongs to;
    /// empty-state shows an explanatory line and the same create
    /// button so a brand-new user has a clear way in.
    private var leaguesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel(ar ? "الدوريات" : "LEAGUES")
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showCreateLeagueSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .heavy))
                        Text(ar ? "جديد" : "New")
                            .font(.system(size: 12, weight: .heavy))
                    }
                    .foregroundColor(HexTheme.accent)
                }
                .buttonStyle(.plain)
            }

            if app.myLeagues.isEmpty {
                Text(ar
                     ? "أنشئ دوريك الأول وادعُ أصدقاءك للتنافس"
                     : "Create your first league and invite friends to compete")
                    .font(.system(size: 12))
                    .foregroundColor(HexTheme.mute)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(HexTheme.surface2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(HexTheme.border, lineWidth: 1)
                    )
            } else {
                VStack(spacing: 12) {
                    ForEach(app.myLeagues) { league in
                        LeagueListCard(league: league, ar: ar) {
                            leagueDestination = league
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateLeagueSheet) {
            CreateLeagueSheet().environmentObject(app)
        }
        .navigationDestination(
            isPresented: Binding(
                get: { leagueDestination != nil },
                set: { if !$0 { leagueDestination = nil } }
            )
        ) {
            if let dest = leagueDestination {
                LeagueDetailView(league: dest).environmentObject(app)
            }
        }
    }
}

// MARK: - Friend bubble

private struct FriendBubble: View {
    let friend: FriendListEntry
    let trainedToday: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                AvatarCircle(
                    initial: initial,
                    url: friend.avatarURL,
                    size: 48,
                    ring: trainedToday ? HexTheme.accent : Color(white: 0.16),
                    bg: HexTheme.accent.opacity(0.10),
                    textColor: trainedToday ? HexTheme.accent : HexTheme.dim,
                    fontSize: 17
                )
                Text(firstName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(HexTheme.mute)
                    .lineLimit(1)
                    .frame(maxWidth: 56)
            }
            .frame(width: 60)
        }
        .buttonStyle(.plain)
    }

    private var initial: String {
        if let n = friend.name?.first { return String(n).uppercased() }
        if let u = friend.username?.first { return String(u).uppercased() }
        return "?"
    }
    private var firstName: String {
        let raw = friend.name ?? friend.username ?? "Bro"
        let first = raw.split(separator: " ").first.map(String.init) ?? raw
        return String(first.prefix(8))
    }
}

// MARK: - Add bubble

private struct AddBubble: View {
    let ar: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(white: 0.27))
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .strokeBorder(
                                Color(white: 0.20),
                                style: StrokeStyle(lineWidth: 2, dash: [4, 4])
                            )
                    )
                Text(ar ? "إضافة" : "Add")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(white: 0.27))
            }
            .frame(width: 60)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Avatar helpers

/// Decode a "data:image/jpeg;base64,XXX" URL string into a UIImage.
/// Returns nil for plain http(s) URLs, malformed input, or bytes
/// that don't decode as an image. AsyncImage in SwiftUI hands data
/// URLs straight to URLSession's cache layer, which discards them —
/// so anywhere we display an avatar we have to short-circuit data
/// URLs and decode them ourselves.
///
/// React stores avatars as base64 data URLs directly in
/// profiles.avatar_url (see src/components/ProfileTab.jsx
/// compressImage + App.jsx saveAvatarUrl). The iOS port writes
/// the same format so both clients see each other's avatars.
func decodeDataURLImage(_ s: String) -> UIImage? {
    guard s.hasPrefix("data:"),
          let commaIdx = s.firstIndex(of: ","),
          let data = Data(base64Encoded: String(s[s.index(after: commaIdx)...]))
    else { return nil }
    return UIImage(data: data)
}

// MARK: - Avatar circle (shared)

struct AvatarCircle: View {
    let initial: String
    var url: String? = nil
    var size: CGFloat = 48
    var ring: Color = Color(white: 0.16)
    var bg:   Color = HexTheme.accent.opacity(0.10)
    var textColor: Color = HexTheme.dim
    var fontSize: CGFloat? = nil

    var body: some View {
        let fs = fontSize ?? size * 0.36
        ZStack {
            if let urlString = url {
                // Data URL → decode immediately. http URL → AsyncImage.
                // Anything else → fallback initial.
                if let dataImg = decodeDataURLImage(urlString) {
                    Image(uiImage: dataImg)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else if let parsed = URL(string: urlString),
                          parsed.scheme == "http" || parsed.scheme == "https" {
                    AsyncImage(url: parsed) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            ZStack {
                                Circle().fill(bg)
                                Text(initial)
                                    .font(.system(size: fs, weight: .heavy))
                                    .foregroundColor(textColor)
                            }
                        }
                    }
                    .clipShape(Circle())
                } else {
                    Circle().fill(bg)
                    Text(initial)
                        .font(.system(size: fs, weight: .heavy))
                        .foregroundColor(textColor)
                }
            } else {
                Circle().fill(bg)
                Text(initial)
                    .font(.system(size: fs, weight: .heavy))
                    .foregroundColor(textColor)
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(ring, lineWidth: 2.5))
    }
}

// MARK: - Add Bro sheet (invite link + search)

private struct AddBroSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    enum Tab { case invite, search }
    @State private var tab: Tab = .invite

    @State private var inviteLink: InviteLink?
    @State private var generating = false
    @State private var copied = false

    @State private var query = ""
    @State private var results: [UserSearchResult] = []
    @State private var searching = false
    @State private var sentStatus: [UUID: String] = [:]   // "sending" | "sent"

    private var ar: Bool { app.language == "ar" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // grabber
            Capsule()
                .fill(HexTheme.surface2)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
                .padding(.bottom, 12)

            Text(ar ? "إضافة صديق" : "Add a Bro")
                .font(.system(size: 17, weight: .heavy))
                .foregroundColor(HexTheme.text)
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            // Tab switch
            HStack(spacing: 0) {
                tabButton(.invite, label: ar ? "رابط الدعوة" : "Invite link")
                tabButton(.search, label: ar ? "البحث" : "Search users")
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(HexTheme.surface2)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Group {
                if tab == .invite {
                    inviteBody
                } else {
                    searchBody
                }
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 24)
        }
        .background(HexTheme.bg.ignoresSafeArea())
        .task {
            if inviteLink == nil { await regenerate() }
        }
    }

    @ViewBuilder
    private func tabButton(_ t: Tab, label: String) -> some View {
        Button { tab = t } label: {
            Text(label)
                .font(.system(size: 13, weight: tab == t ? .heavy : .semibold))
                .foregroundColor(tab == t ? HexTheme.text : HexTheme.mute)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tab == t ? HexTheme.surface : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: invite tab

    private var inviteBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(ar
                 ? "شارك هذا الرابط — يتيح لهم إضافتك كصديق فوراً. ينتهي خلال ٤٨ ساعة."
                 : "Share this link — it lets them add you as a Bro instantly. Expires in 48h.")
                .font(.system(size: 13))
                .foregroundColor(HexTheme.dim)
                .lineSpacing(3)

            if generating {
                Text(ar ? "جارٍ إنشاء الرابط…" : "Generating link…")
                    .font(.system(size: 13))
                    .foregroundColor(HexTheme.mute)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(HexTheme.surface2)
                    )
            } else if let link = inviteLink {
                Text("hex://invite/\(link.code)")
                    .font(.system(size: 12))
                    .foregroundColor(HexTheme.dim)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(HexTheme.surface2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(HexTheme.border, lineWidth: 1)
                    )

                // QR code for in-person sharing — encodes the same
                // `hex://invite/<code>` URL the Share button does, so
                // a Bro standing next to you can just point their
                // camera at the screen instead of waiting for a link.
                // Rendered through `HexTheme.accentFill` so it picks
                // up the user's accent COLOUR and MATERIAL
                // (matte / glossy / metal / neon) — switching the
                // material in Settings repaints the QR on the next
                // body evaluation.
                AccentQRCodeBlock(url: "hex://invite/\(link.code)",
                                  ar: ar)

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = "hex://invite/\(link.code)"
                        copied = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 12, weight: .heavy))
                            Text(copied ? (ar ? "تم النسخ!" : "Copied!")
                                        : (ar ? "نسخ" : "Copy"))
                                .font(.system(size: 13, weight: .heavy))
                        }
                        .foregroundColor(copied ? HexTheme.accent : HexTheme.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(copied ? HexTheme.accent.opacity(0.10) : HexTheme.surface2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(copied ? HexTheme.accent : HexTheme.border, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)

                    ShareLink(item: URL(string: "hex://invite/\(link.code)")!) {
                        HStack(spacing: 7) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 12, weight: .heavy))
                            Text(ar ? "مشاركة" : "Share")
                                .font(.system(size: 13, weight: .heavy))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(HexTheme.accentFill)
                        )
                    }
                }

                Button {
                    Task { await regenerate() }
                } label: {
                    Text(ar ? "إنشاء رابط جديد" : "Generate new link")
                        .font(.system(size: 12))
                        .foregroundColor(HexTheme.mute)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @MainActor
    private func regenerate() async {
        generating = true
        do {
            inviteLink = try await SupabaseManager.shared.createInviteLink()
        } catch {
            print("[AddBroSheet] generate failed:", error)
        }
        generating = false
    }

    // MARK: search tab

    private var searchBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(HexTheme.mute)
                TextField(ar
                          ? "ابحث باسم المستخدم أو الاسم…"
                          : "Search by username or name…",
                          text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 16))
                    .foregroundColor(HexTheme.text)
                    .onChange(of: query) { _ in
                        scheduleSearch()
                    }
                if searching {
                    Text("…")
                        .font(.system(size: 11))
                        .foregroundColor(HexTheme.mute)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(HexTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(HexTheme.border, lineWidth: 1)
            )

            ForEach(results) { u in
                HStack(spacing: 12) {
                    AvatarCircle(
                        initial: initial(u),
                        url: u.avatarURL,
                        size: 34,
                        ring: HexTheme.border,
                        bg: HexTheme.surface2,
                        textColor: HexTheme.mute,
                        fontSize: 13
                    )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(u.name ?? u.username ?? "Gym Bro")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(HexTheme.text)
                        if let un = u.username {
                            Text("@\(un)")
                                .font(.system(size: 11))
                                .foregroundColor(HexTheme.mute)
                        }
                    }
                    Spacer()
                    let status = sentStatus[u.id]
                    Button {
                        Task {
                            sentStatus[u.id] = "sending"
                            await app.sendFriendRequest(toUserId: u.id)
                            sentStatus[u.id] = "sent"
                        }
                    } label: {
                        Text(status == "sending"
                             ? "…"
                             : (status == "sent"
                                ? (ar ? "تم ✓" : "Sent ✓")
                                : (ar ? "إضافة" : "Add")))
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(status == "sent" ? HexTheme.accent : .black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(status == "sent"
                                          ? HexTheme.accent.opacity(0.13)
                                          : HexTheme.accent)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(status == "sent" ? HexTheme.accent : Color.clear,
                                            lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(status != nil)
                }
                .padding(.vertical, 6)
                .overlay(
                    Rectangle().fill(HexTheme.border).frame(height: 1),
                    alignment: .bottom
                )
            }

            if !query.isEmpty, !searching, results.isEmpty {
                Text(ar
                     ? "لا مستخدمين لـ \"\(query)\""
                     : "No users found for \"\(query)\"")
                    .font(.system(size: 13))
                    .foregroundColor(HexTheme.mute)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
        }
    }

    @State private var searchTask: Task<Void, Never>? = nil

    private func scheduleSearch() {
        searchTask?.cancel()
        let q = query
        if q.trimmingCharacters(in: .whitespaces).isEmpty {
            results = []
            searching = false
            return
        }
        searching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            do {
                let res = try await SupabaseManager.shared.searchUsers(query: q)
                if !Task.isCancelled {
                    await MainActor.run {
                        results = res
                        searching = false
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run { searching = false }
                }
            }
        }
    }

    private func initial(_ u: UserSearchResult) -> String {
        if let n = u.name?.first { return String(n).uppercased() }
        if let u = u.username?.first { return String(u).uppercased() }
        return "?"
    }
}

// MARK: - All friends page

private struct AllFriendsPage: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let onTap: (FriendListEntry) -> Void

    private var ar: Bool { app.language == "ar" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: ar ? "chevron.right" : "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(HexTheme.text)
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(HexTheme.surface2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(HexTheme.border, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 1) {
                    Text(ar ? "أصدقاؤك" : "Your Bros")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(HexTheme.text)
                    Text(ar
                         ? "\(app.friends.count) صديق"
                         : "\(app.friends.count) \(app.friends.count == 1 ? "bro" : "bros")")
                        .font(.system(size: 11))
                        .foregroundColor(HexTheme.mute)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(HexTheme.surface)
            .overlay(Rectangle().fill(HexTheme.border).frame(height: 1),
                     alignment: .bottom)

            if app.friends.isEmpty {
                Text(ar ? "لا أصدقاء بعد — أضف بعضهم!"
                        : "No Bros yet — add some!")
                    .font(.system(size: 14))
                    .foregroundColor(HexTheme.mute)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(app.friends) { f in
                            Button { onTap(f) } label: {
                                HStack(spacing: 12) {
                                    AvatarCircle(
                                        initial: initial(f),
                                        url: f.avatarURL,
                                        size: 42,
                                        ring: HexTheme.border,
                                        fontSize: 15
                                    )
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(f.name ?? f.username ?? "Gym Bro")
                                            .font(.system(size: 14, weight: .heavy))
                                            .foregroundColor(HexTheme.text)
                                        if let u = f.username {
                                            Text("@\(u)")
                                                .font(.system(size: 11))
                                                .foregroundColor(HexTheme.mute)
                                        }
                                        Text("\(f.leaderboardData?.setsCompleted ?? 0) sets · +\(f.leaderboardData?.improvementPct ?? 0)% volume")
                                            .font(.system(size: 11))
                                            .foregroundColor(HexTheme.mute)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11))
                                        .foregroundColor(HexTheme.mute)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                .overlay(
                                    Rectangle().fill(HexTheme.border).frame(height: 1),
                                    alignment: .bottom
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .background(HexTheme.bg.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private func initial(_ f: FriendListEntry) -> String {
        if let n = f.name?.first { return String(n).uppercased() }
        if let u = f.username?.first { return String(u).uppercased() }
        return "?"
    }
}

// MARK: - Points info sheet
//
// 1:1 port of `PointsInfoCard` from src/components/GymBrosTab.jsx:679–852.
// Two-pane vertical layout inside a sheet:
//   1. Sticky header: title + subtitle on the leading side, close-X
//      button on the trailing side.
//   2. Scrollable body: formula pill (with visual 70/30 split bar +
//      labels) -> Consistency block (description + 3 example rows)
//      -> Improvement block (same shape) -> trophy footer.
//
// Presentation is controlled at the call site (`.sheet(...)` in
// CrewView) — we use `.presentationDetents([.large])` and
// `.presentationDragIndicator(.hidden)` there so the system's
// built-in swipe-to-dismiss works naturally without our handle
// fighting it. The drag-down gesture is contained to the sheet
// surface and does NOT reach the page behind it, so CrewView's
// scroll position and data don't reset on dismiss.
private struct PointsInfoSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    private var ar: Bool { app.language == "ar" }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    formulaPill
                    consistencyBlock
                    improvementBlock
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .background(HexTheme.bg.ignoresSafeArea())
        .environment(\.layoutDirection, ar ? .rightToLeft : .leftToRight)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(ar ? "كيف تُحسب النقاط؟" : "How points are calculated")
                    .font(HexTheme.font(size: 18, weight: .heavy, ar: ar))
                    .foregroundColor(HexTheme.accent)
                Text(ar
                     ? "النقاط غير محدودة — تُعاد شهرياً"
                     : "Unlimited score · resets every month")
                    .font(HexTheme.font(size: 12, weight: .regular, ar: ar))
                    .foregroundColor(HexTheme.mute)
            }
            Spacer(minLength: 8)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(HexTheme.mute)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(HexTheme.surface2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(HexTheme.border, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 20)
    }

    // MARK: - Formula pill (title + equation + visual 70/30 split)

    private var formulaPill: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(ar ? "المعادلة" : "THE FORMULA")
                .font(HexTheme.font(size: 10, weight: .heavy, ar: ar))
                .kerning(ar ? 0 : 0.8)
                .foregroundColor(HexTheme.accent)

            Text(ar
                 ? "النقاط = (الالتزام × ٧٠٪) + (التحسن × ٣٠٪)"
                 : "Score = (Consistency × 70%) + (Improvement × 30%)")
                .font(HexTheme.font(size: 13, weight: .heavy, ar: ar))
                .foregroundColor(Color.white.opacity(0.80))
                .padding(.bottom, 2)

            // 70/30 split bar — 70% solid accent, 30% accent at 0.5 alpha.
            // Matches React's `LIME` (full) + `#ADFF2F88` (~0.53 alpha)
            // pairing. Uses GeometryReader so the widths track the
            // available width regardless of sheet sizing.
            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(HexTheme.accentFill)
                        .frame(width: max(0, geo.size.width * 0.70 - 1), height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(HexTheme.accent.opacity(0.50))
                        .frame(width: max(0, geo.size.width * 0.30 - 1), height: 4)
                }
            }
            .frame(height: 4)

            HStack {
                Text(ar ? "الالتزام ٧٠٪" : "Consistency 70%")
                    .font(HexTheme.font(size: 10, weight: .heavy, ar: ar))
                    .foregroundColor(HexTheme.accent)
                Spacer()
                Text(ar ? "التحسن ٣٠٪" : "Improvement 30%")
                    .font(HexTheme.font(size: 10, weight: .heavy, ar: ar))
                    .foregroundColor(HexTheme.accent.opacity(0.50))
            }
            .padding(.top, 3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HexTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HexTheme.accent.opacity(0.20), lineWidth: 1.5)
        )
    }

    // MARK: - Consistency block

    private var consistencyBlock: some View {
        scoreBlock(
            emoji: "✅",
            titleColor: HexTheme.accent,
            title: ar ? "الالتزام — ٧٠ نقطة" : "Consistency — 70 pts",
            description: ar
                ? "عدد المجموعات التي أتممتها هذا الشهر مقسوماً على إجمالي المجموعات المبرمجة في شهر كامل من برنامجك (الأسبوع × ٤). حجم البرنامج لا يهم — كل واحد يقارن بهدفه الشهري."
                : "Sets you completed this month divided by your programme's monthly target (weekly sets × 4). Programme size doesn't matter — everyone is judged against THEIR own monthly target.",
            rows: ar
                ? [
                    (label: "أتممت ٦٠ من أصل ٦٠ مجموعة شهرياً", value: "١٠٠ نقطة", highlight: true),
                    (label: "أتممت ٣٠ من أصل ٦٠ مجموعة شهرياً", value: "٥٠ نقطة", highlight: false),
                    (label: "تجاوزت هدفك الشهري (٧٠ من ٦٠)", value: "١١٧ نقطة", highlight: true),
                ]
                : [
                    (label: "Complete 60 of 60 monthly sets", value: "100 pts", highlight: true),
                    (label: "Complete 30 of 60 monthly sets", value: "50 pts", highlight: false),
                    (label: "Exceed your monthly target (70 / 60)", value: "117 pts", highlight: true),
                ]
        )
    }

    // MARK: - Improvement block

    private var improvementBlock: some View {
        scoreBlock(
            emoji: "📈",
            titleColor: HexTheme.accent.opacity(0.50),
            title: ar ? "التحسن — ٣٠ نقطة" : "Improvement — 30 pts",
            description: ar
                ? "متوسط نسبة تحسن الحجم لكل تمرين (الوزن × التكرارات) مقارنةً بأول تسجيل لك."
                : "Average volume gain per exercise (weight × reps) vs. your very first logged set — averaged across all your exercises.",
            rows: ar
                ? [
                    (label: "بدأت بـ ٥٠ كجم، والآن ٦٥ كجم (+٣٠٪)", value: "٩ / ٣٠", highlight: false),
                    (label: "حسّنت كل تمارينك بأكثر من ١٠٠٪", value: "٣٠ / ٣٠", highlight: true),
                    (label: "لا يوجد حد أقصى للتحسن", value: "∞", highlight: true),
                ]
                : [
                    (label: "Started 50 kg → now 65 kg (+30% vol.)", value: "9 / 30", highlight: false),
                    (label: "Improved every exercise by 100%+", value: "30 / 30", highlight: true),
                    (label: "No ceiling on improvement", value: "∞", highlight: true),
                ]
        )
    }

    /// Generic "Consistency / Improvement" card: emoji-header,
    /// description, then a vertical list of example rows.
    private func scoreBlock(
        emoji: String,
        titleColor: Color,
        title: String,
        description: String,
        rows: [(label: String, value: String, highlight: Bool)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Heading area
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(emoji)
                        .font(.system(size: 18))
                    Text(title)
                        .font(HexTheme.font(size: 14, weight: .heavy, ar: ar))
                        .foregroundColor(titleColor)
                }
                Text(description)
                    .font(HexTheme.font(size: 12, weight: .regular, ar: ar))
                    .foregroundColor(HexTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .overlay(
                Rectangle()
                    .fill(HexTheme.border)
                    .frame(height: 1),
                alignment: .bottom
            )

            // Example rows
            ForEach(0..<rows.count, id: \.self) { i in
                let row = rows[i]
                HStack {
                    Text(row.label)
                        .font(HexTheme.font(size: 12, weight: .regular, ar: ar))
                        .foregroundColor(HexTheme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Text(row.value)
                        .font(HexTheme.font(size: 13, weight: .heavy, ar: ar))
                        .foregroundColor(row.highlight ? HexTheme.accent : Color.white.opacity(0.60))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .overlay(
                    Rectangle()
                        .fill(HexTheme.border.opacity(0.6))
                        .frame(height: 1),
                    alignment: .top
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HexTheme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Footer

    private var footer: some View {
        Text(ar
             ? "🏆 المتصدر هو من يملك أعلى نقاط بحلول نهاية الشهر"
             : "🏆 The player with the most points by end of month wins")
            .font(HexTheme.font(size: 12, weight: .regular, ar: ar))
            .foregroundColor(HexTheme.dim)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(HexTheme.accent.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(HexTheme.accent.opacity(0.13), lineWidth: 1)
            )
            .padding(.top, 4)
    }
}

// MARK: - Accent-tinted QR code (CoreImage-backed)
//
// Generates a QR code for the invite URL and tints it with the
// user's chosen accent colour + material. Pipeline:
//   1. `CIQRCodeGenerator` produces a default black-on-white QR.
//   2. `CIColorInvert` swaps to white-on-black so the data cells
//      become the bright pixels.
//   3. `CIMaskToAlpha` keys out the dark background — data cells
//      are now opaque white on a transparent canvas.
//   4. Render through SwiftUI's `.renderingMode(.template)` +
//      `.foregroundStyle(HexTheme.accentFill)` so the opaque
//      pixels paint themselves with the active accent ShapeStyle.
//      Because `accentFill` returns a gradient when the user picks
//      glossy / metal / neon, the QR cells inherit those effects
//      naturally — no per-cell drawing needed.
private struct AccentQRCodeBlock: View {
    let url: String
    let ar: Bool

    var body: some View {
        VStack(spacing: 6) {
            if let img = Self.qrImage(for: url) {
                Image(uiImage: img)
                    .renderingMode(.template)
                    .interpolation(.none) // sharp pixel edges
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(HexTheme.accentFill)
                    .frame(width: 180, height: 180)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(HexTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(HexTheme.border, lineWidth: 1)
                    )
            }

            Text(ar
                 ? "أو امسح الباركود إذا كان صديقك بجانبك"
                 : "Or scan the code if your Bro is next to you")
                .font(HexTheme.font(size: 11, weight: .regular, ar: ar))
                .foregroundColor(HexTheme.mute)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    /// Build the QR data image. Returns nil if CoreImage fails to
    /// produce a usable bitmap (edge case — should never happen with
    /// well-formed input). The result is a small transparent-background
    /// PNG ready for template tinting.
    private static func qrImage(for text: String) -> UIImage? {
        guard let data = text.data(using: .utf8),
              let qr = CIFilter(name: "CIQRCodeGenerator")
        else { return nil }
        qr.setValue(data, forKey: "inputMessage")
        // "H" = highest error correction — gives the most scanner
        // tolerance for partial obscuring (glare, fingers, etc.) at
        // the cost of slightly denser cells. Well worth it for a
        // pass-the-phone scanning UX.
        qr.setValue("H", forKey: "inputCorrectionLevel")
        guard let raw = qr.outputImage else { return nil }

        // Invert (black ↔ white), then mask to alpha to make the
        // original data cells (formerly black, now white-after-invert)
        // come out opaque, and the background transparent.
        guard let invert = CIFilter(name: "CIColorInvert") else { return nil }
        invert.setValue(raw, forKey: kCIInputImageKey)
        guard let inverted = invert.outputImage else { return nil }

        guard let mask = CIFilter(name: "CIMaskToAlpha") else { return nil }
        mask.setValue(inverted, forKey: kCIInputImageKey)
        guard let alpha = mask.outputImage else { return nil }

        // Scale up so the cell edges render crisply even at 180pt.
        // 12× covers @3x retina with headroom; combined with
        // `.interpolation(.none)` we get sharp squares, not blur.
        let scaled = alpha.transformed(by: CGAffineTransform(scaleX: 12, y: 12))

        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent)
        else { return nil }
        return UIImage(cgImage: cg)
    }
}
