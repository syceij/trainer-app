import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Set-button App Intent
//
// Lives in this file (rather than a separate `ToggleSetIntent.swift`)
// because CI's `xcodebuild` only compiles files that appear in
// project.pbxproj. This file is already registered for the WorkoutWidget
// target, so anything declared here ships automatically. Adding a new
// .swift source file would require editing the pbxproj — riskier and
// not visible to xcodebuild until that edit happens.

/// Tapping a numbered set button on the Lock Screen / Dynamic Island
/// fires this intent. It runs inside the WorkoutWidget extension process
/// (not the main app), so all Supabase work is deferred:
///
///   1. Toggle the bit in `ContentState.setsCompleted[setIndex]`.
///   2. If the set just transitioned to complete:
///      - Queue a `PendingSetDTO` in the App Group store (main app
///        drains it on next launch and writes the row to Supabase).
///      - Kick off the user's rest timer.
///   3. If every set on the current exercise is now done:
///      - Look up the next exercise in the App Group's `StagedSessionDTO`.
///      - If one exists: reset `ContentState` to that next exercise.
///      - If not: mark the session finished + end the Live Activity
///        immediately (Option A in the spec).
///   4. Call `Activity.update(...)` so the Lock Screen reflects the
///      new state without round-tripping through the main app.
///
/// Available on iOS 17+ because interactive Live Activity buttons
/// require `AppIntent` integration with `Button(intent:)`. iOS 16
/// users see the same card but with non-tappable buttons (handled in
/// the `setLabel(i:done:)` builder below).
@available(iOS 17.0, *)
struct ToggleSetIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Workout Set"
    /// Keep the intent running in the widget extension process so the
    /// tap doesn't unlock or open the app — the user's whole goal is
    /// to complete sets without leaving the Lock Screen.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Set Index")
    var setIndex: Int

    init() {}

    init(setIndex: Int) {
        self.setIndex = setIndex
    }

    func perform() async throws -> some IntentResult {
        guard let activity = Activity<WorkoutActivityAttributes>.activities.first
        else { return .result() }

        var state = activity.content.state

        // Bounds-check — tapping a stale button after the state advanced
        // could otherwise crash.
        guard state.setsCompleted.indices.contains(setIndex)
        else { return .result() }

        // Toggle the per-set completion bit.
        let wasCompleted = state.setsCompleted[setIndex]
        state.setsCompleted[setIndex].toggle()
        let isNowCompleted = state.setsCompleted[setIndex]

        // Queue the set for Supabase ONLY on the false→true transition.
        // Untoggling (true→false) just clears the UI state; the main
        // app's reconciler treats the pending queue as authoritative.
        if isNowCompleted && !wasCompleted {
            queueCompletedSet(state: state)
            // Kick off the rest timer.
            state.restEndsAt = Date().addingTimeInterval(Double(state.restSeconds))
        } else if !isNowCompleted && wasCompleted {
            // Cancel any active timer when the user un-completes a set
            // (matches the React TodayTab feel).
            state.restEndsAt = .distantPast
        }

        // If every set is done, try to advance to the next exercise.
        if state.allSetsDone {
            if let advanced = advance(from: state) {
                state = advanced
                await activity.update(.init(state: state, staleDate: nil))
            } else {
                // Final exercise complete → record a finish marker so the
                // main app runs the full finishWorkout flow next launch,
                // then end the Live Activity immediately (Option A).
                if let staged = WorkoutGroupStore.loadStagedSession() {
                    WorkoutGroupStore.markSessionFinished(staged.sessionId)
                }
                await activity.end(
                    .init(state: state, staleDate: nil),
                    dismissalPolicy: .immediate
                )
                WorkoutGroupStore.clearStagedSession()
            }
        } else {
            await activity.update(.init(state: state, staleDate: nil))
        }

        return .result()
    }

    // MARK: - Helpers

    /// Build the next-exercise ContentState from the staged session in
    /// App Group storage. Returns nil when the current exercise was the
    /// last one (caller ends the activity).
    private func advance(from state: WorkoutActivityAttributes.ContentState)
        -> WorkoutActivityAttributes.ContentState?
    {
        guard let staged = WorkoutGroupStore.loadStagedSession() else { return nil }
        let nextIdx = state.exerciseIndex + 1
        guard staged.exercises.indices.contains(nextIdx) else { return nil }
        let next = staged.exercises[nextIdx]
        return WorkoutActivityAttributes.ContentState(
            exerciseName:   next.name,
            exerciseIndex:  nextIdx,
            totalExercises: staged.exercises.count,
            setsCompleted:  Array(repeating: false, count: max(next.sets, 1)),
            targetReps:     next.reps,
            weightKg:       next.weightKg,
            weightLabel:    next.bodyweight ? "BW" : nil,
            targetRpe:      next.rpe,
            tag:            next.tag,
            focus:          next.focus,
            restEndsAt:     Date().addingTimeInterval(Double(state.restSeconds)),
            restSeconds:    state.restSeconds
        )
    }

    /// Append the just-completed set to the App Group pending queue.
    /// Main-app `AppState.drainPendingSets()` reads this on launch /
    /// foreground and writes each row to Supabase `sets`.
    private func queueCompletedSet(state: WorkoutActivityAttributes.ContentState) {
        guard let staged = WorkoutGroupStore.loadStagedSession() else { return }
        // Best-effort numeric reps — split on "-" and take the high end so
        // we record the prescription's upper rep target. Falls back to 8.
        let reps: Int = {
            let parts = state.targetReps.split(separator: "-")
            if let last = parts.last, let n = Int(last) { return n }
            if let n = Int(state.targetReps) { return n }
            return 8
        }()
        let pending = PendingSetDTO(
            id:           UUID(),
            sessionId:    staged.sessionId,
            exerciseName: state.exerciseName,
            setNumber:    setIndex + 1,
            reps:         reps,
            weightKg:     state.weightKg > 0 ? state.weightKg : nil,
            completedAt:  Date()
        )
        WorkoutGroupStore.appendPendingSet(pending)
    }
}

