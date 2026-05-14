import SwiftUI

/// Progress tab — full port of src/components/ProgressTab.jsx.
///
/// Layout, top to bottom:
///   • "Progress" header (no subtitle — React doesn't have one).
///   • 2×2 tracked-lifts grid — slots come from `profiles.tracked_lifts`
///     so picks made on iOS surface on the web and vice versa.
///   • "View Gym Calendar" pill (navigates to CalendarView).
///   • "MOST IMPROVED" exercise list — top 4 by absolute kg delta;
///     hidden when there's no improvement yet, matching React.
///   • Muscle-progress chart (6 bars) with the "MOST IMPROVED / NEEDS
///     WORK" stats card pair under it.
///   • "HISTORY" expandable session list.
///
/// All sources of truth are Supabase — the workoutHistory, profile,
/// working_weights, and tracked lifts are loaded by AppState and read
/// here without any local-only mutations.
struct ProgressTabView: View {
    @EnvironmentObject var app: AppState

    // Picker state — when not nil, the ExercisePickerSheet opens and any
    // selection writes back to that specific slot.
    @State private var pickerSlot: Int? = nil

    // Action-sheet state — when not nil, the confirmation dialog opens
    // for that filled slot with "Change exercise" / "View progress".
    @State private var actionSheetSlot: Int? = nil

    // Set after the user taps "View progress" — drives the
    // navigationDestination to ExerciseLiftPage.
    @State private var viewingLiftName: String? = nil

    // History row expansion (one open at a time, like React).
    @State private var expandedSessionId: UUID? = nil

    private var ar: Bool { app.language == "ar" }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header ────────────────────────────────────────
                Text(ar ? "تقدمك" : "Progress")
                    .font(.system(size: 26, weight: .heavy))
                    .kerning(ar ? 0 : -0.5)
                    .foregroundColor(HexTheme.text)
                    .padding(.bottom, 18)

                // ── Tracked lifts grid ────────────────────────────
                liftsGrid
                    .padding(.bottom, 24)

                // ── View Gym Calendar pill ────────────────────────
                calendarPill
                    .padding(.bottom, 24)

                // ── MOST IMPROVED exercise list (hidden if empty) ──
                if !mostImprovedExercises.isEmpty {
                    mostImprovedSection
                        .padding(.bottom, 24)
                }

                // ── Muscle progress chart ─────────────────────────
                muscleProgressCard
                    .padding(.bottom, 12)

                // ── Dual MOST IMPROVED / NEEDS WORK stats row ─────
                muscleStatsRow
                    .padding(.bottom, 24)

                // ── HISTORY ───────────────────────────────────────
                historySection

