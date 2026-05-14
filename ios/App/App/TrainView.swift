import SwiftUI

/// Train tab — workout logger. Visual port of src/components/TodayTab.jsx.
/// Header + Live Activity toggle + progress bar + exercise cards (each with
/// weight pill, expandable rest-timer chips, and numbered set buttons that
/// flip to a check when tapped) + finish session button.
///
/// Empty state matches the React version when no session is loaded.
struct TrainView: View {
    @EnvironmentObject var app: AppState

    // Local UI state (kept in this view for now — real persistence happens
    // when the session is saved via app.finishSession). Mirrors the
    // useState hooks in TodayTab.jsx.
    @State private var completedSets: [String: Bool] = [:]   // "exKey_setIdx" → done
    @State private var expandedKey: String? = nil            // which exercise has the
                                                              // weight/timer expand showing
    @State private var editedWeights: [String: Double] = [:] // per-exercise weight override
    @State private var restTimerChoice: [String: Int] = [:]  // exKey → seconds
    @State private var activeTimerKey: String? = nil
    @State private var timerRemaining: Int = 0
    @State private var timerDuration: Int = 0
    @State private var timerPaused: Bool = false
    @State private var liveActivityActive: Bool = false

    private var ar: Bool { app.language == "ar" }

    var body: some View {
        Group {
            if let session = app.currentSession,
               let exercises = session.data?.exercises, !exercises.isEmpty {
                sessionLayout(session: session, exercises: exercises)
            } else {
                emptyState
            }
        }
        .background(HexTheme.bg.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt")
                .font(.system(size: 40))
                .foregroundColor(HexTheme.mute)
            Text(ar ? "لم يتم تحميل جلسة." : "No session loaded.")
                .font(.system(size: 16))
                .foregroundColor(HexTheme.dim)
            Text(ar
                 ? "اذهب إلى الرئيسية لاختيار جلسة."
                 : "Go to Home to select one.")
                .font(.system(size: 16))
                .foregroundColor(HexTheme.dim)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Main layout

    private func sessionLayout(session: WorkoutSession,
                               exercises: [Exercise]) -> some View {
        let totalSets = exercises.reduce(0) { $0 + $1.sets }
        let doneSets  = completedSets.values.filter { $0 }.count
        let progress  = totalSets > 0 ? Double(doneSets) / Double(totalSets) : 0

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Title ─────────────────────────────────────────
                Text(session.name)
                    .font(.system(size: 26, weight: .heavy))
                    .kerning(ar ? 0 : -0.4)
                    .foregroundColor(HexTheme.text)
                    .padding(.bottom, 16)

                // ── Live Activity toggle ──────────────────────────
                liveActivityButton
                    .padding(.bottom, 14)

                // ── Progress bar ──────────────────────────────────
                progressBar(progress: progress,
                            done: doneSets,
                            total: totalSets)
                    .padding(.bottom, 14)

                // ── Exercise cards ───────────────────────────────
                VStack(spacing: 12) {
                    ForEach(Array(exercises.enumerated()), id: \.offset) { idx, ex in
                        exerciseCard(ex: ex, exIdx: idx)
                    }
                }
                .padding(.bottom, 16)

                // ── Finish button ────────────────────────────────
                finishButton(exercises: exercises)

                Spacer(minLength: 30)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }

    // MARK: - Live Activity button

    private var liveActivityButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            liveActivityActive.toggle()
            // TODO: wire up LiveActivityService.shared.start/.end
        } label: {
            HStack(spacing: 8) {
                Image(systemName: liveActivityActive ? "bolt.fill" : "bolt")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(HexTheme.accent)
                Text(liveActivityActive
                     ? (ar ? "النشاط المباشر فعّال" : "Live Activity Active")
                     : (ar ? "بدء النشاط المباشر" : "Start Live Activity"))
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(liveActivityActive ? HexTheme.accent : HexTheme.dim)
                Spacer()
                if liveActivityActive {
                    Circle()
                        .fill(HexTheme.accent)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(HexTheme.accent.opacity(liveActivityActive ? 0.12 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(HexTheme.accent.opacity(liveActivityActive ? 0.5 : 0.2), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Progress bar

    private func progressBar(progress: Double, done: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(HexTheme.surface2)
                        .frame(height: 4)
                    Capsule()
                        .fill(HexTheme.accent)
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(.spring(response: 0.4, dampingFraction: 0.85),
                                   value: progress)
                }
            }
            .frame(height: 4)

            Text(ar
                 ? "\(done) / \(total) مجموعات مكتملة"
                 : "\(done) / \(total) sets complete")
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(HexTheme.dim)
        }
    }

    // MARK: - Exercise card

    @ViewBuilder
    private func exerciseCard(ex: Exercise, exIdx: Int) -> some View {
        let exKey = "\(exIdx)_\(ex.name)"
        let isExpanded = expandedKey == exKey

        VStack(alignment: .leading, spacing: 10) {

            // ── Top row: name+meta + weight pill ──────────────────
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ex.name)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(HexTheme.text)
                    metaLine(ex: ex)
                    if let notes = ex.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 11))
                            .italic()
                            .foregroundColor(HexTheme.mute)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                weightPill(ex: ex, exKey: exKey, isExpanded: isExpanded)
            }

            // ── Inline expand: weight stepper + rest timer chips ──
            if isExpanded {
                expandPanel(ex: ex, exKey: exKey)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // ── Set buttons + timer ring ──────────────────────────
            HStack(alignment: .center, spacing: 8) {
                setButtonsRow(ex: ex, exKey: exKey)
                if activeTimerKey == exKey {
                    timerRing
                }
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

    private func metaLine(ex: Exercise) -> some View {
        HStack(spacing: 6) {
            Text(metaText(ex: ex))
                .font(.system(size: 12))
                .foregroundColor(HexTheme.dim)
            if let tag = ex.tag, !tag.isEmpty {
                Text(tag)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(HexTheme.mute)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(HexTheme.surface)
                    )
            }
        }
    }

    private func metaText(ex: Exercise) -> String {
        var s = "\(ex.sets) × \(ex.reps)"
        if let rpe = ex.rpe, !rpe.isEmpty {
            s += " · RPE \(rpe)"
        }
        return s
    }

    private func weightPill(ex: Exercise, exKey: String, isExpanded: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                expandedKey = isExpanded ? nil : exKey
            }
        } label: {
            HStack(spacing: 4) {
                Text(weightLabel(ex: ex, exKey: exKey))
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(HexTheme.accent)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(HexTheme.accent)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(HexTheme.accent.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HexTheme.accent.opacity(0.30), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func weightLabel(ex: Exercise, exKey: String) -> String {
        let override = editedWeights[exKey]
        let w = override ?? ex.weight ?? 0
        if w <= 0 { return "BW" }
        if w == w.rounded() {
            return "\(Int(w))kg"
        }
        return String(format: "%.1fkg", w)
    }

    // MARK: - Expand panel

    private func expandPanel(ex: Exercise, exKey: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Weight stepper (placeholder UI — full stepper TBD)
            if (ex.weight ?? 0) > 0 {
                weightStepper(ex: ex, exKey: exKey)
            }
            restTimerChips(exKey: exKey)
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private func weightStepper(ex: Exercise, exKey: String) -> some View {
        let current = editedWeights[exKey] ?? ex.weight ?? 0
        return HStack(spacing: 10) {
            stepperButton(symbol: "minus") {
                editedWeights[exKey] = max(0, current - 2.5)
            }
            VStack(spacing: 0) {
                Text(current == current.rounded()
                     ? "\(Int(current))"
                     : String(format: "%.1f", current))
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(HexTheme.text)
                Text("kg")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(HexTheme.mute)
            }
            .frame(maxWidth: .infinity)
            stepperButton(symbol: "plus") {
                editedWeights[exKey] = current + 2.5
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(HexTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HexTheme.border, lineWidth: 1)
        )
    }

    private func stepperButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(HexTheme.accent)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(HexTheme.accent.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(HexTheme.accent.opacity(0.3), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func restTimerChips(exKey: String) -> some View {
        let presets: [(label: String, seconds: Int)] = [
            ("30s", 30), ("60s", 60), ("90s", 90), ("2m", 120), ("3m", 180),
        ]
        let chosen = restTimerChoice[exKey] ?? 90

        return VStack(alignment: .leading, spacing: 8) {
            Text(ar ? "مؤقت الراحة" : "REST TIMER")
                .font(.system(size: 10, weight: .heavy))
                .kerning(ar ? 0 : 0.8)
                .foregroundColor(HexTheme.mute)

            HStack(spacing: 6) {
                ForEach(presets, id: \.seconds) { preset in
                    let active = preset.seconds == chosen
                    Button {
                        restTimerChoice[exKey] = preset.seconds
                    } label: {
                        Text(preset.label)
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(active ? .black : HexTheme.dim)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(active ? HexTheme.accent : HexTheme.surface)
                            )
                            .overlay(
                                Capsule().stroke(active ? HexTheme.accent : HexTheme.border,
                                                 lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Set buttons

    private func setButtonsRow(ex: Exercise, exKey: String) -> some View {
        // Wrap-style flex row using LazyVGrid since SwiftUI lacks native flex-wrap
        FlexRow(spacing: 8) {
            ForEach(0..<ex.sets, id: \.self) { si in
                let key = "\(exKey)_\(si)"
                let done = completedSets[key] == true
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    toggleSet(exKey: exKey, setIdx: si, ex: ex)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(done ? HexTheme.accent : HexTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(done ? HexTheme.accent : HexTheme.border,
                                            lineWidth: 1.5)
                            )
                        if done {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundColor(.black)
                        } else {
                            Text("\(si + 1)")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundColor(HexTheme.mute)
                        }
                    }
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggleSet(exKey: String, setIdx: Int, ex: Exercise) {
        let key = "\(exKey)_\(setIdx)"
        let wasDone = completedSets[key] == true
        completedSets[key] = !wasDone

        if !wasDone {
            // Set just completed — check if all done
            let allDone = (0..<ex.sets).allSatisfy { completedSets["\(exKey)_\($0)"] == true }
            if allDone {
                if activeTimerKey == exKey { stopTimer() }
            } else {
                let dur = restTimerChoice[exKey] ?? 90
                startTimer(exKey: exKey, duration: dur)
            }
        }
    }

    // MARK: - Rest timer ring

    private var timerRing: some View {
        let total = max(timerDuration, 1)
        let frac  = Double(timerRemaining) / Double(total)
        return Button {
            timerPaused.toggle()
        } label: {
            ZStack {
                Circle()
                    .stroke(HexTheme.border, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: CGFloat(frac))
                    .stroke(HexTheme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.4), value: timerRemaining)
                VStack(spacing: 0) {
                    Text(formatSeconds(timerRemaining))
                        .font(.system(size: 12, weight: .heavy).monospacedDigit())
                        .foregroundColor(HexTheme.text)
                    if timerPaused {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8))
                            .foregroundColor(HexTheme.accent)
                    }
                }
            }
            .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
    }

    private func formatSeconds(_ s: Int) -> String {
        let m = s / 60
        let r = s % 60
        return m > 0 ? "\(m):\(String(format: "%02d", r))" : "\(r)"
    }

    private func startTimer(exKey: String, duration: Int) {
        activeTimerKey = exKey
        timerRemaining = duration
        timerDuration  = duration
        timerPaused    = false
        // Drive countdown
        Task {
            while activeTimerKey == exKey && timerRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !timerPaused { timerRemaining -= 1 }
            }
            if activeTimerKey == exKey { stopTimer() }
        }
    }

    private func stopTimer() {
        activeTimerKey = nil
        timerRemaining = 0
        timerDuration  = 0
        timerPaused    = false
    }

    // MARK: - Finish button

    private func finishButton(exercises: [Exercise]) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            // TODO: app.finishSession(...)
        } label: {
            HStack(spacing: 6) {
                Text(ar ? "إنهاء الجلسة" : "Finish Session")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(.black)
                Image(systemName: ar ? "arrow.left" : "arrow.right")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(HexTheme.accent)
            )
            .shadow(color: HexTheme.accent.opacity(0.35), radius: 24, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

/// Tiny flex-wrap helper so the set buttons reflow onto multiple rows
/// when an exercise has more than ~5 sets at narrow widths. SwiftUI
/// doesn't ship a native flex wrap, so we measure width and lay out
/// children in rows by hand.
private struct FlexRow<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        // Simple HStack for now; this is sufficient up to ~5–6 set buttons
        // at normal device widths. A measured flow layout can replace this
        // later if you ever spec >6 sets on a phone.
        HStack(spacing: spacing) {
            content()
        }
    }
}
