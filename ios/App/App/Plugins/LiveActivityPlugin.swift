import Foundation
import Capacitor
import ActivityKit

/// Capacitor plugin that exposes iOS Live Activities to the JS layer.
/// Auto-discovered by Capacitor's Objective-C runtime scan — no manual
/// registration is needed.
///
/// JS usage (after registerPlugin):
///   LiveActivity.start({ sessionName, exerciseName, setsDone, setsTotal,
///                        timerEndsAt, weightKg, reps })
///   LiveActivity.update({ ... same keys ... })
///   LiveActivity.end()
///   LiveActivity.isSupported() → { supported: Bool }
@objc(LiveActivityPlugin)
public class LiveActivityPlugin: CAPPlugin {

    // Hold a reference to the single running activity.
    // Marked as AnyObject so we don't need @available everywhere in the class.
    private var activityRef: AnyObject?

    // MARK: - isSupported

    @objc func isSupported(_ call: CAPPluginCall) {
        if #available(iOS 16.2, *) {
            let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
            print("[LiveActivity] isSupported() → areActivitiesEnabled=\(enabled)")
            call.resolve(["supported": enabled])
        } else {
            print("[LiveActivity] isSupported() → iOS < 16.2, returning false")
            call.resolve(["supported": false])
        }
    }

    // MARK: - start

    @objc func start(_ call: CAPPluginCall) {
        print("[LiveActivity] start() called")
        guard #available(iOS 16.2, *) else {
            print("[LiveActivity] start() rejected — iOS < 16.2")
            call.reject("Live Activities require iOS 16.2+")
            return
        }

        // End any existing activity first
        if let existing = activityRef as? Activity<WorkoutActivityAttributes> {
            print("[LiveActivity] ending previous activity before starting new one")
            Task { await existing.end(nil, dismissalPolicy: .immediate) }
            activityRef = nil
        }

        let attrs = WorkoutActivityAttributes(
            sessionName: call.getString("sessionName") ?? "Workout"
        )
        let state = buildState(from: call)
        print("[LiveActivity] requesting activity: session=\(attrs.sessionName) exercise=\(state.exerciseName) sets=\(state.setsDone)/\(state.setsTotal)")

        do {
            let activity = try Activity<WorkoutActivityAttributes>.request(
                attributes: attrs,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            activityRef = activity
            print("[LiveActivity] started successfully, id=\(activity.id)")
            call.resolve(["activityId": activity.id])
        } catch {
            print("[LiveActivity] Activity.request() FAILED: \(error)")
            print("[LiveActivity] Error domain: \((error as NSError).domain) code: \((error as NSError).code)")
            print("[LiveActivity] Full error: \((error as NSError).userInfo)")
            call.reject("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    // MARK: - update

    @objc func update(_ call: CAPPluginCall) {
        guard #available(iOS 16.2, *) else {
            call.resolve()
            return
        }
        guard let activity = activityRef as? Activity<WorkoutActivityAttributes> else {
            // Silently ignore if no activity is running
            call.resolve()
            return
        }
        let state = buildState(from: call)
        Task {
            await activity.update(.init(state: state, staleDate: nil))
            call.resolve()
        }
    }

    // MARK: - end

    @objc func end(_ call: CAPPluginCall) {
        guard #available(iOS 16.2, *) else {
            call.resolve()
            return
        }
        guard let activity = activityRef as? Activity<WorkoutActivityAttributes> else {
            call.resolve()
            return
        }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            activityRef = nil
            call.resolve()
        }
    }

    // MARK: - Helpers

    @available(iOS 16.2, *)
    private func buildState(from call: CAPPluginCall) -> WorkoutActivityAttributes.ContentState {
        let timerEndsAtTs = call.getDouble("timerEndsAt") ?? 0
        // Any Unix timestamp > 1_000_000_000 (Sep 2001+) is a valid future time;
        // anything else means "no timer" → use distantPast so the widget hides it.
        let timerEndsAt = timerEndsAtTs > 1_000_000_000
            ? Date(timeIntervalSince1970: timerEndsAtTs)
            : Date.distantPast

        return WorkoutActivityAttributes.ContentState(
            exerciseName: call.getString("exerciseName") ?? "Exercise",
            setsDone:     call.getInt("setsDone")        ?? 0,
            setsTotal:    call.getInt("setsTotal")       ?? 1,
            timerEndsAt:  timerEndsAt,
            weightKg:     call.getDouble("weightKg")     ?? 0,
            reps:         call.getInt("reps")            ?? 0
        )
    }
}
