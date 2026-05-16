import SwiftUI

/// Friend profile — port of `src/components/FriendProfilePage.jsx`.
/// Shows avatar + name, three stat cards (sessions / top muscle / lifts),
/// muscle progress bars, recent sessions, and working weights, all gated by
/// the friend's `privacy_settings` jsonb column.
struct FriendProfilePage: View {

    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    let friend: FriendListEntry

    @State private var profile: SupabaseManager.FriendProfileRow?
    @State private var sessions: [FriendSession] = []
    @State private var weights: [String: Double] = [:]
    @State private var loading = true

    @State private var confirmingRemove = false
    @State private var removing = false

    private var ar: Bool { app.language == "ar" }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(HexTheme.bg.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await load() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: ar ? "chevron.right" : "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(HexTheme.text)
                    .frame(width: 36, height: 36)
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
                Text(loading
                     ? (ar ? "جارٍ التحميل…" : "Loading…")
                     : (profile?.username ?? profile?.name ?? friend.name ?? (ar ? "صديق" : "Bro")))
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(HexTheme.text)
                if let un = profile?.username {
                    Text("@\(un)")
                        .font(.system(size: 11))
                        .foregroundColor(HexTheme.mute)
                }
            }
            Spacer()

            if !loading {
                Button { handleRemove() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "person.fill.xmark")
                            .font(.system(size: 11))
                        Text(removing
                             ? (ar ? "جارٍ الإزالة…" : "Removing…")
                             : (confirmingRemove
                                ? (ar ? "تأكيد؟" : "Confirm?")
                                : (ar ? "إزالة" : "Remove")))
                            .font(.system(size: 12, weight: .heavy))
                    }
                    .foregroundColor(confirmingRemove
                                     ? Color(red: 1.0, green: 0.42, blue: 0.42)
                                     : HexTheme.mute)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(confirmingRemove
                                  ? Color(red: 1.0, green: 0.31, blue: 0.31).opacity(0.10)
                                  : HexTheme.surface2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(confirmingRemove
                                    ? Color(red: 1.0, green: 0.31, blue: 0.31).opacity(0.40)
                                    : HexTheme.border,
                                    lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(removing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(HexTheme.surface)
        .overlay(Rectangle().fill(HexTheme.border).frame(height: 1),
                 alignment: .bottom)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if loading {
            VStack {
                Spacer(minLength: 60)
                Text(ar ? "جارٍ تحميل الملف الشخصي…" : "Loading profile…")
                    .font(.system(size: 14))
                    .foregroundColor(HexTheme.mute)
                Spacer()
            }
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    avatarBlock.padding(.top, 16)
                    statsRow

                    if canSeeProgress, !muscleImprovements.isEmpty {
                        muscleProgressCard
                    }

                    if canSeeSessions, !sessions.isEmpty {
                        recentSessionsCard
                    }

                    if canSeeWeights, !weights.isEmpty {
                        workingWeightsCard
                    }

                    if showEmptyState {
                        Text(privacyMessage)
                            .font(.system(size: 14))
                            .foregroundColor(HexTheme.mute)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Pieces

    private var avatarBlock: some View {
        VStack(spacing: 10) {
            // Render the friend's actual avatar when one is set, with
            // a gradient/initial fallback to match the previous look
            // when the URL is missing or the load fails. Avatar URL
            // can come from either the freshly-loaded FriendProfileRow
            // (preferred — has the latest from `profiles`) or the
            // friend list entry we navigated in from.
            let urlString = profile?.avatarURL ?? friend.avatarURL
            ZStack {
                if let url = urlString.flatMap(URL.init(string:)) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            avatarFallback
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
                } else {
                    avatarFallback
                        .frame(width: 72, height: 72)
                }
                Circle()
                    .stroke(HexTheme.accent.opacity(0.27), lineWidth: 2)
                    .frame(width: 72, height: 72)
            }
            Text(profile?.name ?? profile?.username ?? friend.name ?? "Gym Bro")
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(HexTheme.text)
            if let un = profile?.username {
                Text("@\(un)")
                    .font(.system(size: 13))
                    .foregroundColor(HexTheme.mute)
            }
        }
    }

    /// Lime-tinted gradient + initial — same look the page had before
    /// when no avatar URL was available. Used as the AsyncImage
    /// placeholder + the no-URL branch.
    private var avatarFallback: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [HexTheme.accent.opacity(0.20),
                             HexTheme.accent.opacity(0.07)],
                    startPoint: .topLeading,
                    endPoint:   .bottomTrailing))
            Text(initial)
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(HexTheme.text)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 8) {
            statCard(label: ar ? "جلسات" : "Sessions",
                     value: "\(sessions.count)",
                     sub: sessions.isEmpty ? nil : (ar ? "مسجلة" : "logged"))
            statCard(label: ar ? "أفضل عضلة" : "Top muscle",
                     value: topMuscle?.label ?? "—",
                     sub: topMuscle.map { "+\($0.pct)%" })
            statCard(label: ar ? "رفعات متتبعة" : "Lifts tracked",
                     value: "\(weights.count)",
                     sub: nil)
        }
    }

