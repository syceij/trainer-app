import ActivityKit
import Foundation

/// Shared between the main app (starts/updates activities) and the
/// WorkoutWidget extension (renders the lock-screen / Dynamic Island UI).
///
/// The attribute type is fixed for the lifetime of an activity.
/// ContentState carries everything that changes during a workout.
///
/// **Xcode setup:** ensure this file is a member of BOTH the App and
/// WorkoutWidget targets (File Inspector → Target Membership).
@available(iOS 16.2, *)
struct WorkoutActivityAttributes: ActivityAttributes {

    // ── Static data (set once at activity start) ──────────────────────────────
    var sessionName: String

    // ── Dynamic data (updated on each set / timer event) ─────────────────────
    public struct ContentState: Codable, Hashable {
        /// Name of the exercise currently being performed.
        var exerciseName: String
        /// 0-based position of this exercise in the staged session.
        var exerciseIndex: Int
        /// Total number of exercises in the staged session.
        var totalExercises: Int

        /// Per-set completion flags. `setsCompleted.count` is the total
        /// number of sets for the current exercise; `filter { $0 }.count`
        /// is how many have been finished.
        var setsCompleted: [Bool]
        /// Target reps string, e.g. `"8-10"`.
        var targetReps: String
        /// Working weight in kg. `0` when bodyweight or unset — see `weightLabel`.
        var weightKg: Double
        /// Display label for non-numeric weights, e.g. `"BW"`. Nil otherwise.
        var weightLabel: String?
        /// Target RPE descriptor, e.g. `"7-8"`. Nil when not prescribed.
        var targetRpe: String?
        /// Exercise tag, e.g. `"compound"` / `"accessory"`. Nil when absent.
        var tag: String?
        /// Optional focus / sub-header text rendered under the metadata.
        var focus: String?

        /// When the rest timer expires.
        /// Use `Date.distantPast` (or any past date) when no timer is active.
        var restEndsAt: Date
        /// User's chosen rest duration in seconds (default 60).
        var restSeconds: Int

        // MARK: - Computed conveniences

        var setsTotal: Int { setsCompleted.count }
        var setsDone: Int  { setsCompleted.filter { $0 }.count }
        var allSetsDone: Bool { !setsCompleted.isEmpty && setsCompleted.allSatisfy { $0 } }

        // MARK: - Init

        init(
            exerciseName: String,
            exerciseIndex: Int = 0,
            totalExercises: Int = 1,
            setsCompleted: [Bool],
            targetReps: String,
            weightKg: Double,
            weightLabel: String? = nil,
            targetRpe: String? = nil,
            tag: String? = nil,
            focus: String? = nil,
            restEndsAt: Date = .distantPast,
            restSeconds: Int = 60
        ) {
            self.exerciseName    = exerciseName
            self.exerciseIndex   = exerciseIndex
            self.totalExercises  = totalExercises
            self.setsCompleted   = setsCompleted
            self.targetReps      = targetReps
            self.weightKg        = weightKg
            self.weightLabel     = weightLabel
            self.targetRpe       = targetRpe
            self.tag             = tag
            self.focus           = focus
            self.restEndsAt      = restEndsAt
            self.restSeconds     = restSeconds
        }
    }
}
