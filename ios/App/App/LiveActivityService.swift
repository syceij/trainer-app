import Foundation
import ActivityKit

/// Wraps ActivityKit so the rest of the app can start/update/end the workout
/// Live Activity with a single line of Swift.
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

    /// Start a fresh Live Activity for the given session.
    /// Returns the activity ID on success, throws on failure.
    @available(iOS 16.2, *)
    @discardableResult
    func start(
        sessionName: String,
        exerciseName: String,
        setsDone: Int,
        setsTotal: Int,
        timerEndsAt: Date?,
        weightKg: Double,
        reps: Int
    ) async throws -> String {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LAError.disabled
        }

        // Always end any lingering activity first (in-memory OR from previous
        // app sessions) — iOS limits each app to a small number of concurrent
        // activities, and a leftover one is a common cause of request failures.
        await endAll()

        let attrs = WorkoutActivityAttributes(sessionName: sessionName)
        let state = WorkoutActivityAttributes.ContentState(
            exerciseName: exerciseName,
            setsDone:     setsDone,
            setsTotal:    setsTotal,
            timerEndsAt:  timerEndsAt ?? .distantPast,
            weightKg:     weightKg,
            reps:         reps
        )

        let activity = try Activity<WorkoutActivityAttributes>.request(
            attributes: attrs,
            content: .init(state: state, staleDate: nil),
            pushType: nil
        )
        currentActivity = activity
        print("[LiveActivity] started id=\(activity.id)")
        return activity.id
    }

    // MARK: - Update

    /// Push a new state to the running activity. No-ops if none is running.
    @available(iOS 16.2, *)
    func update(
        exerciseName: String,
        setsDone: Int,
        setsTotal: Int,
        timerEndsAt: Date?,
        weightKg: Double,
        reps: Int
    ) async {
        guard let activity = currentActivity as? Activity<WorkoutActivityAttributes> else { return }
        let state = WorkoutActivityAttributes.ContentState(
            exerciseName: exerciseName,
            setsDone:     setsDone,
            setsTotal:    setsTotal,
            timerEndsAt:  timerEndsAt ?? .distantPast,
            weightKg:     weightKg,
            reps:         reps
        )
        await activity.update(.init(state: state, staleDate: nil))
    }

    // MARK: - End

    /// End the current activity and dismiss it immediately. Also cleans up any
    /// lingering activities of the same type from previous app sessions.
    func end() async {
        if #available(iOS 16.2, *) {
            await endAll()
        }
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
        var errorDescription: String? {
            switch self {
            case .disabled:
                return "Live Activities are disabled. Enable them in Settings → HEX → Live Activities."
            }
        }
    }
}
