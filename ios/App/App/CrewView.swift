import SwiftUI
import UIKit

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
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(HexTheme.border, lineWidth: 1)
                    )
                    .padding(.bottom, 18)
                }

                // ── Activity feed ─────────────────────────────────
                if !app.activityFeed.isEmpty {
                    sectionLabel(ar ? "النشاط الأخير" : "RECENT ACTIVITY")
                        .padding(.bottom, 6)
                    VStack(spacing: 0) {
                        ForEach(app.activityFeed.prefix(20)) { item in
                            activityRow(item)
                        }
                    }
                    .padding(.bottom, 12)
                }

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
            PointsInfoSheet().environmentObject(app)
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
                    .background(Circle().fill(HexTheme.accent))
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

        return HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(isMe ? HexTheme.accent.opacity(0.12) : HexTheme.surface2)
                Circle()
                    .stroke(isMe ? HexTheme.accent.opacity(0.4) : HexTheme.border, lineWidth: 1.5)
                Text(String(display.replacingOccurrences(of: "@", with: "").prefix(1)))
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(isMe ? HexTheme.accent : HexTheme.dim)
            }
            .frame(width: 34, height: 34)

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
            let volStr = vol > 0 ? " · \(Int(vol)) kg" : ""
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
                        .fill(HexTheme.accent)
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
            if let urlString = url, let parsed = URL(string: urlString) {
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
                Text("https://hex.app/invite/\(link.code)")
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

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = "https://hex.app/invite/\(link.code)"
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

                    ShareLink(item: URL(string: "https://hex.app/invite/\(link.code)")!) {
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
                                .fill(HexTheme.accent)
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

private struct PointsInfoSheet: View {
    @EnvironmentObject var app: AppState
    private var ar: Bool { app.language == "ar" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Capsule()
                    .fill(HexTheme.surface2)
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(ar ? "كيف تُحسب النقاط؟" : "How points are calculated")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(HexTheme.accent)
                    Text(ar
                         ? "النقاط غير محدودة — تُعاد شهرياً"
                         : "Unlimited score · resets every month")
                        .font(.system(size: 12))
                        .foregroundColor(HexTheme.mute)
                }
                .padding(.bottom, 12)

                // Formula
                VStack(alignment: .leading, spacing: 6) {
                    Text(ar ? "المعادلة" : "THE FORMULA")
                        .font(.system(size: 10, weight: .heavy))
                        .kerning(0.8)
                        .foregroundColor(HexTheme.accent)
                    Text(ar
                         ? "النقاط = (الالتزام × ٧٠٪) + (التحسن × ٣٠٪)"
                         : "Score = (Consistency × 70%) + (Improvement × 30%)")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(HexTheme.text)
                    HStack(spacing: 2) {
                        Rectangle().fill(HexTheme.accent).frame(height: 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Rectangle().fill(HexTheme.accent.opacity(0.5)).frame(height: 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .clipShape(Capsule())
                    .padding(.top, 2)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(HexTheme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(HexTheme.accent.opacity(0.20), lineWidth: 1.5)
                )

                infoBlock(
                    title: ar ? "الالتزام — ٧٠ نقطة" : "Consistency — 70 pts",
                    description: ar
                        ? "عدد المجموعات التي أتممتها هذا الشهر مقسوماً على المجموعات المبرمجة في برنامجك."
                        : "Sets you completed this month divided by the sets programmed in your programme."
                )

                infoBlock(
                    title: ar ? "التحسن — ٣٠ نقطة" : "Improvement — 30 pts",
                    description: ar
                        ? "متوسط نسبة تحسن الحجم لكل تمرين مقارنةً بأول تسجيل لك."
                        : "Average volume gain per exercise (weight × reps) vs. your very first logged set."
                )

                Text(ar
                     ? "🏆 المتصدر هو من يملك أعلى نقاط بحلول نهاية الشهر"
                     : "🏆 The player with the most points by end of month wins")
                    .font(.system(size: 12))
                    .foregroundColor(HexTheme.mute)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(HexTheme.accent.opacity(0.05))
                    )
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .background(HexTheme.bg.ignoresSafeArea())
    }

    private func infoBlock(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(HexTheme.accent)
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(HexTheme.dim)
                .lineSpacing(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HexTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1)
        )
    }
}
