import ActivityKit
import Foundation

/// Shared between the main app (starts/updates activities) and the
/// WorkoutWidget extension (renders the lock-screen / Dynamic Island UI).
///
/// The attribute type is fixed for the lifetime of an activity.
/// ContentState carries everything that changes during a workout.
@available(iOS 16.2, *)
struct WorkoutActivityAttributes: ActivityAttributes {

    // ── Static data (set once at activity start) ──────────────────────────────
    var sessionName: String

    // ── Dynamic data (updated on each set / timer event) ─────────────────────
    public struct ContentState: Codable, Hashable {
        /// Name of the exercise currently being performed.
        var exerciseName: String
        /// How many sets have been completed so far across the whole session.
        var setsDone: Int
        /// Total sets in the session.
        var setsTotal: Int
        /// When the rest timer expires.
        /// Set to `Date.distantPast` (or any past date) when no timer is active.
        var timerEndsAt: Date
        /// Working weight in kg (0 = bodyweight / not applicable).
        var weightKg: Double
        /// Target reps for the current set.
        var reps: Int
    }
}