                Spacer(minLength: 100) // room for floating tab bar
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(HexTheme.bg.ignoresSafeArea())
        .navigationBarHidden(true)
        // ExercisePickerSheet — opens for a specific slot when pickerSlot
        // is non-nil. Picking writes through AppState.setTrackedLift.
        .sheet(isPresented: pickerSlotIsActive) {
            ExercisePickerSheet(
                currentName: pickerSlot.flatMap { app.trackedLiftSlots[$0]?.name }
            ) { lib in
                if let slot = pickerSlot {
                    Task {
                        await app.setTrackedLift(
                            slot: slot,
                            lift: TrackedLift(name: lib.name, key: lib.key)
                        )
                    }
                }
                pickerSlot = nil
            }
            .environmentObject(app)
        }
        // Action sheet — open when actionSheetSlot is set. Two options:
        // change the exercise (re-open picker) or view its full history.
        .confirmationDialog(
            actionSheetTitle,
            isPresented: actionSheetIsActive,
            titleVisibility: .visible
        ) {
            Button(ar ? "تغيير التمرين" : "Change exercise") {
                let slot = actionSheetSlot
                actionSheetSlot = nil
                pickerSlot = slot
            }
            Button(ar ? "عرض التقدم" : "View progress") {
                if let slot = actionSheetSlot,
                   let lift = app.trackedLiftSlots[slot] {
                    viewingLiftName = lift.name
                }
                actionSheetSlot = nil
            }
            Button(ar ? "إزالة" : "Remove", role: .destructive) {
                if let slot = actionSheetSlot {
                    Task { await app.setTrackedLift(slot: slot, lift: nil) }
                }
                actionSheetSlot = nil
            }
            Button(ar ? "إلغاء" : "Cancel", role: .cancel) {
                actionSheetSlot = nil
            }
        }
        // ExerciseLiftPage navigation, driven by viewingLiftName.
        .navigationDestination(isPresented: viewingLiftIsActive) {
            if let name = viewingLiftName {
                ExerciseLiftPage(exerciseName: name)
                    .environmentObject(app)
            }
        }
    }

    // MARK: - Binding helpers

    private var pickerSlotIsActive: Binding<Bool> {
        Binding(get: { pickerSlot != nil },
                set: { if !$0 { pickerSlot = nil } })
    }
    private var actionSheetIsActive: Binding<Bool> {
        Binding(get: { actionSheetSlot != nil },
                set: { if !$0 { actionSheetSlot = nil } })
    }
    private var viewingLiftIsActive: Binding<Bool> {
        Binding(get: { viewingLiftName != nil },
                set: { if !$0 { viewingLiftName = nil } })
    }

    private var actionSheetTitle: String {
        guard let slot = actionSheetSlot,
              let lift = app.trackedLiftSlots[slot]
        else { return "" }
        return lift.name
    }

    // MARK: - Tracked lifts grid

    private var liftsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ar ? "أوزانك" : "TRACKED LIFTS")
                .font(.system(size: 10, weight: .heavy))
                .kerning(ar ? 0 : 0.9)
                .foregroundColor(HexTheme.dim)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)],
                      spacing: 10) {
                ForEach(0..<4, id: \.self) { i in
                    if let lift = app.trackedLiftSlots[i] {
                        Button {
                            actionSheetSlot = i
                        } label: {
                            filledLiftCard(lift: lift)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            pickerSlot = i
                        } label: {
                            emptyLiftCard
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// Empty slot: dashed-border placeholder with a "+" and copy CTA.
    private var emptyLiftCard: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(HexTheme.surface2)
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(HexTheme.dim)
            }
            .frame(width: 28, height: 28)
            .overlay(Circle().stroke(HexTheme.border, lineWidth: 1))

            Text(ar ? "اضغط لإضافة تمرين" : "Tap to add a lift to track")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(HexTheme.mute)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(.horizontal, 12)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HexTheme.border, style: StrokeStyle(
                    lineWidth: 1.5, dash: [5, 4]))
        )
    }

    /// Filled slot: uppercase tiny name + big kg value + sparkline polyline.
    private func filledLiftCard(lift: TrackedLift) -> some View {
        let weight = resolveWorkingWeight(for: lift)
        let sparkData = sparklineWeights(for: lift.name)

        return VStack(alignment: .leading, spacing: 0) {
            // Name + pencil row
            HStack(alignment: .top, spacing: 4) {
                Text(lift.name.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .kerning(0.5)
                    .foregroundColor(HexTheme.dim)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "pencil")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(HexTheme.mute)
            }
            .padding(.bottom, 6)

            // Weight value (or em dash when unknown)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                if let w = weight {
                    Text(formatWeight(w))
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(HexTheme.text)
                    Text("kg")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(HexTheme.dim)
                } else {
                    Text("—")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(HexTheme.text)
                }
            }
            .padding(.bottom, 8)

            // Polyline sparkline
            sparkline(weights: sparkData.isEmpty
                      ? (weight.map { [$0] } ?? [])
                      : sparkData)
                .frame(height: 28)
        }
        .padding(.horizontal, 13)
        .padding(.top, 12)
        .padding(.bottom, 10)
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

    // MARK: - Sparkline (polyline + endpoint dot)

    /// Polyline sparkline matching React's Sparkline component:
    /// W ≈ container width, H = 28, stroke 1.5, dot r=2.5, accent colour.
    /// Renders nothing for <2 data points (returns empty space).
    private func sparkline(weights: [Double]) -> some View {
        GeometryReader { geo in
            if weights.count >= 2 {
                let w = geo.size.width, h: CGFloat = 28
                let lo  = weights.min() ?? 0
                let hi  = weights.max() ?? 1
                let range = max(hi - lo, 1)
                let pts: [CGPoint] = weights.enumerated().map { i, v in
                    let x = CGFloat(i) / CGFloat(weights.count - 1) * w
                    let y = h - CGFloat((v - lo) / range) * (h - 4) - 2
                    return CGPoint(x: x, y: y)
                }
                ZStack(alignment: .topLeading) {
                    Path { p in
                        if let first = pts.first { p.move(to: first) }
                        for pt in pts.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(HexTheme.accent, style: StrokeStyle(
                        lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                    if let last = pts.last {
                        Circle()
                            .fill(HexTheme.accent)
                            .frame(width: 5, height: 5)
                            .position(x: last.x, y: last.y)
                    }
                }
            } else {
                // <2 points — just an empty band, matches React's blank div.
                Color.clear
            }
        }
    }

    // MARK: - Calendar pill

    private var calendarPill: some View {
        NavigationLink {
            CalendarView().environmentObject(app)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HexTheme.accent)
                Text(ar ? "عرض التقويم" : "View Gym Calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HexTheme.text)
                Spacer()
                Image(systemName: ar ? "chevron.left" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(HexTheme.mute)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(HexTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(HexTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - MOST IMPROVED exercise list

    /// Top 4 weighted exercises by absolute kg delta. Mirrors React's
    /// `getMostImproved` in ProgressTab.jsx — skip bodyweight, require
    /// 2+ entries, delta > 0, descending order, take 4.
    private struct ImprovedExercise: Identifiable, Hashable {
        let id: String        // exercise key (or lowercased name)
        let name: String
        let first: Double
        let last: Double
        var delta: Double { last - first }
        var pct: Int { Int(((last - first) / max(first, 0.0001) * 100).rounded()) }
    }

    private var mostImprovedExercises: [ImprovedExercise] {
        struct Entry { var name: String; var entries: [(Date, Double)] = [] }
        var byKey: [String: Entry] = [:]
        for session in app.workoutHistory {
            for ex in session.data?.exercises ?? [] {
                if ex.bodyweight { continue }
                guard let w = ex.weight, w > 0 else { continue }
                let key = ex.key.isEmpty ? ex.name.lowercased() : ex.key
                var e = byKey[key] ?? Entry(name: ex.name)
                e.entries.append((session.date, w))
                byKey[key] = e
            }
        }
        var out: [ImprovedExercise] = []
        for (key, entry) in byKey where entry.entries.count >= 2 {
            let sorted = entry.entries.sorted(by: { $0.0 < $1.0 })
            let first = sorted.first!.1
            let last  = sorted.last!.1
            if last - first > 0 {
                out.append(ImprovedExercise(
                    id: key, name: entry.name, first: first, last: last
                ))
            }
        }
        return out
            .sorted(by: { $0.delta > $1.delta })
            .prefix(4)
            .map { $0 }
    }

    private var mostImprovedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(HexTheme.accent)
                Text(ar ? "الأكثر تحسناً" : "MOST IMPROVED")
                    .font(.system(size: 12, weight: .heavy))
                    .kerning(ar ? 0 : 0.8)
                    .foregroundColor(HexTheme.dim)
            }
            VStack(spacing: 8) {
                ForEach(mostImprovedExercises) { item in
                    improvedRow(item: item)
                }
            }
        }
    }

    private func improvedRow(item: ImprovedExercise) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(HexTheme.text)
                Text("\(formatWeight(item.first)) kg → \(formatWeight(item.last)) kg")
                    .font(.system(size: 11))
                    .foregroundColor(HexTheme.dim)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(formatWeight(item.delta)) kg")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(Color(red: 74/255, green: 222/255, blue: 128/255))
                Text("+\(item.pct)%")
                    .font(.system(size: 11))
                    .foregroundColor(HexTheme.dim)
            }
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

    // MARK: - Muscle progress chart + stats row

    private var muscleProgressCard: some View {
        let stats  = muscleStats
        let maxPct = max(stats.map(\.pct).max() ?? 1, 1)
        let bestId = stats.filter { $0.seen && $0.pct > 0 }
                          .max(by: { $0.pct < $1.pct })?.id

        return VStack(alignment: .leading, spacing: 14) {
            Text(ar ? "تقدم العضلات" : "MUSCLE PROGRESS")
                .font(.system(size: 12, weight: .heavy))
                .kerning(ar ? 0 : 0.8)
                .foregroundColor(HexTheme.dim)

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(stats, id: \.id) { stat in
                    NavigationLink {
                        MusclePage(muscleId: stat.id)
                            .environmentObject(app)
                    } label: {
                        muscleBar(stat: stat, maxPct: maxPct, bestId: bestId)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 130)
        }
    }

    /// One bar in the chart. Same logic as before but extracted from the
    /// previous file so the stats-cards row can render alongside.
    private func muscleBar(stat: MuscleStat, maxPct: Int, bestId: String?) -> some View {
        let label = barLabel(forId: stat.id)
        let pctClamped = max(min(stat.pct, 100), 0)
        let frac: CGFloat = stat.seen
            ? max(CGFloat(pctClamped) / CGFloat(maxPct), 0.10)
            : 0.06
        let isBest = stat.id == bestId
        let pctLabel: String = {
            if !stat.seen { return "—" }
            if stat.pct > 0 { return "+\(stat.pct)%" }
            return "0%"
        }()

        return VStack(spacing: 4) {
            Text(pctLabel)
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(isBest ? HexTheme.accent
                                 : stat.seen ? HexTheme.dim : HexTheme.mute)
                .frame(height: 11)

            GeometryReader { geo in
                VStack {
                    Spacer(minLength: 0)
                    if stat.seen {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isBest ? HexTheme.accent : HexTheme.border)
                            .frame(height: max(8, geo.size.height * frac))
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(HexTheme.border, style: StrokeStyle(
                                lineWidth: 1.5, dash: [4, 3]))
                            .frame(height: max(8, geo.size.height * frac))
                            .opacity(0.45)
                    }
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(isBest ? HexTheme.accent
                                 : stat.seen ? HexTheme.text : HexTheme.mute)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    /// Pair of cards under the muscle chart: best muscle group (accent
    /// background) + worst muscle group (neutral). Hidden when there's
    /// no data at all (matches React's `withData.length > 0` guard).
    @ViewBuilder
    private var muscleStatsRow: some View {
        let stats = muscleStats
        let withData = stats.filter { $0.seen }
        let improved = stats.filter { $0.seen && $0.pct > 0 }
        let best = improved.max(by: { $0.pct < $1.pct })
        let worst = withData.count > 1
            ? withData.min(by: { $0.pct < $1.pct })
            : nil

        if withData.isEmpty {
            Text(ar
                 ? "سجّل جلستك الأولى لرؤية تقدم العضلات"
                 : "Log your first session to see muscle progress")
                .font(.system(size: 12))
                .foregroundColor(HexTheme.mute)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        } else {
            HStack(spacing: 8) {
                bestImprovementCard(best: best)
                if let worst = worst, worst.id != best?.id {
                    needsWorkCard(worst: worst)
                }
            }
        }
    }

    @ViewBuilder
    private func bestImprovementCard(best: MuscleStat?) -> some View {
        // When a positive improvement exists, render the lime-accent
        // card matching React. Otherwise fall back to a neutral
        // "Keep training" card with the same dimensions.
        if let b = best {
            VStack(alignment: .leading, spacing: 4) {
                Text(ar ? "الأكثر تحسناً" : "MOST IMPROVED")
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(ar ? 0 : 0.6)
                    .foregroundColor(HexTheme.accent)
                Text(barLabel(forId: b.id, full: true))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(HexTheme.text)
                Text("+\(b.pct)%")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(HexTheme.accent)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(HexTheme.accent.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(HexTheme.accent.opacity(0.20), lineWidth: 1)
            )
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(ar ? "التقدم" : "PROGRESS")
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(ar ? 0 : 0.6)
                    .foregroundColor(HexTheme.mute)
                Text(ar ? "واصل التدريب" : "Keep training")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(HexTheme.dim)
                Text(ar
                     ? "يظهر التحسن بعد عدة جلسات"
                     : "Improvements appear after more sessions")
                    .font(.system(size: 11))
                    .foregroundColor(HexTheme.mute)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
    }

    private func needsWorkCard(worst: MuscleStat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ar ? "بحاجة لعمل" : "NEEDS WORK")
                .font(.system(size: 9, weight: .heavy))
                .kerning(ar ? 0 : 0.6)
                .foregroundColor(HexTheme.mute)
            Text(barLabel(forId: worst.id, full: true))
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(HexTheme.text)
            Text(worst.pct > 0
                 ? "+\(worst.pct)%"
                 : (ar ? "لا تقدم بعد" : "No gains yet"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(HexTheme.dim)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - HISTORY

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(ar ? "السجل" : "HISTORY")
                .font(.system(size: 12, weight: .heavy))
                .kerning(ar ? 0 : 0.8)
                .foregroundColor(HexTheme.dim)

            if app.workoutHistory.isEmpty {
                Text(ar
                     ? "أكمل تمرينك الأول لعرض السجل."
                     : "Complete your first session to see history.")
                    .font(.system(size: 13))
                    .foregroundColor(HexTheme.mute)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    // workoutHistory is already DESC by date — render as-is.
                    ForEach(app.workoutHistory) { session in
                        historyRow(session: session)
                    }
                }
            }
        }
    }

    private func historyRow(session: WorkoutSession) -> some View {
        let expanded = expandedSessionId == session.id
        let exercises = session.data?.exercises ?? []
        let volume = exercises.reduce(0.0) { acc, ex in
            if ex.bodyweight { return acc }
            guard let w = ex.weight, w > 0 else { return acc }
            return acc + w * Double(max(ex.sets, 1))
        }

        return VStack(spacing: 0) {
            Button {
                expandedSessionId = expanded ? nil : session.id
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.name)
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(HexTheme.text)
                            .multilineTextAlignment(.leading)
                        Text(historySubtitle(date: session.date,
                                             exerciseCount: exercises.count,
                                             volume: volume))
                            .font(.system(size: 11))
                            .foregroundColor(HexTheme.dim)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(HexTheme.mute)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(spacing: 0) {
                    ForEach(Array(exercises.enumerated()), id: \.offset) { idx, ex in
                        HStack {
                            Text(ex.name)
                                .font(.system(size: 13))
                                .foregroundColor(HexTheme.text)
                            Spacer()
                            Text(exerciseSummary(ex))
                                .font(.system(size: 12))
                                .foregroundColor(HexTheme.dim)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        if idx < exercises.count - 1 {
                            Rectangle()
                                .fill(HexTheme.border)
                                .frame(height: 1)
                                .padding(.horizontal, 14)
                        }
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 10)
                .overlay(
                    Rectangle()
                        .fill(HexTheme.border)
                        .frame(height: 1),
                    alignment: .top
                )
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
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func historySubtitle(date: Date, exerciseCount: Int, volume: Double) -> String {
        let df = DateFormatter()
        df.dateStyle = .short
        let dateStr = df.string(from: date)
        let vol = Int(volume.rounded())
        return ar
            ? "\(dateStr) · \(exerciseCount) تمارين · \(vol) كغ"
            : "\(dateStr) · \(exerciseCount) exercises · \(vol) kg vol."
    }

    private func exerciseSummary(_ ex: Exercise) -> String {
        let load: String = {
            if ex.bodyweight { return ar ? "وزن الجسم" : "BW" }
            if let w = ex.weight, w > 0 { return "\(formatWeight(w))kg" }
            return "—"
        }()
        return "\(ex.sets)×\(ex.reps) @ \(load)"
    }

    // MARK: - Working-weight resolution + sparkline data

    /// Resolve the current weight for a tracked lift. Mirrors React's
    /// `resolveWeight` — exact match in `workingWeights`, else first-2-word
    /// prefix match, else fall back to the most-recent session weight.
    private func resolveWorkingWeight(for lift: TrackedLift) -> Double? {
        // 1. Exact match in workingWeights (keyed by canonical lift key OR
        //    display name depending on which writer wrote it).
        if let w = app.workingWeights[lift.name], w > 0 { return w }
        if let key = lift.key, let w = app.workingWeights[key], w > 0 { return w }
        // 2. First-2-word case-insensitive prefix match — handles
        //    "Lateral Raise" → "Lateral raise (DB)" etc.
        let prefix = lift.name
            .split(separator: " ").prefix(2)
            .joined(separator: " ").lowercased()
        if !prefix.isEmpty {
            for (k, v) in app.workingWeights
                where v > 0 && k.lowercased().contains(prefix) {
                return v
            }
        }
        // 3. Fall back to the most recent session weight for that name.
        for session in app.workoutHistory {
            if let ex = session.data?.exercises.first(where: {
                $0.name.lowercased() == lift.name.lowercased()
            }), let w = ex.weight, w > 0 {
                return w
            }
        }
        return nil
    }

    /// Up to 8 weights chronologically (oldest → newest) for the sparkline.
    private func sparklineWeights(for name: String) -> [Double] {
        var weights: [Double] = []
        // workoutHistory is DESC by date — walk reversed to get oldest first.
        for session in app.workoutHistory.reversed() {
            if let ex = session.data?.exercises.first(where: {
                $0.name.lowercased() == name.lowercased()
            }), !ex.bodyweight, let w = ex.weight, w > 0 {
                weights.append(w)
            }
        }
        if weights.count > 8 {
            weights = Array(weights.suffix(8))
        }
        return weights
    }

    private func formatWeight(_ w: Double) -> String {
        if w == w.rounded() { return "\(Int(w))" }
        return String(format: "%.1f", w)
    }

    // MARK: - Muscle stats (unchanged from previous file)

    private struct MuscleStat { let id: String; let pct: Int; let seen: Bool }

    /// Aggregate stats per muscle group computed from `workoutHistory`.
    /// Same logic React uses in calcMuscleImprovements.
    private var muscleStats: [MuscleStat] {
        struct Entry { var muscle: String; var weights: [Double] = [] }
        var byName: [String: Entry] = [:]
        for session in app.workoutHistory.reversed() {
            for ex in session.data?.exercises ?? [] {
                if ex.bodyweight { continue }
                guard let w = ex.weight, w > 0 else { continue }
                guard let muscle = MuscleUtils.resolveMuscle(for: ex) else { continue }
                let key = ex.name.lowercased()
                var e = byName[key] ?? Entry(muscle: muscle)
                e.weights.append(w)
                byName[key] = e
            }
        }
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

    /// Bar label — short variant for the chart, full variant for stats cards.
    private func barLabel(forId id: String, full: Bool = false) -> String {
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
        case "shoulders": return full ? "Shoulders" : "Shldr"
        case "arms":      return "Arms"
        case "legs":      return "Legs"
        case "core":      return "Core"
        default:          return id.capitalized
        }
    }
}
