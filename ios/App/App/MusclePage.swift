import SwiftUI

/// Muscle-group detail page — port of src/components/MusclePage.jsx.
/// Slides in from the Progress tab when a muscle bar is tapped. Loads all
/// sets for the user, filters to the group via MuscleUtils, and shows:
///   1. Sticky header (back + label + "N sessions · N exercises")
///   2. 3-card summary row (OVERALL %, TOTAL VOLUME, EXERCISES)
///   3. Strongest mover card (+ mini sparkline)
///   4. All-exercises list with per-row progress bar
///   5. Weekly trend chart (% vs baseline)
struct MusclePage: View {
    let muscleId: String

    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var allSets: [PerformedSet]? = nil   // nil = loading
    @State private var failed: Bool = false

    private var ar: Bool { app.language == "ar" }

    private var muscleGroup: MuscleUtils.MuscleGroup? {
        MuscleUtils.group(id: muscleId)
    }

    var body: some View {
        ZStack(alignment: .top) {
            HexTheme.bg.ignoresSafeArea()

            ScrollView {
                content
                    .padding(.horizontal, 20)
                    .padding(.top, 84)
                    .padding(.bottom, 52)
            }

            stickyHeader
        }
        .navigationBarHidden(true)
        .task { await load() }
    }

    // MARK: - Sticky header

