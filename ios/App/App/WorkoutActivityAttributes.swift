import ActivityKit
import Foundation

/// Shared between the main app (starts/updates activities) and the
/// WorkoutWidget extension (renders the lock-screen / Dynamic Island UI).
///
/// The attribute type is fixed for the lifetime of an activity.
/// ContentState carries everything that changes during a workout.
///
/// **Xcode setup:** this file is already a member of BOTH the App and
/// WorkoutWidget targets (see project.pbxproj — confirmed at file refs
/// for both targets). The `WorkoutGroupStore` helpers and DTOs below
/// piggyback on that same target membership so we don't have to add
/// new source files to the pbxproj (which CI's `xcodebuild` can't see
/// unless the project file is edited).
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
        /// Per-exercise rest seconds (the user's chip choice for THIS
        /// exercise). Was previously a session-wide value — moved to
        /// per-exercise so the Lock Screen timer matches what the user
        /// picked on each exercise card.
        var restSeconds: Int

        /// Sets completed across all exercises BEFORE the current one.
        /// Used to drive the session-wide top progress bar in the LA
        /// card without needing to send the whole prior history.
        /// Defaulted because old encoded states may not have it.
        var priorSetsDone: Int = 0
        /// Total sets across every exercise in the staged session.
        /// Drives the denominator of the session-wide progress bar.
        var totalSessionSets: Int = 0

        // MARK: - Computed conveniences

        var setsTotal: Int { setsCompleted.count }
        var setsDone: Int  { setsCompleted.filter { $0 }.count }
        var allSetsDone: Bool { !setsCompleted.isEmpty && setsCompleted.allSatisfy { $0 } }

        /// Session-wide completion count = sets done on prior exercises
        /// plus sets completed on the current one.
        var sessionSetsDone: Int { priorSetsDone + setsDone }
        /// Session-wide completion fraction 0…1.
        var sessionProgress: Double {
            guard totalSessionSets > 0 else { return 0 }
            return min(1, max(0, Double(sessionSetsDone) / Double(totalSessionSets)))
        }

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
            restSeconds: Int = 60,
            priorSetsDone: Int = 0,
            totalSessionSets: Int = 0
        ) {
            self.exerciseName     = exerciseName
            self.exerciseIndex    = exerciseIndex
            self.totalExercises   = totalExercises
            self.setsCompleted    = setsCompleted
            self.targetReps       = targetReps
            self.weightKg         = weightKg
            self.weightLabel      = weightLabel
            self.targetRpe        = targetRpe
            self.tag              = tag
            self.focus            = focus
            self.restEndsAt       = restEndsAt
            self.restSeconds      = restSeconds
            self.priorSetsDone    = priorSetsDone
            self.totalSessionSets = totalSessionSets
        }
    }
}

// MARK: - App Group store (inlined here so it ships with both targets
//                          without requiring a new pbxproj entry)

/// Shared storage between the main app and the WorkoutWidget extension.
///
/// The Live Activity ContentState payload is capped at ~4KB and can't
/// carry the whole staged session inline, so we mirror it here at
/// session start. The widget's `ToggleSetIntent` then reads this when
/// it needs to look up the next exercise.
///
/// We also use this as an offline queue for completed sets — the App
/// Intent doesn't have a live Supabase session (different process), so
/// it appends `PendingSetDTO`s and the main app drains the queue on
/// next launch / foreground.
///
/// **Xcode setup required (one-time, manual):**
///   1. Apple Developer portal → Identifiers → App Groups → add
///      `group.com.hexapp.training`.
///   2. Xcode → App target → Signing & Capabilities → `+ Capability` →
///      App Groups → tick `group.com.hexapp.training`.
///   3. Repeat for the WorkoutWidget target.
enum WorkoutGroupStore {

    /// Shared App Group suite name — must match the entitlement on both
    /// the main app and WorkoutWidget targets.
    static let suiteName = "group.com.hexapp.training"

    /// Lazy-initialised shared UserDefaults. `nil` on simulator builds
    /// where the App Group isn't configured — callers should fall back
    /// gracefully (no-op rather than crash).
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    // MARK: - Keys