// MARK: - Live Activity widget UI

// ── Design tokens matching the HEX app ───────────────────────────────────────
private let hexAccent     = Color(red: 0.722, green: 1.0,   blue: 0.0)    // #B8FF00
private let hexBg         = Color(red: 0.039, green: 0.039, blue: 0.039)  // #0A0A0A
private let hexDim        = Color.white.opacity(0.50)
private let hexMute       = Color.white.opacity(0.32)
private let hexMutedBg    = Color.white.opacity(0.07)
private let hexBorder     = Color.white.opacity(0.10)

// ── Lock Screen / Notification Banner view ────────────────────────────────────
struct WorkoutLockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    private var s: WorkoutActivityAttributes.ContentState { context.state }
    private var a: WorkoutActivityAttributes { context.attributes }
    private var hasTimer: Bool { s.restEndsAt > Date() }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ── Header row: exercise name + weight pill ────────────────
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    // Tiny uppercase session header — "PUSH B — SHOULDER FOCUS"
                    Text(a.sessionName.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .kerning(0.8)
                        .foregroundStyle(hexDim)
                        .lineLimit(1)

                    Text(s.exerciseName)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 8)
                weightPill
            }

            // ── Metadata row: "4 × 8-10 · RPE 7-8" + compound tag ─────
            HStack(spacing: 6) {
                Text(metadataLine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(hexDim)
                if let tag = s.tag, !tag.isEmpty {
                    Text(tag)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color.white.opacity(0.08))
                        )
                }
                Spacer(minLength: 0)
            }

            // ── Focus / notes line (italic, dim) ──────────────────────
            if let focus = s.focus, !focus.isEmpty {
                Text(focus)
                    .font(.system(size: 11, weight: .regular).italic())
                    .foregroundStyle(hexMute)
                    .lineLimit(1)
            }

            // ── Set buttons row ───────────────────────────────────────
            setButtonsRow
                .padding(.top, 2)

            // ── Rest timer (when active) ─────────────────────────────
            if hasTimer {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(hexAccent)
                    Text(s.restEndsAt, style: .timer)
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(hexAccent)
                        .contentTransition(.numericText(countsDown: true))
                    Text("rest")
                        .font(.system(size: 11))
                        .foregroundStyle(hexDim)
                    Spacer()
                    // Tiny exercise progress indicator "1 / 5"
                    Text("\(s.exerciseIndex + 1) / \(s.totalExercises)")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(hexMute)
                }
                .padding(.top, 2)
            } else {
                // Even without a timer, show the exercise-progress hint
                // so the user knows where they are in the session.
                HStack {
                    Spacer()
                    Text("\(s.exerciseIndex + 1) / \(s.totalExercises)")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(hexMute)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(hexBg)
    }

    // MARK: - Sub-views

    /// Lime-outlined weight pill in the top-right corner.
    private var weightPill: some View {
        let label: String = {
            if let l = s.weightLabel, !l.isEmpty { return l }
            if s.weightKg > 0 {
                let w = s.weightKg
                return w == w.rounded() ? "\(Int(w))kg" : String(format: "%.1fkg", w)
            }
            return "—"
        }()
        return Text(label)
            .font(.system(size: 14, weight: .heavy))
            .foregroundStyle(hexAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(hexAccent.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(hexAccent, lineWidth: 1.2)
            )
    }

    /// "4 × 8-10 · RPE 7-8" line.
    private var metadataLine: String {
        var parts: [String] = []
        parts.append("\(s.setsTotal) × \(s.targetReps)")
        if let rpe = s.targetRpe, !rpe.isEmpty {
            parts.append("RPE \(rpe)")
        }
        return parts.joined(separator: " · ")
    }

    /// Row of numbered set buttons. Buttons are interactive on iOS 17+
    /// via the `Button(intent:)` initialiser; older systems fall back
    /// to plain coloured squares (still readable as a progress display).
    private var setButtonsRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<s.setsTotal, id: \.self) { i in
                setButton(index: i)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func setButton(index i: Int) -> some View {
        let isDone = s.setsCompleted[i]
        let label = setLabel(i: i, done: isDone)
        if #available(iOS 17.0, *) {
            // iOS 17 — interactive button wired to the App Intent.
            Button(intent: ToggleSetIntent(setIndex: i)) {
                label
            }
            .buttonStyle(.plain)
        } else {
            // iOS 16 — non-interactive display, still legible.
            label
        }
    }

    /// One set-button face. Filled lime when done, neutral when pending.
    /// Sized 36×36 (down from 42) to keep the full card under Apple's
    /// ~220pt Lock Screen Live Activity cap even when the focus / notes
    /// line wraps to two lines.
    @ViewBuilder
    private func setLabel(i: Int, done: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(done ? hexAccent : hexMutedBg)
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(done ? Color.clear : hexBorder, lineWidth: 1)
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.black)
            } else {
                Text("\(i + 1)")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(hexDim)
            }
        }
        .frame(width: 36, height: 36)
    }
}

