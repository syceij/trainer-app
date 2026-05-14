import Foundation
import AppIntents
import ActivityKit

/// Tapping a numbered set button on the Lock Screen / Dynamic Island
/// fires this intent. It runs inside the WorkoutWidget extension process
/// (not the main app), so all Supabase work is deferred:
///
///   1. Toggle the bit in `ContentState.setsCompleted[setIndex]`.
///   2. If the set just transitioned to complete:
///      - Queue a `PendingSetDTO` in the App Group store (main app
///        drains it on next launch and writes the row to Supabase).
///      - Kick off a 60-second rest timer (or the user's choice if
///        they've overridden `restSeconds` since session start).
///   3. If every set on the current exercise is now done:
///      - Look up the next exercise in the App Group's `StagedSessionDTO`.
///      - If one exists: reset `ContentState` to that next exercise.
///      - If not: end the Live Activity immediately (Option A — the
///        user explicitly chose this behaviour over "wait for app to
///        save the session").
///   4. Call `Activity.update(...)` so the Lock Screen reflects the
///      new state without round-tripping through the main app.
///
/// Available on iOS 17+ because interactive Live Activity buttons
/// require `AppIntent` integration with `Button(intent:)`. iOS 16
/// users see the same card but with non-tappable buttons (handled in
/// `WorkoutWidgetLiveActivity.swift`).
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