    private var stickyHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: ar ? "chevron.right" : "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(HexTheme.text)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(HexTheme.surface2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(HexTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(headerTitle)
                        .font(.system(size: 22, weight: .heavy))
                        .kerning(ar ? 0 : -0.2)
                        .foregroundColor(HexTheme.text)
                    Text(headerSubtitle)
                        .font(.system(size: 12))
                        .foregroundColor(HexTheme.dim)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Rectangle().fill(HexTheme.border).frame(height: 1)
        }
        .background(HexTheme.bg)
    }

    private var headerTitle: String {
        guard let g = muscleGroup else { return "" }
        if !ar { return g.label }
        // Arabic labels
        switch g.id {
        case "chest":     return "صدر"
        case "back":      return "ظهر"
        case "shoulders": return "أكتاف"
        case "arms":      return "ذراع"
        case "legs":      return "أرجل"
        case "core":      return "بطن"
        default:          return g.label
        }
    }

    private var headerSubtitle: String {
        if allSets == nil { return ar ? "جاري التحميل…" : "Loading…" }
        let s = uniqueSessions
        let e = exerciseStats.count
        if ar {
            return "\(s) جلسة · \(e) تمرين متتبع"
        }
        return "\(s) session\(s == 1 ? "" : "s") · \(e) exercise\(e == 1 ? "" : "s") tracked"
    }

    // MARK: - Body content

    @ViewBuilder
    private var content: some View {
        if failed {
            errorState
        } else if allSets == nil {
            loadingState
        } else if muscleSets.isEmpty {
            emptyState
        } else {
            dataState
        }
    }

    private var loadingState: some View {
        Spinner()
            .frame(width: 28, height: 28)
            .padding(.top, 60)
            .frame(maxWidth: .infinity)
    }

    private var errorState: some View {
        Text(ar
             ? "تعذّر تحميل البيانات. حاول مرة أخرى."
             : "Failed to load data. Please try again.")
            .font(.system(size: 13))
            .foregroundColor(HexTheme.dim)
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("💪")
                .font(.system(size: 40))
            Text(ar
                 ? "لا جلسات مسجلة لـ\(headerTitle) بعد"
                 : "No sessions logged for \(muscleGroup?.label ?? "") yet")
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(HexTheme.text)
                .multilineTextAlignment(.center)
            Text(ar
                 ? "أكمل جلسة للبدء في التتبع."
                 : "Complete a session to start tracking.")
                .font(.system(size: 13))
                .foregroundColor(HexTheme.dim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var dataState: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryRow
                .padding(.bottom, 24)

            if let mover = strongestMover {
                strongestMoverSection(mover: mover)
                    .padding(.bottom, 24)
            }

            allExercisesSection
                .padding(.bottom, 24)

            if trendData.count >= 2 {
                trendSection
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Summary row

    private var summaryRow: some View {
        HStack(spacing: 8) {
            statCard(label: ar ? "الإجمالي" : "OVERALL",
                     value: overallPct > 0 ? "+\(overallPct)%" : "0%",
                     accent: overallPct > 0)
            statCard(label: ar ? "الحجم الكلي" : "TOTAL VOLUME",
                     value: "\(formatVolume(totalVolume)) kg")
            statCard(label: ar ? "تمارين" : "EXERCISES",
                     value: "\(exerciseStats.count)")
        }
    }

    private func statCard(label: String, value: String, accent: Bool = false) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .kerning(ar ? 0 : 0.6)
                .foregroundColor(HexTheme.dim)
            Text(value)
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(accent ? HexTheme.accent : HexTheme.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(HexTheme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Strongest mover

    private func strongestMoverSection(mover: ExerciseStat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ar ? "الأكثر تحسناً" : "STRONGEST MOVER")
                .font(.system(size: 11, weight: .heavy))
                .kerning(ar ? 0 : 0.8)
                .foregroundColor(HexTheme.dim)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        // "MOST IMPROVED" pill
                        Text(ar ? "الأكثر تحسناً" : "MOST IMPROVED")
                            .font(.system(size: 9, weight: .heavy))
                            .kerning(ar ? 0 : 0.4)
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(HexTheme.accent)
                            )
                            .padding(.bottom, 4)
                        Text(mover.name)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundColor(HexTheme.text)
                        Text(weightRangeLabel(first: mover.firstW, last: mover.lastW))
                            .font(.system(size: 12))
                            .foregroundColor(HexTheme.dim)
                    }
                    Spacer()
                    Text(mover.pct > 0 ? "+\(mover.pct)%" : "—")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundColor(mover.pct > 0 ? HexTheme.accent : HexTheme.dim)
                }

                MiniSparkline(values: mover.sparkData)
                    .frame(height: 28)
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
    }

    private func weightRangeLabel(first: Double?, last: Double?) -> String {
        let f = first.map { "\(formatKg($0)) kg" } ?? "—"
        let l = last.map  { "\(formatKg($0)) kg" } ?? "—"
        return "\(f) → \(l)"
    }

    // MARK: - All exercises list

    private var allExercisesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ar ? "كل التمارين" : "ALL EXERCISES")
                .font(.system(size: 11, weight: .heavy))
                .kerning(ar ? 0 : 0.8)
                .foregroundColor(HexTheme.dim)

            VStack(spacing: 8) {
                ForEach(exerciseStats, id: \.name) { ex in
                    exerciseRow(ex)
                }
            }
        }
    }

    private func exerciseRow(_ ex: ExerciseStat) -> some View {
        let best = max(bestPct, 1)
        let barFrac = (best > 0 && ex.pct > 0) ? max(Double(ex.pct) / Double(best), 0.04) : 0

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ex.name)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(HexTheme.text)
                    Text(rowSubtitle(ex: ex))
                        .font(.system(size: 11))
                        .foregroundColor(HexTheme.dim)
                }
                Spacer()
                Text(ex.pct > 0 ? "+\(ex.pct)%" : "0%")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(ex.pct > 0 ? HexTheme.accent : HexTheme.mute)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(HexTheme.border)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ex.pct > 0 ? HexTheme.accent : Color.white.opacity(0.10))
                        .frame(width: geo.size.width * CGFloat(barFrac), height: 4)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: barFrac)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 14)
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

    private func rowSubtitle(ex: ExerciseStat) -> String {
        var s = ""
        if let f = ex.firstW, let l = ex.lastW {
            s = "\(formatKg(f)) kg → \(formatKg(l)) kg"
        } else {
            s = "—"
        }
        if let d = ex.lastDate {
            s += "  ·  \(formatShortDate(d))"
        }
        return s
    }

    // MARK: - Trend chart section

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ar
                 ? "اتجاه \(headerTitle)"
                 : "\((muscleGroup?.label ?? "").uppercased()) TREND")
                .font(.system(size: 11, weight: .heavy))
                .kerning(ar ? 0 : 0.8)
                .foregroundColor(HexTheme.dim)

            TrendChart(points: trendData)
                .frame(height: 130)
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 8)
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
    }

    // MARK: - Data load

    /// Pulls performed sets and unions in synthesized rows for any
    /// session that touched a relevant exercise but never wrote to
    /// the `sets` table (legacy pre-7d0a1d1 sessions had their set
    /// rows silently dropped due to a key-mismatch bug — the session
    /// row still landed in `sessions`, so the data is recoverable
    /// from `data.exercises[]`).
    ///
    /// Also back-fills `reps` on real rows that came in with `nil`,
    /// by parsing the prescription off the matching session.
    ///
    /// Mirrors what `ExerciseLiftPage.load()` does for a single
    /// exercise — same logic, just unscoped here because MusclePage
    /// summarises every exercise in the group.
    private func load() async {
        do {
            let fetched = try await SupabaseManager.shared.fetchAllSets(limit: 2000)

            // Build a per-session map of (exercise, date) for every
            // exercise in workoutHistory. Multiple exercises can share
            // a session, so the value is an array.
            var sessionToExercises: [UUID: (Date, [Exercise])] = [:]
            for session in app.workoutHistory {
                let exs = session.data?.exercises ?? []
                if !exs.isEmpty {
                    sessionToExercises[session.id] = (session.date, exs)
                }
            }

            // (1) Patch nil reps on real set rows by parsing the
            //     matching session's exercise prescription.
            var combined: [PerformedSet] = fetched.map { row in
                guard row.reps == nil,
                      let (_, exs) = sessionToExercises[row.sessionId],
                      let ex = exs.first(where: {
                          $0.name.lowercased() == row.exerciseName.lowercased()
                      }),
                      let parsed = ExerciseLiftPage.parsePrescriptionReps(ex.reps)
                else { return row }
                var copy = row
                copy.reps = parsed
                return copy
            }

            // (2) Synthesize rows for `(session, exercise)` pairs that
            //     have no representation in the `sets` table at all.
            //     Key by (sessionId, exerciseName.lowercased) so we
            //     only synthesize what's actually missing.
            let covered: Set<String> = Set(fetched.map { row in
                "\(row.sessionId.uuidString)|\(row.exerciseName.lowercased())"
            })
            if let uid = SupabaseManager.shared.currentUser?.id {
                for (sid, (date, exs)) in sessionToExercises {
                    for ex in exs {
                        let key = "\(sid.uuidString)|\(ex.name.lowercased())"
                        if covered.contains(key) { continue }
                        // Skip rows with no recorded weight — they'd
                        // produce zero-weight points in the chart.
                        guard let w = ex.weight, w > 0 else { continue }
                        let setCount = max(ex.sets, 1)
                        let parsedReps = ExerciseLiftPage.parsePrescriptionReps(ex.reps)
                        for setIdx in 0..<setCount {
                            combined.append(PerformedSet(
                                id:           UUID(),
                                sessionId:    sid,
                                userId:       uid,
                                exerciseName: ex.name,
                                setNumber:    setIdx + 1,
                                reps:         parsedReps,
                                weight:       w,
                                rpe:          nil,
                                completed:    true,
                                failed:       false,
                                createdAt:    date
                            ))
                        }
                    }
                }
            }

            allSets = combined.sorted { lhs, rhs in
                let l = lhs.createdAt ?? .distantPast
                let r = rhs.createdAt ?? .distantPast
                return l < r
            }
            failed = false
        } catch {
            print("[MusclePage] load failed:", error)
            failed = true
        }
    }

    // MARK: - Derived data

    /// Sets matching this muscle group.
    private var muscleSets: [PerformedSet] {
        guard let mg = muscleGroup, let sets = allSets else { return [] }
        return sets.filter { s in
            guard let m = MuscleUtils.resolveMuscle(fromName: s.exerciseName) else { return false }
            return mg.muscles.contains(m)
        }
    }

    /// Per-exercise stat row, sorted by improvement % descending.
    struct ExerciseStat {
        let name: String
        let firstW: Double?
        let lastW: Double?
        let pct: Int
        let lastDate: Date?
        let sparkData: [Double]   // max weight per session (chronological)
    }

    private var exerciseStats: [ExerciseStat] {
        var byName: [String: [PerformedSet]] = [:]
        for s in muscleSets {
            byName[s.exerciseName, default: []].append(s)
        }
        let stats = byName.map { (name, sets) -> ExerciseStat in
            let sorted = sets.sorted {
                ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast)
            }
            let first = sorted.first?.weight
            let last  = sorted.last?.weight
            let pct: Int
            if let f = first, let l = last, f > 0 {
                pct = Int(((l - f) / f * 100).rounded())
            } else {
                pct = 0
            }
            // Spark data: max weight per session id (fallback yyyy-MM-dd)
            var sessMap: [String: Double] = [:]
            for s in sorted {
                guard let w = s.weight, w > 0 else { continue }
                let key = !s.sessionId.uuidString.isEmpty
                    ? s.sessionId.uuidString
                    : MusclePage.dayKey(s.createdAt ?? Date())
                sessMap[key] = max(sessMap[key] ?? 0, w)
            }
            return ExerciseStat(
                name: name,
                firstW: first, lastW: last, pct: pct,
                lastDate: sorted.last?.createdAt,
                sparkData: Array(sessMap.values)
            )
        }
        return stats.sorted { $0.pct > $1.pct }
    }

    private var uniqueSessions: Int {
        var keys = Set<String>()
        for s in muscleSets {
            let k = !s.sessionId.uuidString.isEmpty
                ? s.sessionId.uuidString
                : MusclePage.dayKey(s.createdAt ?? Date())
            keys.insert(k)
        }
        return keys.count
    }

    private var totalVolume: Double {
        muscleSets.reduce(0) { acc, s in
            let w = s.weight ?? 0
            let reps = MusclePage.repsLower(s.reps.map(String.init))
            return acc + w * Double(reps)
        }
    }

    private var overallPct: Int {
        let improved = exerciseStats.filter { ($0.firstW ?? 0) > 0 && $0.lastW != nil }
        guard !improved.isEmpty else { return 0 }
        let total = improved.reduce(0.0) { acc, e in
            let f = e.firstW ?? 0
            let l = e.lastW  ?? 0
            return acc + ((l - f) / f) * 100
        }
        return Int((total / Double(improved.count)).rounded())
    }

    private var bestPct: Int {
        exerciseStats.map(\.pct).max() ?? 0
    }

    private var strongestMover: ExerciseStat? {
        if let positive = exerciseStats.first(where: { $0.pct > 0 }) { return positive }
        return exerciseStats.first
    }

    /// Per-week average improvement % vs each exercise's all-time baseline.
    struct TrendPoint: Identifiable {
        let id = UUID()
        let label: String
        let pct: Double
    }

    private var trendData: [TrendPoint] {
        guard !muscleSets.isEmpty, !exerciseStats.isEmpty else { return [] }
        let baseline = Dictionary(uniqueKeysWithValues:
            exerciseStats.compactMap { e -> (String, Double)? in
                if let f = e.firstW, f > 0 { return (e.name, f) }
                return nil
            })

        var weekMap: [String: [String: Double]] = [:]
        let cal = Calendar(identifier: .gregorian)
        for s in muscleSets {
            guard let date = s.createdAt, let w = s.weight, w > 0 else { continue }
            // Monday of this week as yyyy-MM-dd
            let dow = cal.component(.weekday, from: date)          // 1=Sun..7=Sat
            let dayDelta = (dow == 1 ? 6 : dow - 2)                // back to Mon
            guard let monday = cal.date(byAdding: .day, value: -dayDelta, to: date) else { continue }
            let key = MusclePage.dayKey(monday)
            var ex = weekMap[key] ?? [:]
            ex[s.exerciseName] = max(ex[s.exerciseName] ?? 0, w)
            weekMap[key] = ex
        }

        let sortedKeys = weekMap.keys.sorted()
        return sortedKeys.enumerated().map { idx, key -> TrendPoint in
            let entries = weekMap[key] ?? [:]
            var pcts: [Double] = []
            for (name, maxW) in entries {
                if let base = baseline[name], base > 0 {
                    pcts.append((maxW - base) / base * 100)
                } else {
                    pcts.append(0)
                }
            }
            let avg = pcts.isEmpty ? 0 : pcts.reduce(0, +) / Double(pcts.count)
            return TrendPoint(label: "W\(idx + 1)",
                              pct: (avg * 10).rounded() / 10)
        }
    }

    // MARK: - Formatting helpers

    private static func dayKey(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: d)
    }

    private static func repsLower(_ raw: String?) -> Int {
        guard let raw = raw else { return 0 }
        let first = raw.split(separator: "-").first.map(String.init) ?? raw
        return Int(first) ?? 0
    }

    private func formatVolume(_ v: Double) -> String {
        if v >= 10000 { return "\(Int((v / 1000).rounded()))k" }
        if v >= 1000  { return String(format: "%.1fk", (v / 100).rounded() / 10) }
        return "\(Int(v.rounded()))"
    }

    private func formatKg(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(v))
            : String(format: "%.1f", v)
    }

    private func formatShortDate(_ d: Date) -> String {
        let cal = Calendar.current
        return "\(cal.component(.day, from: d))/\(cal.component(.month, from: d))"
    }
}