// ── Live Activity widget configuration ────────────────────────────────────────
struct WorkoutLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in

            // ── Lock screen / banner ──────────────────────────────────────────
            WorkoutLockScreenView(context: context)

        } dynamicIsland: { context in
            let s = context.state
            let hasTimer = s.restEndsAt > Date()

            return DynamicIsland {

                // ── Expanded ─────────────────────────────────────────────────
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(hexAccent)
                        Text(s.exerciseName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(s.setsDone)/\(s.setsTotal)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(hexAccent)
                        .monospacedDigit()
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        // Pack as many set buttons as fit — Dynamic Island
                        // expanded height is ~160pt, so 5+ usually still works.
                        ForEach(0..<s.setsTotal, id: \.self) { i in
                            islandSetButton(state: s, index: i)
                        }
                        Spacer(minLength: 0)
                        if hasTimer {
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.system(size: 10))
                                    .foregroundStyle(hexAccent)
                                Text(s.restEndsAt, style: .timer)
                                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(hexAccent)
                                    .contentTransition(.numericText(countsDown: true))
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }

            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(hexAccent)

            } compactTrailing: {
                if hasTimer {
                    Text(s.restEndsAt, style: .timer)
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundStyle(hexAccent)
                        .contentTransition(.numericText(countsDown: true))
                } else {
                    Text("\(s.setsDone)/\(s.setsTotal)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(hexAccent)
                        .monospacedDigit()
                }

            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(hexAccent)
            }
        }
    }

    /// Smaller set-button variant for the Dynamic Island expanded bottom row.
    @ViewBuilder
    private func islandSetButton(state s: WorkoutActivityAttributes.ContentState,
                                 index i: Int) -> some View {
        let isDone = s.setsCompleted[i]
        let face = ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isDone ? hexAccent : hexMutedBg)
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.black)
            } else {
                Text("\(i + 1)")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(hexDim)
            }
        }
        .frame(width: 32, height: 32)

        if #available(iOS 17.0, *) {
            Button(intent: ToggleSetIntent(setIndex: i)) {
                face
            }
            .buttonStyle(.plain)
        } else {
            face
        }
    }
}
