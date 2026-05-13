import ActivityKit
import WidgetKit
import SwiftUI

// ── Design tokens matching the HEX app ───────────────────────────────────────
private let hexAccent     = Color(red: 0.722, green: 1.0,   blue: 0.0)    // #B8FF00
private let hexBg         = Color(red: 0.039, green: 0.039, blue: 0.039)  // #0A0A0A
private let hexDim        = Color.white.opacity(0.38)
private let hexMutedBg    = Color.white.opacity(0.07)

// ── Helpers ───────────────────────────────────────────────────────────────────
private func formatTime(_ date: Date) -> String {
    let remaining = max(0, Int(date.timeIntervalSinceNow))
    return String(format: "%d:%02d", remaining / 60, remaining % 60)
}

// ── Lock Screen / Notification Banner view ────────────────────────────────────
// Deployment target for this extension is 16.2, so no @available guard needed.
struct WorkoutLockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    private var s: WorkoutActivityAttributes.ContentState { context.state }
    private var hasTimer: Bool { s.timerEndsAt > Date() }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {

            // Left column: icon circle
            ZStack {
                Circle()
                    .fill(hexAccent.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(hexAccent)
            }

            // Right column: content
            VStack(alignment: .leading, spacing: 4) {

                // Session name
                Text(s.sessionName.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(hexDim)
                    .kerning(1.2)
                    .lineLimit(1)

                // Exercise name — big
                Text(s.exerciseName)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Progress row
                HStack(spacing: 8) {
                    // Set dots
                    HStack(spacing: 3) {
                        ForEach(0..<min(s.setsTotal, 8), id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(i < s.setsDone ? hexAccent : hexMutedBg)
                                .frame(width: 14, height: 5)
                        }
                    }

                    Spacer()

                    // Weight × reps
                    if s.weightKg > 0 {
                        Text("\(Int(s.weightKg)) kg × \(s.reps)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(hexDim)
                    } else if s.reps > 0 {
                        Text("\(s.reps) reps")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(hexDim)
                    }
                }

                // Rest timer — uses iOS's built-in live countdown
                if hasTimer {
                    HStack(spacing: 5) {
                        Image(systemName: "timer")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(hexAccent)

                        Text(s.timerEndsAt, style: .timer)
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundStyle(hexAccent)
                            .contentTransition(.numericText(countsDown: true))

                        Text("rest")
                            .font(.system(size: 11))
                            .foregroundStyle(hexDim)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(hexBg)
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
            let hasTimer = s.timerEndsAt > Date()

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
                    HStack {
                        if s.weightKg > 0 {
                            Text("\(Int(s.weightKg)) kg × \(s.reps)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(hexDim)
                        } else if s.reps > 0 {
                            Text("\(s.reps) reps")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(hexDim)
                        }

                        Spacer()

                        if hasTimer {
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.system(size: 10))
                                    .foregroundStyle(hexAccent)
                                Text(s.timerEndsAt, style: .timer)
                                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(hexAccent)
                                    .contentTransition(.numericText(countsDown: true))
                            }
                        }
                    }
                }

            } compactLeading: {
                // ── Compact leading ───────────────────────────────────────────
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(hexAccent)

            } compactTrailing: {
                // ── Compact trailing ─────────────────────────────────────────
                if hasTimer {
                    Text(s.timerEndsAt, style: .timer)
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
                // ── Minimal (stacked) ─────────────────────────────────────────
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(hexAccent)
            }
        }
    }
}