// MARK: - Mini sparkline (80 × 28)

private struct MiniSparkline: View {
    let values: [Double]
    var body: some View {
        GeometryReader { geo in
            if values.isEmpty {
                EmptyView()
            } else if values.count == 1 {
                Circle()
                    .fill(HexTheme.accent)
                    .frame(width: 6, height: 6)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            } else {
                let minV = values.min() ?? 0
                let maxV = values.max() ?? 1
                let range = max(maxV - minV, 1)
                let pts: [CGPoint] = values.enumerated().map { i, v in
                    let x = CGFloat(i) / CGFloat(values.count - 1) * geo.size.width
                    let y = geo.size.height
                          - CGFloat((v - minV) / range) * (geo.size.height - 4) - 2
                    return CGPoint(x: x, y: y)
                }
                ZStack {
                    Path { p in
                        for (i, pt) in pts.enumerated() {
                            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                        }
                    }
                    .stroke(HexTheme.accent,
                            style: StrokeStyle(lineWidth: 1.5,
                                               lineCap: .round,
                                               lineJoin: .round))
                    if let last = pts.last {
                        Circle()
                            .fill(HexTheme.accent)
                            .frame(width: 5, height: 5)
                            .position(last)
                    }
                }
            }
        }
    }
}

// MARK: - Trend chart (335 × 130, with Y gridlines + X labels)

