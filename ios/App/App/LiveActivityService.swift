import Foundation
import ActivityKit

/// Wraps ActivityKit so the rest of the app can start/update/end the workout
/// Live Activity with a single call. Also mirrors the staged session into
/// the App Group store so the widget's `ToggleSetIntent` can advance through
/// exercises without an open app.
///
/// All methods are safe to call on any iOS version; they no-op on iOS < 16.2.
final class LiveActivityService {

    // MARK: - Singleton

    static let shared = LiveActivityService()
    private init() {}

    // MARK: - In-memory reference

    private var currentActivity: Any?

    // MARK: - Capability check

    /// True iff iOS supports Live Activities AND the user has them enabled
    /// for this app in Settings.
    var isEnabled: Bool {
        if #available(iOS 16.2, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        return false
    }

    // MARK: - Start

    /// Start a fresh Live Activity for the given staged session.
    /// Returns the activity ID on success, throws on failure.
    ///
    /// Persists the session into the App Group store so the widget
    /// extension's `ToggleSetIntent` can read it back when the user
    /// taps a set button on the Lock Screen.
    @available(iOS 16.2, *)
    @discardableResult
    func start(staged: StagedSessionDTO) async throws -> String {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LAError.disabled
        }
        guard let firstExercise = staged.exercises.first else {
            throw LAError.emptySession
        }

        // Always end any lingering activity first (in-memory OR from previous
        // app sessions) — iOS limits each app to a small number of concurrent
        // activities, and a leftover one is a common cause of request failures.
        await endAll()

        // Persist staged session to App Group so the widget can advance
        // through exercises without IPC back to the main app.
        WorkoutGroupStore.saveStagedSession(staged)
        // Clear any stale pending sets from a previous session.
        WorkoutGroupStore.clearPendingSets()

        let attrs = WorkoutActivityAttributes(sessionName: staged.name)
        let state = WorkoutActivityAttributes.ContentState(
            exerciseName:   firstExercise.name,
            exerciseIndex:  0,
            totalExercises: staged.exercises.count,
            setsCompleted:  Array(repeating: false, count: max(firstExercise.sets, 1)),
            targetReps:     firstExercise.reps,
            weightKg:       firstExercise.weightKg,
            weightLabel:    firstExercise.bodyweight ? "BW" : nil,
            targetRpe:      firstExercise.rpe,
            tag:            firstExercise.tag,
            focus:          firstExercise.focus,
            restEndsAt:     .distantPast,
            restSeconds:    max(15, staged.restSeconds)
        )

        let activity = try Activity<WorkoutActivityAttributes>.request(
            attributes: attrs,
            content: .init(state: state, staleDate: nil),
            pushType: nil
        )
        currentActivity = activity
        print("[LiveActivity] started id=\(activity.id) exercise=\(firstExercise.name)")
        return activity.id
    }

    // MARK: - Update

    /// Push a new state to the running activity. No-ops if none is running.
    /// Used by the main app's TrainView when the user taps a set inside the
    /// app — keeps the Lock Screen widget in sync.
    @available(iOS 16.2, *)
    func update(_ state: WorkoutActivityAttributes.ContentState) async {
        guard let activity = currentActivity as? Activity<WorkoutActivityAttributes> else { return }
        await activity.update(.init(state: state, staleDate: nil))
    }

    // MARK: - End

    /// End the current activity and dismiss it immediately. Also cleans up any
    /// lingering activities of the same type from previous app sessions and
    /// wipes the App Group staged session.
    func end() async {
        if #available(iOS 16.2, *) {
            await endAll()
        }
        WorkoutGroupStore.clearStagedSession()
    }

    // MARK: - Private

    @available(iOS 16.2, *)
    private func endAll() async {
        for activity in Activity<WorkoutActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }

    // MARK: - Errors

    enum LAError: LocalizedError {
        case disabled
        case emptySession
        var errorDescription: String? {
            switch self {
            case .disabled:
                return "Live Activities are disabled. Enable them in Settings → HEX → Live Activities."
            case .emptySession:
                return "There are no exercises in the current session."
            }
        }
    }
}