    private func statCard(label: String, value: String, sub: String?) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(HexTheme.text)
            if let sub = sub {
                Text(sub)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(HexTheme.accent)
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(HexTheme.mute)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(HexTheme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1)
        )
    }

    private var muscleProgressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ar ? "تقدم العضلات" : "MUSCLE PROGRESS")
                .font(.system(size: 12, weight: .heavy))
                .kerning(ar ? 0 : 0.7)
                .foregroundColor(HexTheme.dim)
            ForEach(muscleImprovements) { mg in
                muscleBar(mg)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HexTheme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1)
        )
    }

    private func muscleBar(_ mg: MuscleImprovement) -> some View {
        let isTop = mg.id == muscleImprovements.first?.id
        return HStack(spacing: 10) {
            Text(mg.label)
                .font(.system(size: 12))
                .foregroundColor(HexTheme.dim)
                .frame(width: 70, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(HexTheme.surface).frame(height: 6)
                    Capsule()
                        .fill(isTop ? HexTheme.accent : Color(white: 0.23))
                        .frame(width: geo.size.width * CGFloat(min(mg.pct, 100)) / 100.0,
                               height: 6)
                        .animation(.easeOut(duration: 0.6), value: mg.pct)
                }
            }
            .frame(height: 6)
            Text("+\(mg.pct)%")
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(isTop ? HexTheme.accent : HexTheme.mute)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private var recentSessionsCard: some View {
        VStack(spacing: 0) {
            Text(ar ? "الجلسات الأخيرة" : "RECENT SESSIONS")
                .font(.system(size: 12, weight: .heavy))
                .kerning(ar ? 0 : 0.7)
                .foregroundColor(HexTheme.dim)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ForEach(Array(sessions.prefix(5).enumerated()), id: \.element.id) { _, s in
                HStack(spacing: 12) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 12))
                        .foregroundColor(HexTheme.mute)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(HexTheme.surface)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.name)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(HexTheme.text)
                            .lineLimit(1)
                        Text(ar
                             ? "\(s.exercises.count) تمرين"
                             : "\(s.exercises.count) exercise\(s.exercises.count == 1 ? "" : "s")")
                            .font(.system(size: 11))
                            .foregroundColor(HexTheme.mute)
                    }
                    Spacer()
                    Text(formatDate(s.date))
                        .font(.system(size: 12))
                        .foregroundColor(HexTheme.mute)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .overlay(
                    Rectangle().fill(HexTheme.border).frame(height: 1),
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
    }

    private var workingWeightsCard: some View {
        VStack(spacing: 0) {
            Text(ar ? "أوزان العمل" : "WORKING WEIGHTS")
                .font(.system(size: 12, weight: .heavy))
                .kerning(ar ? 0 : 0.7)
                .foregroundColor(HexTheme.dim)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            let sorted = weights.sorted { $0.value > $1.value }.prefix(8)
            ForEach(Array(sorted), id: \.key) { name, w in
                HStack {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(HexTheme.text)
                        .lineLimit(1)
                    Spacer()
                    Text("\(trimWeight(w)) kg")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(HexTheme.accent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .overlay(
                    Rectangle().fill(HexTheme.border).frame(height: 1),
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
    }

    // MARK: - Data loaders

    private func load() async {
        loading = true
        async let prof    = SupabaseManager.shared.fetchFriendProfile(friendId: friend.id)
        async let sess    = SupabaseManager.shared.fetchFriendSessions(friendId: friend.id, limit: 10)
        async let weights = SupabaseManager.shared.fetchFriendWeights(friendId: friend.id)
        do {
            let (p, s, w) = try await (prof, sess, weights)
            self.profile  = p
            self.sessions = s
            self.weights  = w
        } catch {
            print("[FriendProfilePage] load failed:", error)
        }
        loading = false
    }

    private func handleRemove() {
        if !confirmingRemove {
            confirmingRemove = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                confirmingRemove = false
            }
            return
        }
        removing = true
        Task {
            await app.removeFriend(friend.id)
            await MainActor.run {
                removing = false
                dismiss()
            }
        }
    }

    // MARK: - Privacy

    private var canSeeProgress: Bool { privacyAllows("showProgress") }
    private var canSeeSessions: Bool { privacyAllows("showSessions") }
    private var canSeeWeights:  Bool { privacyAllows("showWeights")  }

    /// Defaults to true (visible) when the flag is missing.
    private func privacyAllows(_ key: String) -> Bool {
        guard let p = profile?.privacySettings else { return true }
        if let v = p[key]?.value as? Bool { return v }
        return true
    }

    private var showEmptyState: Bool {
        // Mirror the React condition: nothing is renderable
        (!canSeeSessions || sessions.isEmpty) &&
        (!canSeeWeights  || weights.isEmpty) &&
        (!canSeeProgress || muscleImprovements.isEmpty)
    }

    private var privacyMessage: String {
        if !canSeeSessions && !canSeeWeights && !canSeeProgress {
            return ar ? "هذا الصديق يبقي إحصاءاته خاصة 🔒"
                      : "This Bro keeps their stats private 🔒"
        }
        return ar ? "لا بيانات بعد" : "No data yet"
    }

    // MARK: - Muscle improvement computation

    struct MuscleImprovement: Identifiable, Hashable {
        let id: String
        let label: String
        let pct: Int
    }

    private var muscleImprovements: [MuscleImprovement] {
        guard !sessions.isEmpty, canSeeProgress else { return [] }
        // exerciseName → (muscle, weights[])
        var exMap: [String: (muscle: String, weights: [Double])] = [:]
        for s in sessions {
            for ex in s.exercises {
                if ex.name.isEmpty { continue }
                // Same heuristic as React: skip bodyweight exercises (no
                // weight to improve). We don't have a bodyweight flag on
                // the Exercise struct, so skip rows with no weight at all.
                guard let m = MuscleUtils.resolveMuscle(fromName: ex.name) else { continue }
                guard let w = ex.weight, w > 0 else { continue }
                if exMap[ex.name] == nil {
                    exMap[ex.name] = (muscle: m, weights: [])
                }
                exMap[ex.name]?.weights.append(w)
            }
        }
        // Per-exercise improvement %, capped at 100
        var grouped: [String: [Int]] = [:]
        for (_, info) in exMap {
            guard info.weights.count >= 2 else { continue }
            let first = info.weights.first ?? 0
            let last  = info.weights.last  ?? 0
            guard first > 0 else { continue }
            let imp = min(Int(((last - first) / first * 100).rounded()), 100)
            grouped[info.muscle, default: []].append(imp)
        }
        var out: [MuscleImprovement] = []
        for mg in MuscleUtils.groups {
            // Sum across all primary-muscle slugs that map to this group.
            let pcts = mg.muscles.flatMap { grouped[$0] ?? [] }
            if pcts.isEmpty { continue }
            let avg = pcts.reduce(0, +) / pcts.count
            if avg > 0 { out.append(.init(id: mg.id, label: mg.label, pct: avg)) }
        }
        return out.sorted { $0.pct > $1.pct }
    }

    private var topMuscle: MuscleImprovement? { muscleImprovements.first }

    // MARK: - Helpers

    private var initial: String {
        let raw = profile?.username ?? profile?.name ?? friend.name ?? friend.username ?? "?"
        return String((raw.first.map(String.init) ?? "?")).uppercased()
    }

    private func formatDate(_ d: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: ar ? "ar_SA" : "en_GB")
        df.dateFormat = "MMM d"
        return df.string(from: d)
    }

    private func trimWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(w))
            : String(format: "%.1f", w)
    }
}