private struct TrendChart: View {
    let points: [MusclePage.TrendPoint]

    var body: some View {
        GeometryReader { geo in
            if points.count < 2 {
                EmptyView()
            } else {
                let layout = ChartLayout(values: points.map(\.pct), size: geo.size)

                ZStack {
                    // Y gridlines + labels
                    ForEach(0..<layout.yTicks.count, id: \.self) { i in
                        let y = layout.scaleY(layout.yTicks[i])
                        Rectangle()
                            .fill(HexTheme.border)
                            .frame(width: layout.chartWidth, height: 1)
                            .position(x: layout.pad.leading + layout.chartWidth / 2, y: y)
                        Text("\(Int(layout.yTicks[i].rounded()))%")
                            .font(.system(size: 8))
                            .foregroundColor(HexTheme.mute)
                            .position(x: layout.pad.leading - 12, y: y)
                    }

                    // X baseline
                    Rectangle()
                        .fill(HexTheme.border)
                        .frame(width: layout.chartWidth, height: 1)
                        .position(x: layout.pad.leading + layout.chartWidth / 2,
                                  y: layout.pad.top + layout.chartHeight)

                    // Area + line
                    AreaShape(points: points, layout: layout)
                        .fill(HexTheme.accent.opacity(0.06))
                    LineShape(points: points, layout: layout)
                        .stroke(HexTheme.accent,
                                style: StrokeStyle(lineWidth: 2,
                                                   lineCap: .round,
                                                   lineJoin: .round))

                    // Dots
                    ForEach(Array(points.enumerated()), id: \.offset) { idx, _ in
                        let isLast = idx == points.count - 1
                        Circle()
                            .stroke(HexTheme.accent, lineWidth: 1.5)
                            .background(
                                Circle().fill(isLast ? HexTheme.accent : HexTheme.surface2)
                            )
                            .frame(width: isLast ? 8 : 5, height: isLast ? 8 : 5)
                            .position(x: layout.scaleX(idx),
                                      y: layout.scaleY(points[idx].pct))
                    }

                    // X labels (every week)
                    ForEach(Array(points.enumerated()), id: \.offset) { idx, p in
                        Text(p.label)
                            .font(.system(size: 8))
                            .foregroundColor(HexTheme.mute)
                            .position(x: layout.scaleX(idx),
                                      y: layout.pad.top + layout.chartHeight + 14)
                    }
                }
            }
        }
    }