    private enum K {
        static let stagedSession    = "staged_session_v1"
        static let pendingSets      = "pending_sets_v1"
        static let finishedSessions = "finished_session_ids_v1"
    }

    // MARK: - Staged session

    /// Persist the staged workout session so the widget extension can
    /// advance through its exercises without a live IPC channel.
    static func saveStagedSession(_ dto: StagedSessionDTO) {
        guard let d = defaults,
              let data = try? JSONEncoder().encode(dto) else { return }
        d.set(data, forKey: K.stagedSession)
    }

    static func loadStagedSession() -> StagedSessionDTO? {
        guard let d = defaults,
              let data = d.data(forKey: K.stagedSession) else { return nil }
        return try? JSONDecoder().decode(StagedSessionDTO.self, from: data)
    }

    static func clearStagedSession() {
        defaults?.removeObject(forKey: K.stagedSession)
    }

    // MARK: - Pending-sets queue

    /// Append a set completion to the queue. The main app drains this on
    /// next launch and writes the rows to Supabase.
    static func appendPendingSet(_ set: PendingSetDTO) {
        guard let d = defaults else { return }
        var current = loadPendingSets()
        current.append(set)
        if let data = try? JSONEncoder().encode(current) {
            d.set(data, forKey: K.pendingSets)
        }
    }

    static func loadPendingSets() -> [PendingSetDTO] {
        guard let d = defaults,
              let data = d.data(forKey: K.pendingSets),
              let list = try? JSONDecoder().decode([PendingSetDTO].self, from: data)
        else { return [] }
        return list
    }

    static func clearPendingSets() {
        defaults?.removeObject(forKey: K.pendingSets)
    }

    // MARK: - Finished-session markers

    /// When the App Intent ends a Live Activity because the user tapped
    /// the last set of the last exercise, record the sessionId here. The
    /// main app's drain logic reads this list to decide whether to fire
    /// the full `finishWorkout` flow.
    static func markSessionFinished(_ sessionId: UUID) {
        guard let d = defaults else { return }
        var current = loadFinishedSessionIds()
        if !current.contains(sessionId) {
            current.append(sessionId)
        }
        if let data = try? JSONEncoder().encode(current) {
            d.set(data, forKey: K.finishedSessions)
        }
    }

    static func loadFinishedSessionIds() -> [UUID] {
        guard let d = defaults,
              let data = d.data(forKey: K.finishedSessions),
              let list = try? JSONDecoder().decode([UUID].self, from: data)
        else { return [] }
        return list
    }

    static func clearFinishedSessionIds() {
        defaults?.removeObject(forKey: K.finishedSessions)
    }
}

// MARK: - DTOs (shipped with both targets via this file's membership)

/// Mirror of the staged WorkoutSession + its exercises in a format the
/// widget extension can decode without dragging the whole AppState
/// dependency tree. Kept intentionally flat.
struct StagedSessionDTO: Codable, Hashable {
    var sessionId: UUID
    var userId: UUID
    var programmeId: UUID?
    var name: String
    var weekNumber: Int?
    var block: String?
    var startedAt: Date
    var exercises: [StagedExerciseDTO]
    /// User-chosen rest seconds between sets (default 60).
    var restSeconds: Int
}

struct StagedExerciseDTO: Codable, Hashable {
    var key: String
    var name: String
    var sets: Int
    var reps: String
    var weightKg: Double      // 0 → bodyweight or unset
    var bodyweight: Bool
    var rpe: String?
    var tag: String?
    var focus: String?
    var notes: String?
    /// User's chosen rest seconds for THIS exercise (chip selection on
    /// the in-app card — `30s / 60s / 90s / 2m / 3m`). Defaulted so old
    /// staged payloads still decode; new payloads carry the real value.
    var restSeconds: Int = 90
}

/// A completed set the widget extension wrote while the user was on the
/// Lock Screen. The main app drains the queue on next launch and inserts
/// these into the Supabase `sets` table.
struct PendingSetDTO: Codable, Hashable {
    var id: UUID
    var sessionId: UUID
    var exerciseName: String
    var setNumber: Int
    var reps: Int
    var weightKg: Double?     // nil for bodyweight
    var completedAt: Date
}
