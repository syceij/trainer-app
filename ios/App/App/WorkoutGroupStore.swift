import Foundation

/// Shared storage between the main app and the WorkoutWidget extension.
///
/// The Live Activity ContentState payload is capped at ~4KB by Apple and
/// can't carry the whole staged session inline, so we mirror it here at
/// session start. The `ToggleSetIntent` running inside the widget then
/// reads this when it needs to look up the next exercise.
///
/// We also use this as an offline queue for completed sets — the App
/// Intent doesn't have a live Supabase session (different process), so
/// it appends a `PendingSetDTO` and the main app drains the queue on
/// next launch / foreground.
///
/// **Xcode setup required (one-time):**
///   1. Apple Developer portal → Identifiers → App Groups → add
///      `group.com.hexapp.training` (if not already there).
///   2. In Xcode: select the **App** target → Signing & Capabilities →
///      `+ Capability` → App Groups → tick `group.com.hexapp.training`.
///   3. Repeat for the **WorkoutWidget** target.
///   4. Make sure THIS file is a member of both targets (Inspector →
///      Target Membership).
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
    /// the full `finishWorkout` flow (writes the sessions row, updates
    /// working_weights, recalculates leaderboard, posts the activity-feed
    /// entry) for that sessionId.
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

// MARK: - DTOs

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
