import SwiftUI

/// Single-lift drill-down — port of src/components/ExerciseLiftPage.jsx.
/// Slides in over the Progress tab. Header with chevron-back + exercise
/// name + sessions count, then loading / error / empty / data states.
/// Data state shows: 4-stat row (START / CURRENT / INCREASE / SESSIONS),
/// optional +% improvement badge, a line-chart card, and a per-session
/// table. Pulls rows from the `sets` table via SupabaseManager.
struct ExerciseLiftPage: View {
    let exerciseName: String

    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    /// nil = still loading, [] = no data, [..] = loaded rows (oldest first).
    @State private var rows: [PerformedSet]? = nil
    @State private var failed: Bool = false

    private var ar: Bool { app.language == "ar" }

    var body: some View {
        ZStack(alignment: .top) {
            HexTheme.bg.ignoresSafeArea()

            ScrollView {
                content
                    .padding(.horizontal, 20)
                    .padding(.top, 80)         // breathing room below sticky header
                    .padding(.bottom, 40)
            }

            stickyHeader   // overlaid so it stays put while scrolling
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

                VStack(alignment: .leading, spacing: 1) {
                    Text(exerciseName)
                        .font(.system(size: 18, weight: .heavy))
                        .kerning(ar ? 0 : -0.2)
                        .foregroundColor(HexTheme.text)
                    Text(subtitle)
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

    private var subtitle: String {
        if rows == nil {
            return ar ? "جاري التحميل…" : "Loading…"
        }
        let n = uniqueSessions
        if ar { return "\(n) جلسات مسجلة" }
        return "\(n) session\(n == 1 ? "" : "s") logged"
    }

    // MARK: - Body content (state branches)

    @ViewBuilder
    private var content: some View {
        if failed {
            errorState
        } else if rows == nil {
            loadingState
        } else if rows?.isEmpty == true {
            emptyState
        } else {
            dataState
        }
    }

    private var loadingState: some View {
        VStack {
            Spinner()
                .frame(width: 28, height: 28)
                .padding(.top, 60)
        }
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
            Text("📊")
                .font(.system(size: 32))
            Text(ar ? "لم تُسجَّل جلسات بعد" : "No sessions logged yet")
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(HexTheme.text)
            Text(ar
                 ? "أكمل جلسة مع \(exerciseName) للبدء في تتبع التقدم."
                 : "Complete a session with \(exerciseName) to start tracking progress.")
                .font(.system(size: 13))
                .foregroundColor(HexTheme.dim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var dataState: some View {
        let rows  = rows ?? []
        let stats = computeStats(rows: rows)
        let chart = toChartData(rows: rows)
        let table = groupBySession(rows: rows)

        return VStack(alignment: .leading, spacing: 0) {
            // ── Stat pills ──────────────────────────────────────────
            HStack(spacing: 8) {
                stat(label: ar ? "البداية"  : "START",
                     value: stats.first.map { "\(formatKg($0)) kg" } ?? "—")
                stat(label: ar ? "الحالي" : "CURRENT",
                     value: stats.last.map  { "\(formatKg($0)) kg" } ?? "—",
                     accent: true)
                stat(label: ar ? "الزيادة" : "INCREASE",
                     value: stats.delta.map { "\($0 >= 0 ? "+" : "")\(formatKg($0)) kg" } ?? "—",
                     accent: (stats.delta ?? 0) > 0)
                stat(label: ar ? "جلسات" : "SESSIONS",
                     value: "\(uniqueSessions)")
            }
            .padding(.bottom, 24)

            // ── Improvement badge ───────────────────────────────────
            if let pct = stats.pct, (stats.delta ?? 0) > 0 {
                HStack(spacing: 8) {
                    Text("📈").font(.system(size: 18))
                    Text(ar
                         ? "أقوى بنسبة +\(pct)% منذ بدايتك"
                         : "+\(pct)% stronger since you started")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(HexTheme.accent)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(HexTheme.accent.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(HexTheme.accent.opacity(0.25), lineWidth: 1)
                )
                .padding(.bottom, 20)
            }

            // ── Chart card ──────────────────────────────────────────
            VStack(alignment: .leading, spacing: 12) {
                Text(ar ? "الوزن عبر الوقت (كجم)" : "WEIGHT OVER TIME (kg)")
                    .font(.system(size: 11, weight: .heavy))
                    .kerning(ar ? 0 : 0.6)
                    .foregroundColor(HexTheme.dim)
                LineChart(points: chart)
                    .frame(height: chart.count <= 1 ? 120 : 180)
            }
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
            .padding(.bottom, 24)

            // ── Session log table ───────────────────────────────────
            Text(ar ? "سجل الجلسات" : "SESSION LOG")
                .font(.system(size: 11, weight: .heavy))
                .kerning(ar ? 0 : 0.6)
                .foregroundColor(HexTheme.dim)
                .padding(.bottom, 12)

            sessionTable(rows: table)
        }
    }

    // MARK: - Stat pill

    private func stat(label: String, value: String, accent: Bool = false) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .kerning(ar ? 0 : 0.7)
                .foregroundColor(HexTheme.dim)
            Text(value)
                .font(.system(size: 17, weight: .heavy))
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

    // MARK: - Session log table

    private func sessionTable(rows: [SessionRow]) -> some View {
        VStack(spacing: 2) {
            // Header row
            HStack {
                tableHeader(ar ? "التاريخ" : "DATE")
                tableHeader(ar ? "مج × عد" : "SETS × REPS")
                tableHeader(ar ? "وزن"     : "WEIGHT")
                tableHeader(ar ? "RPE"     : "RPE", trailing: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

            // Data rows
            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                HStack {
                    Text(formatShortDate(row.date))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(HexTheme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(row.count) × \(row.reps)")
                        .font(.system(size: 12))
                        .foregroundColor(HexTheme.dim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.weight.map { "\(formatKg($0)) kg" } ?? "—")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(idx == 0 ? HexTheme.accent : HexTheme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.rpe ?? "—")
                        .font(.system(size: 12))
                        .foregroundColor(HexTheme.dim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(HexTheme.surface2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(HexTheme.border, lineWidth: 1)
                )
            }
        }
    }

    private func tableHeader(_ text: String, trailing: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .kerning(ar ? 0 : 0.4)
            .foregroundColor(HexTheme.mute)
            .frame(maxWidth: .infinity, alignment: trailing ? .leading : .leading)
    }

    // MARK: - Data loading

    private func load() async {
        do {
            let fetched = try await SupabaseManager.shared
                .fetchAllSets(exerciseName: exerciseName, limit: 500)
            // fetchAllSets returns DESC by created_at; the chart helpers
            // expect oldest-first, so reverse here once.
            rows = fetched.reversed()
            failed = false
        } catch {
            print("[ExerciseLiftPage] load failed:", error)
            failed = true
        }
    }

    // MARK: - Derived data

    /// One bucket per session, summarised for the log table.
    struct SessionRow {
        let date: Date
        let count: Int        // total sets
        let reps: String      // reps from first set in the bucket
        let weight: Double?   // max weight across sets
        let rpe: String?
    }

    /// One bucket per session, used for the chart polyline.
    struct ChartPoint: Identifiable {
        let id = UUID()
        let date: Date
        let weight: Double
    }

    private func groupBySession(rows: [PerformedSet]) -> [SessionRow] {
        // group by session id (fallback: yyyy-MM-dd of created_at)
        var groups: [String: [PerformedSet]] = [:]
        for r in rows {
            let key: String = {
                if !r.sessionId.uuidString.isEmpty { return r.sessionId.uuidString }
                return ExerciseLiftPage.iso8601Day(r.createdAt ?? Date())
            }()
            groups[key, default: []].append(r)
        }
        let summarised: [SessionRow] = groups.values.map { bucket in
            let dates = bucket.compactMap(\.createdAt)
            let date = dates.max() ?? Date()
            let weights = bucket.compactMap(\.weight)
            let first = bucket.first
            return SessionRow(
                date: date,
                count: bucket.count,
                reps: first?.reps.map(String.init) ?? "—",
                weight: weights.max(),
                rpe: first?.rpe.map { String(format: "%g", $0) }
            )
        }
        return summarised.sorted { $0.date > $1.date }  // newest first
    }

    private func toChartData(rows: [PerformedSet]) -> [ChartPoint] {
        var byKey: [String: (date: Date, weight: Double)] = [:]
        for r in rows {
            guard let w = r.weight, w > 0 else { continue }
            let date = r.createdAt ?? Date()
            let key = !r.sessionId.uuidString.isEmpty
                ? r.sessionId.uuidString
                : ExerciseLiftPage.iso8601Day(date)
            if let existing = byKey[key] {
                if w > existing.weight { byKey[key] = (existing.date, w) }
            } else {
                byKey[key] = (date, w)
            }
        }
        return byKey.values
            .map { ChartPoint(date: $0.date, weight: $0.weight) }
            .sorted { $0.date < $1.date }
    }

    private var uniqueSessions: Int {
        Set((rows ?? []).map(\.sessionId)).count
    }

    private struct Stats {
        let first: Double?
        let last: Double?
        let delta: Double?
        let pct: Int?
    }

    private func computeStats(rows: [PerformedSet]) -> Stats {
        guard !rows.isEmpty else { return Stats(first: nil, last: nil, delta: nil, pct: nil) }
        let first = rows.first?.weight
        let last  = rows.last?.weight
        let delta: Double? = (first != nil && last != nil) ? (last! - first!) : nil
        let pct: Int?
        if let f = first, f > 0, let d = delta { pct = Int((d / f * 100).rounded()) }
        else { pct = nil }
        return Stats(first: first, last: last, delta: delta, pct: pct)
    }

    // MARK: - Formatting

    private static func iso8601Day(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: d)
    }

    private func formatKg(_ v: Double) -> String {
        // Drop trailing .0 for whole-kg values.
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(v))
            : String(format: "%.1f", v)
    }

    private func formatShortDate(_ d: Date) -> String {
        let cal = Calendar.current
        let day   = cal.component(.day,   from: d)
        let month = cal.component(.month, from: d)
        return "\(day)/\(month)"
    }
}

// MARK: - Line chart (SwiftUI Shapes)

/// Faithful port of the React SVG line chart. One polyline + filled area
/// + dots, three Y gridlines + labels, three X labels.
private struct LineChart: View {
    let points: [ExerciseLiftPage.ChartPoint]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if points.count <= 1, let only = points.first {
                    singlePointView(point: only, size: geo.size)
                } else if points.count >= 2 {
                    let layout = ChartLayout(points: points, size: geo.size)

                    // Y gridlines + labels
                    ForEach(0..<layout.yTicks.count, id: \.self) { i in
                        let y = layout.scaleY(layout.yTicks[i])
                        Rectangle()
                            .fill(HexTheme.border)
                            .frame(width: layout.chartWidth, height: 1)
                            .position(x: layout.pad.leading + layout.chartWidth / 2, y: y)
                        Text("\(Int(layout.yTicks[i].rounded()))")
                            .font(.system(size: 9))
                            .foregroundColor(HexTheme.mute)
                            .position(x: layout.pad.leading - 14, y: y)
                    }

                    // X baseline
                    Rectangle()
                        .fill(HexTheme.border)
                        .frame(width: layout.chartWidth, height: 1)
                        .position(x: layout.pad.leading + layout.chartWidth / 2,
                                  y: layout.pad.top + layout.chartHeight)

                    // Area fill
                    AreaShape(points: points, layout: layout)
                        .fill(HexTheme.accent.opacity(0.07))

                    // Polyline
                    LineShape(points: points, layout: layout)
                        .stroke(HexTheme.accent,
                                style: StrokeStyle(lineWidth: 2,
                                                   lineCap: .round,
                                                   lineJoin: .round))

                    // Dots
                    ForEach(Array(points.enumerated()), id: \.offset) { idx, p in
                        let isLast = idx == points.count - 1
                        Circle()
                            .stroke(HexTheme.accent, lineWidth: 2)
                            .background(
                                Circle().fill(isLast ? HexTheme.accent : HexTheme.surface2)
                            )
                            .frame(width: isLast ? 10 : 6, height: isLast ? 10 : 6)
                            .position(x: layout.scaleX(p.date),
                                      y: layout.scaleY(p.weight))
                    }

                    // X labels (first, middle, last — same rule as React)
                    ForEach(Array(xLabelIndices.enumerated()), id: \.offset) { _, i in
                        let p = points[i]
                        Text(formatShortDate(p.date))
                            .font(.system(size: 9))
                            .foregroundColor(HexTheme.mute)
                            .position(x: layout.scaleX(p.date),
                                      y: layout.pad.top + layout.chartHeight + 16)
                    }
                }
            }
        }
    }

    private var xLabelIndices: [Int] {
        switch points.count {
        case 0:  return []
        case 1:  return [0]
        case 2:  return [0, 1]
        default: return [0, points.count / 2, points.count - 1]
        }
    }

    private func singlePointView(point: ExerciseLiftPage.ChartPoint,
                                 size: CGSize) -> some View {
        VStack(spacing: 4) {
            Text(formatKg(point.weight) + " kg")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(HexTheme.accent)
            Circle()
                .fill(HexTheme.accent)
                .frame(width: 12, height: 12)
            Text(formatShortDate(point.date))
                .font(.system(size: 10))
                .foregroundColor(HexTheme.dim)
        }
        .frame(width: size.width, height: size.height)
    }

    private func formatShortDate(_ d: Date) -> String {
        let cal = Calendar.current
        return "\(cal.component(.day, from: d))/\(cal.component(.month, from: d))"
    }

    private func formatKg(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(v))
            : String(format: "%.1f", v)
    }
}

private struct ChartLayout {
    let pad: (top: CGFloat, leading: CGFloat, trailing: CGFloat, bottom: CGFloat)
        = (top: 20, leading: 30, trailing: 14, bottom: 26)

    let chartWidth:  CGFloat
    let chartHeight: CGFloat
    let xMin: Double
    let xMax: Double
    let yLo: Double
    let yHi: Double
    let yTicks: [Double]

    init(points: [ExerciseLiftPage.ChartPoint], size: CGSize) {
        chartWidth  = max(0, size.width  - pad.leading - pad.trailing)
        chartHeight = max(0, size.height - pad.top     - pad.bottom)

        let xs = points.map { $0.date.timeIntervalSince1970 }
        let ws = points.map { $0.weight }
        xMin = xs.min() ?? 0
        xMax = xs.max() ?? 1
        let minY = ws.min() ?? 0
        let maxY = ws.max() ?? 1
        // Same +/-12% Y padding as React (with sensible fallbacks).
        let pad = max((maxY - minY) * 0.12, maxY * 0.1, 5)
        yLo = minY - pad
        yHi = maxY + pad
        yTicks = [minY, (minY + maxY) / 2, maxY]
    }

    func scaleX(_ date: Date) -> CGFloat {
        let t = date.timeIntervalSince1970
        let range = xMax - xMin
        guard range > 0 else { return pad.leading + chartWidth / 2 }
        return pad.leading + CGFloat((t - xMin) / range) * chartWidth
    }

    func scaleY(_ w: Double) -> CGFloat {
        let range = yHi - yLo
        guard range > 0 else { return pad.top + chartHeight / 2 }
        return pad.top + chartHeight - CGFloat((w - yLo) / range) * chartHeight
    }
}

private struct LineShape: Shape {
    let points: [ExerciseLiftPage.ChartPoint]
    let layout: ChartLayout
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for (i, point) in points.enumerated() {
            let pt = CGPoint(x: layout.scaleX(point.date), y: layout.scaleY(point.weight))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
}

private struct AreaShape: Shape {
    let points: [ExerciseLiftPage.ChartPoint]
    let layout: ChartLayout
    func path(in rect: CGRect) -> Path {
        guard !points.isEmpty else { return Path() }
        var p = Path()
        let baseline = layout.pad.top + layout.chartHeight
        let first = points.first!
        let last  = points.last!
        p.move(to: CGPoint(x: layout.scaleX(first.date), y: layout.scaleY(first.weight)))
        for point in points.dropFirst() {
            p.addLine(to: CGPoint(x: layout.scaleX(point.date), y: layout.scaleY(point.weight)))
        }
        p.addLine(to: CGPoint(x: layout.scaleX(last.date),  y: baseline))
        p.addLine(to: CGPoint(x: layout.scaleX(first.date), y: baseline))
        p.closeSubpath()
        return p
    }
}

// MARK: - Spinner

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