    struct ChartLayout {
        let pad: (top: CGFloat, leading: CGFloat, trailing: CGFloat, bottom: CGFloat)
            = (top: 18, leading: 34, trailing: 14, bottom: 24)
        let chartWidth: CGFloat
        let chartHeight: CGFloat
        let count: Int
        let yLo: Double
        let yHi: Double
        let yTicks: [Double]

        init(values: [Double], size: CGSize) {
            chartWidth  = max(0, size.width  - pad.leading - pad.trailing)
            chartHeight = max(0, size.height - pad.top     - pad.bottom)
            count = values.count
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let padY = max((maxV - minV) * 0.15, 2)
            yLo = minV - padY
            yHi = maxV + padY
            yTicks = [minV, (minV + maxV) / 2, maxV]
        }

        func scaleX(_ idx: Int) -> CGFloat {
            guard count > 1 else { return pad.leading + chartWidth / 2 }
            return pad.leading + CGFloat(idx) / CGFloat(count - 1) * chartWidth
        }

        func scaleY(_ v: Double) -> CGFloat {
            let range = yHi - yLo
            guard range > 0 else { return pad.top + chartHeight / 2 }
            return pad.top + chartHeight - CGFloat((v - yLo) / range) * chartHeight
        }
    }

    private struct LineShape: Shape {
        let points: [MusclePage.TrendPoint]
        let layout: ChartLayout
        func path(in rect: CGRect) -> Path {
            var p = Path()
            for (i, point) in points.enumerated() {
                let pt = CGPoint(x: layout.scaleX(i), y: layout.scaleY(point.pct))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            return p
        }
    }

    private struct AreaShape: Shape {
        let points: [MusclePage.TrendPoint]
        let layout: ChartLayout
        func path(in rect: CGRect) -> Path {
            guard !points.isEmpty else { return Path() }
            var p = Path()
            let baseline = layout.pad.top + layout.chartHeight
            p.move(to: CGPoint(x: layout.scaleX(0), y: layout.scaleY(points[0].pct)))
            for i in 1..<points.count {
                p.addLine(to: CGPoint(x: layout.scaleX(i),
                                      y: layout.scaleY(points[i].pct)))
            }
            p.addLine(to: CGPoint(x: layout.scaleX(points.count - 1), y: baseline))
            p.addLine(to: CGPoint(x: layout.scaleX(0), y: baseline))
            p.closeSubpath()
            return p
        }
    }
}

// MARK: - Spinner (shared visual with ExerciseLiftPage)

private struct Spinner: View {
    @State private var rotating = false
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(HexTheme.accent,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .rotationEffect(.degrees(rotating ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false),
                       value: rotating)
            .onAppear { rotating = true }
    }
}
