import SwiftUI

/// Progress tab — visual scaffold matching src/components/ProgressTab.jsx.
/// Tracked lifts grid, muscle progress chart placeholder, and "add" CTAs.
/// Real history-driven data wiring comes in a later pass.
struct ProgressTabView: View {
    @EnvironmentObject var app: AppState

    private var ar: Bool { app.language == "ar" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header ────────────────────────────────────────
                VStack(alignment: .leading, spacing: 2) {
                    Text(ar ? "تقدمك" : "Progress")
                        .font(.system(size: 26, weight: .heavy))
                        .kerning(ar ? 0 : -0.5)
                        .foregroundColor(HexTheme.text)
                    Text(ar
                         ? "تابع تطورك أسبوعاً بعد أسبوع"
                         : "Track your gains week over week")
                        .font(.system(size: 13))
                        .foregroundColor(HexTheme.dim)
                }
                .padding(.bottom, 24)

                // ── Tracked lifts ────────────────────────────────
                sectionHeader(label: ar ? "أوزانك" : "TRACKED LIFTS",
                              trailingIcon: "plus.circle.fill")
                    .padding(.bottom, 10)

                liftsGrid
                    .padding(.bottom, 24)

                // ── Muscle progress ──────────────────────────────
                sectionHeader(label: ar ? "تقدم العضلات" : "MUSCLE PROGRESS",
                              trailingIcon: nil)
                    .padding(.bottom, 10)

                muscleProgressCard
                    .padding(.bottom, 16)

                // ── Most improved card ───────────────────────────
                mostImprovedCard

                Spacer(minLength: 100) // room for floating tab bar
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(HexTheme.bg.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: - Sections

    private func sectionHeader(label: String, trailingIcon: String?) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .kerning(ar ? 0 : 0.9)
                .foregroundColor(HexTheme.dim)
            Spacer()
            if let icon = trailingIcon {
                Button { /* TODO: open lift picker */ } label: {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(HexTheme.accent)
                }
            }
        }
    }

