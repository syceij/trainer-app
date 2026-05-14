import Foundation
import UIKit
import Capacitor
import ActivityKit

/// Capacitor plugin that exposes iOS Live Activities to the JS layer.
@objc(LiveActivityPlugin)
public class LiveActivityPlugin: CAPPlugin {

    // Hold a reference to the single running activity.
    // Marked as AnyObject so we don't need @available everywhere in the class.
    private var activityRef: AnyObject?

    // MARK: - isSupported

    @objc func isSupported(_ call: CAPPluginCall) {
        if #available(iOS 16.2, *) {
            let info = ActivityAuthorizationInfo()
            print("[LiveActivity] areActivitiesEnabled: \(info.areActivitiesEnabled)")
            call.resolve(["supported": info.areActivitiesEnabled])
        } else {
            print("[LiveActivity] isSupported() → iOS < 16.2, returning false")
            call.resolve(["supported": false])
        }
    }

    // MARK: - diagnostics
    // Returns detailed status info so the JS layer can surface it for debugging.
    @objc func diagnostics(_ call: CAPPluginCall) {
        var info: [String: Any] = [
            "iosVersion": UIDevice.current.systemVersion,
            "available": false,
            "areActivitiesEnabled": false,
            "lingeringCount": 0
        ]
        if #available(iOS 16.2, *) {
            info["available"] = true
            let auth = ActivityAuthorizationInfo()
            info["areActivitiesEnabled"] = auth.areActivitiesEnabled
            info["lingeringCount"] = Activity<WorkoutActivityAttributes>.activities.count
        }
        call.resolve(info)
    }

    // MARK: - start

    @objc func start(_ call: CAPPluginCall) {
        print("[LiveActivity] start() called")
        guard #available(iOS 16.2, *) else {
            print("[LiveActivity] start() rejected — iOS < 16.2")
            call.reject("iOS 16.2+ required (currently \(UIDevice.current.systemVersion))")
            return
        }

        // Pre-flight authorization check so we fail with a clear reason.
        let authInfo = ActivityAuthorizationInfo()
        guard authInfo.areActivitiesEnabled else {
            print("[LiveActivity] start() rejected — areActivitiesEnabled=false")
            call.reject("Live Activities disabled in iOS Settings for HEX")
            return
        }

        let attrs = WorkoutActivityAttributes(
            sessionName: call.getString("sessionName") ?? "Workout"
        )
        let state = buildState(from: call)
        print("[LiveActivity] requesting activity: session=\(attrs.sessionName) exercise=\(state.exerciseName) sets=\(state.setsDone)/\(state.setsTotal)")

        // Run inside a Task so cleanup is fully awaited before Activity.request()
        Task {
            // End any activities left over from a previous app session
            let lingering = Activity<WorkoutActivityAttributes>.activities
            if !lingering.isEmpty {
                print("[LiveActivity] ending \(lingering.count) lingering activity(s)")
                for activity in lingering {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
            activityRef = nil

            do {
                let activity = try Activity<WorkoutActivityAttributes>.request(
                    attributes: attrs,
                    content: .init(state: state, staleDate: nil),
                    pushType: nil
                )
                activityRef = activity
                print("[LiveActivity] SUCCESS id=\(activity.id)")
                call.resolve(["activityId": activity.id])
            } catch {
                let nsErr = error as NSError
                let summary = "[\(nsErr.domain)#\(nsErr.code)] \(error.localizedDescription)"
                print("[LiveActivity] FAILED: \(summary)")
                print("[LiveActivity] userInfo: \(nsErr.userInfo)")
                call.reject(summary)
            }
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
        // End ALL activities of our type, not just the in-memory ref,
        // so lingering ones from previous sessions are also cleaned up.
        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
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