    private var liftsGrid: some View {
        let lifts = trackedLifts
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                   GridItem(.flexible(), spacing: 10)],
                         spacing: 10) {
            ForEach(0..<4, id: \.self) { i in
                if i < lifts.count {
                    NavigationLink {
                        ExerciseLiftPage(exerciseName: lifts[i])
                            .environmentObject(app)
                    } label: {
                        liftCard(name: lifts[i])
                    }
                    .buttonStyle(.plain)
                } else {
                    liftCard(name: nil)
                }
            }
        }
    }

    /// Tracked lifts — derived from the user's workout history (top 4 by
    /// frequency). Mirrors how ProgressTab.jsx picks which lifts to plot.
    private var trackedLifts: [String] {
        var counts: [String: Int] = [:]
        for session in app.workoutHistory {
            for ex in session.data?.exercises ?? [] {
                counts[ex.name, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(4).map(\.key)
    }

    /// Latest logged weight for a lift name (workoutHistory is newest first).
    private func currentWeight(for name: String) -> Double? {
        for session in app.workoutHistory {
            if let ex = session.data?.exercises.first(where: { $0.name == name }),
               let w = ex.weight, w > 0 {
                return w
            }
        }
        return nil
    }

    /// Up to 8 most-recent weights for the sparkline (oldest → newest).
    private func sparklineWeights(for name: String) -> [Double] {
        var out: [Double] = []
        for session in app.workoutHistory {
            if let ex = session.data?.exercises.first(where: { $0.name == name }),
               let w = ex.weight, w > 0 {
                out.append(w)
                if out.count >= 8 { break }
            }
        }
        return out.reversed()
    }

    /// One tracked-lift card. Empty layout (placeholder text + grey bars)
    /// when `name` is nil — same look as before.
    @ViewBuilder
    private func liftCard(name: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name ?? (ar ? "اختر تمريناً" : "Pick a lift"))
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(name == nil ? HexTheme.dim : HexTheme.text)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(HexTheme.mute)
            }

            if let name = name, let w = currentWeight(for: name) {
                Text(formatCardWeight(w))
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(HexTheme.text)
                    .padding(.top, 2)
            } else {
                Text("—")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(HexTheme.text)
                    .padding(.top, 2)
            }

            sparkline(weights: name.map(sparklineWeights) ?? [])
                .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HexTheme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1)
        )
    }

    /// 8-bar sparkline. Empty data → 8 grey placeholder bars (same look
    /// as the original placeholder). With data, bars scale to the max.
    private func sparkline(weights: [Double]) -> some View {
        let maxBars = 8
        let maxW = max(weights.max() ?? 1, 1)
        return HStack(spacing: 3) {
            ForEach(0..<maxBars, id: \.self) { i in
                let w = i < weights.count ? weights[i] : nil
                if let w = w {
                    Capsule()
                        .fill(HexTheme.accent)
                        .frame(width: 3,
                               height: max(4, CGFloat(w / maxW) * 16))
                } else {
                    Capsule()
                        .fill(HexTheme.border)
                        .frame(width: 3, height: 16)
                }
            }
        }
        .frame(height: 16, alignment: .bottom)
    }

    private func formatCardWeight(_ w: Double) -> String {
        let int = Int(w.rounded())
        return "\(int) kg"
    }

    private var muscleProgressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 6 muscle group bars — each is a NavigationLink to MusclePage
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(muscleStats, id: \.id) { stat in
                    NavigationLink {
                        MusclePage(muscleId: stat.id)
                            .environmentObject(app)
                    } label: {
                        muscleBar(stat: stat)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 130)

            // Legend
            HStack {
                Text(legendText)
                    .font(.system(size: 11))
                    .foregroundColor(HexTheme.mute)
                Spacer()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HexTheme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1)
        )
    }

    /// One bar in the chart — height proportional to pct (clamped 0-100).
    /// Inactive look matches the original placeholder when pct is 0.
    private func muscleBar(stat: MuscleStat) -> some View {
        let label = barLabel(forId: stat.id)
        let pctClamped = max(min(stat.pct, 100), 0)
        // Reserve a small minimum so even "0%" muscles read as a bar.
        let frac = stat.seen ? max(CGFloat(pctClamped) / 100.0, 0.06) : 0.04
        let isActive = stat.pct > 0

        return VStack(spacing: 6) {
            Spacer(minLength: 0)
            GeometryReader { geo in
                VStack {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive ? HexTheme.accent : HexTheme.border)
                        .frame(height: max(8, geo.size.height * frac))
                }
            }
            // Label
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(isActive ? HexTheme.text : HexTheme.mute)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    /// Subtitle under the muscle chart — copy from React.
    private var legendText: String {
        let hasData = muscleStats.contains(where: { $0.pct > 0 })
        if hasData {
            return ar ? "اضغط على عضلة لعرض التفاصيل" : "Tap a muscle to see details"
        }
        return ar ? "سجّل تمرينين على الأقل لرؤية تقدمك" : "Log 2+ workouts to see your progress"
    }

    private var mostImprovedCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(HexTheme.accent.opacity(0.12))
                Image(systemName: "trophy.fill")
                    .font(.system(size: 18))
                    .foregroundColor(HexTheme.accent)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(ar ? "الأكثر تحسناً" : "MOST IMPROVED")
                    .font(.system(size: 10, weight: .heavy))
                    .kerning(ar ? 0 : 0.9)
                    .foregroundColor(HexTheme.dim)
                Text(ar ? "ابدأ بتسجيل تمارينك" : "Start logging to see")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(HexTheme.text)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HexTheme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Muscle bar data

    /// One row of the muscle progress chart.
    /// - `id`: group key from MuscleUtils (chest | back | shoulders | arms | legs | core)
    /// - `pct`: average improvement % across exercises mapped to this group
    /// - `seen`: true when the user has logged at least one set tagged to
    ///           this group, even if not enough sessions for an improvement.
    private struct MuscleStat { let id: String; let pct: Int; let seen: Bool }

    /// Aggregate stats per muscle group computed from `workoutHistory`.
    /// Mirrors the MuscleProgressChart aggregator in ProgressTab.jsx.
    private var muscleStats: [MuscleStat] {
        // 1. exercises grouped by name across all sessions → list of weights
        struct Entry { var muscle: String; var weights: [Double] = [] }
        var byName: [String: Entry] = [:]
        // workoutHistory is newest-first; reverse so we accumulate oldest → newest
        for session in app.workoutHistory.reversed() {
            for ex in session.data?.exercises ?? [] {
                guard let muscle = MuscleUtils.resolveMuscle(name: ex.name) else { continue }
                var e = byName[ex.name] ?? Entry(muscle: muscle)
                if let w = ex.weight, w > 0 { e.weights.append(w) }
                byName[ex.name] = e
            }
        }

        // 2. Per group: collect improvement % from exercises with ≥2 weights;
        //    also mark a group as "seen" if any logged exercise maps to it.
        var pctsByGroup: [String: [Double]] = [:]
        var seenByGroup: Set<String>        = []
        for (_, entry) in byName {
            for mg in MuscleUtils.groups where mg.muscles.contains(entry.muscle) {
                seenByGroup.insert(mg.id)
                if entry.weights.count >= 2,
                   let first = entry.weights.first, first > 0,
                   let last = entry.weights.last {
                    pctsByGroup[mg.id, default: []].append((last - first) / first * 100)
                }
            }
        }

        // 3. Final per-group average (clamped to 0 for bar height).
        return MuscleUtils.groups.map { mg in
            let pcts = pctsByGroup[mg.id] ?? []
            let avg  = pcts.isEmpty ? 0 : pcts.reduce(0, +) / Double(pcts.count)
            return MuscleStat(
                id:   mg.id,
                pct:  Int(max(avg, 0).rounded()),
                seen: seenByGroup.contains(mg.id)
            )
        }
    }

    /// Short label used under each chart bar — keeps the original UI text.
    private func barLabel(forId id: String) -> String {
        if ar {
            switch id {
            case "chest":     return "صدر"
            case "back":      return "ظهر"
            case "shoulders": return "كتف"
            case "arms":      return "ذراع"
            case "legs":      return "أرجل"
            case "core":      return "بطن"
            default:          return id
            }
        }
        switch id {
        case "chest":     return "Chest"
        case "back":      return "Back"
        case "shoulders": return "Shldr"
        case "arms":      return "Arms"
        case "legs":      return "Legs"
        case "core":      return "Core"
        default:          return id.capitalized
        }
    }
}
