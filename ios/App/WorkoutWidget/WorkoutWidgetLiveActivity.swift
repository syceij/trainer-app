import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

// NOTE: `ToggleSetIntent` previously lived here. It was moved to
// `ios/App/App/ToggleSetIntent.swift` (registered in both the App and
// WorkoutWidget targets) because `LiveActivityIntent.perform()` runs
// inside the host app's process — so the App binary needs the type's
// AppIntents metadata at runtime. With the intent only present in the
// widget extension, iOS could not resolve it at tap time and Lock Screen
// taps silently fired nothing.

// MARK: - Live Activity widget UI

// ── Design tokens matching the HEX app ───────────────────────────────────────
// The accent is computed on every read from the App Group UserDefaults
// key written by the main app's `setAccentChoice`. Doing it as a
// computed property (rather than a `let` constant captured at widget
// load) means switching colour in the in-app picker repaints the Lock
// Screen card on the next render — and the main app re-pushes a
// no-op `Activity.update` so that next render happens immediately.
private let hexBg         = Color(red: 0.039, green: 0.039, blue: 0.039)  // #0A0A0A
private let hexDim        = Color.white.opacity(0.50)
private let hexMute       = Color.white.opacity(0.32)
private let hexMutedBg    = Color.white.opacity(0.07)
private let hexBorder     = Color.white.opacity(0.10)

/// User-chosen accent surface (lime / cream / electric / magenta /
/// orange). Falls back to the historical neon lime when the App Group
/// key is absent — covers fresh installs before the user opens the
/// app picker for the first time.
private var hexAccent: Color {
    // Default is "cream" (#E7E5E0) — the app's main signature
    // colour per user choice. Existing users keep their pick.
    let raw = UserDefaults(suiteName: "group.com.hexapp.training")?
        .string(forKey: "accent_choice_v1") ?? "cream"
    switch raw {
    case "cream":    return Color(red: 0.906, green: 0.898, blue: 0.878) // #E7E5E0
    case "electric": return Color(red: 0.0,   green: 0.898, blue: 1.0)   // #00E5FF
    case "magenta":  return Color(red: 1.0,   green: 0.176, blue: 0.612) // #FF2D9C
    case "orange":   return Color(red: 1.0,   green: 0.549, blue: 0.0)   // #FF8C00
    case "crimson":  return Color(red: 1.0,   green: 0.2,   blue: 0.267) // #FF3344
    case "royal":    return Color(red: 0.482, green: 0.380, blue: 1.0)   // #7B61FF
    case "gold":     return Color(red: 1.0,   green: 0.769, blue: 0.0)   // #FFC400
    case "lime":     return Color(red: 0.722, green: 1.0,   blue: 0.0)   // #B8FF00
    default:         return Color(red: 0.906, green: 0.898, blue: 0.878) // cream
    }
}

/// Material applied on top of the accent (matte / glossy / metal /
/// neon). Read from the same App Group key the main app writes via
/// `AppState.setAccentMaterial`. Implemented as a private helper in
/// this file rather than importing Theme.swift's `AccentMaterial`
/// because the widget target compiles independently — keeping the
/// dependency surface as small as possible avoids a target-membership
/// problem the next time we touch the project file.
private var hexAccentMaterial: String {
    UserDefaults(suiteName: "group.com.hexapp.training")?
        .string(forKey: "accent_material_v1") ?? "matte"
}

/// Build a fill style for shapes that should reflect the chosen
/// material. Mirrors `HexTheme.accentFill` in Theme.swift — kept in
/// sync by hand because the widget target doesn't link the main app's
/// Theme.swift (only the small set of types in WorkoutActivityAttributes
/// + ToggleSetIntent are shared).
private var hexAccentFill: AnyShapeStyle {
    let base = hexAccent
    switch hexAccentMaterial {
    case "glossy":
        return AnyShapeStyle(LinearGradient(
            colors: [base.blendWhite(0.40), base, base.blendBlack(0.15)],
            startPoint: .top, endPoint: .bottom
        ))
    case "metal":
        return AnyShapeStyle(LinearGradient(
            colors: [
                base.blendBlack(0.18), base.blendWhite(0.30),
                base.blendBlack(0.25), base.blendWhite(0.15),
                base.blendBlack(0.10)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ))
    default:
        // Neon / Chrome / Holographic / Frost were removed — any
        // stored UserDefaults value pointing at them falls through
        // here and renders matte.
        return AnyShapeStyle(base)
    }
}

// MARK: - Color blending helpers (widget-local copy)
// Same algorithm as `Color.blendWhite` / `blendBlack` in the main
// app's Theme.swift. Duplicated here so the widget target doesn't
// have to import Theme.swift (kept out of WorkoutWidget Sources for
// the same target-membership reason cited above).
private extension Color {
    func blendWhite(_ amount: Double) -> Color {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let t = CGFloat(min(max(amount, 0), 1))
        return Color(
            red:   Double(r + (1 - r) * t),
            green: Double(g + (1 - g) * t),
            blue:  Double(b + (1 - b) * t)
        )
    }
    func blendBlack(_ amount: Double) -> Color {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let t = CGFloat(1 - min(max(amount, 0), 1))
        return Color(
            red:   Double(r * t),
            green: Double(g * t),
            blue:  Double(b * t)
        )
    }
}

// ── Lock Screen / Notification Banner view ────────────────────────────────────
//
// Layout intentionally minimal — user spec is "exercise name + weight +
// set buttons + timer (right side) + the session-progress line that's
// at the top of the Train page". Stripped out:
//   • Session-name header (`PULL B + ARMS`)
//   • Metadata line (`3 × 12 · RPE 7`)
//   • Tag chip (`accessory`)
//   • Focus / notes italic line
//   • "rest 1 / 5" exercise counter
// All of that info still lives in the staged ContentState in case we
// want it back later, just not rendered.
struct WorkoutLockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    private var s: WorkoutActivityAttributes.ContentState { context.state }
    private var hasTimer: Bool { s.restEndsAt > Date() }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ── Top: session-wide progress bar ─────────────────────────
            // Mirrors the line at the top of TrainView. Drives off
            // sessionProgress = (priorSetsDone + setsDone) / totalSessionSets.
            sessionProgressBar

            // ── Header row: exercise name + weight pill ────────────────
            HStack(alignment: .top, spacing: 12) {
                Text(s.exerciseName)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                weightPill
            }

            // ── Set buttons row (with timer on the right, like TrainView) ─
            HStack(alignment: .center, spacing: 10) {
                setButtonsRow
                if hasTimer {
                    Spacer(minLength: 4)
                    restTimerLabel
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(hexBg)
    }

    // MARK: - Sub-views

    /// Thin lime-fill progress line, with a "DONE / TOTAL sets complete"
    /// caption beneath. Matches the TrainView top progress bar visually
    /// (4pt height, spring animation, dim caption).
    private var sessionProgressBar: some View {
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 4)
                    Capsule()
                        .fill(hexAccentFill)
                        .frame(width: geo.size.width * s.sessionProgress, height: 4)
                        .animation(.spring(response: 0.4, dampingFraction: 0.85),
                                   value: s.sessionProgress)
                }
            }
            .frame(height: 4)

            Text("\(s.sessionSetsDone) / \(s.totalSessionSets) sets complete")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(hexDim)
        }
    }

    /// Lime-outlined weight pill in the top-right corner.
    private var weightPill: some View {
        let label: String = {
            if let l = s.weightLabel, !l.isEmpty { return l }
            if s.weightKg > 0 {
                let w = s.weightKg
                return w == w.rounded() ? "\(Int(w))kg" : String(format: "%.1fkg", w)
            }
            return "—"
        }()
        return Text(label)
            .font(.system(size: 14, weight: .heavy))
            .foregroundStyle(hexAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(hexAccent.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(hexAccent, lineWidth: 1.2)
            )
    }

    /// Compact countdown shown to the right of the set buttons after a
    /// set is checked. Matches TrainView's `timerRing` placement (right
    /// of the buttons, not below them).
    private var restTimerLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: "timer")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(hexAccent)
            Text(s.restEndsAt, style: .timer)
                .font(.system(size: 13, weight: .heavy).monospacedDigit())
                .foregroundStyle(hexAccent)
                .contentTransition(.numericText(countsDown: true))
        }
    }

    /// Row of numbered set buttons. Buttons are interactive on iOS 17+
    /// via the `Button(intent:)` initialiser.
    private var setButtonsRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<s.setsTotal, id: \.self) { i in
                setButton(index: i)
            }
        }
    }

    @ViewBuilder
    private func setButton(index i: Int) -> some View {
        // Widget target's deployment minimum is iOS 17 — no runtime
        // availability check needed. `.buttonStyle(.plain)` suppresses
        // iOS's default system-blue accent tint so the lime fill / black
        // checkmark / dim number render with the colours from
        // `setLabel` exactly as written. Inlining `s.setsCompleted[i]`
        // inside the Button closure forces a fresh read on every body
        // re-evaluation.
        Button(intent: ToggleSetIntent(setIndex: i)) {
            setLabel(i: i, done: s.setsCompleted[i])
        }
        .buttonStyle(.plain)
    }

    /// One set-button face. Filled lime when done, neutral when pending.
    /// Sized 36×36 to keep the full card under Apple's ~220pt Lock
    /// Screen Live Activity cap.
    @ViewBuilder
    private func setLabel(i: Int, done: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(done ? hexAccentFill : AnyShapeStyle(hexMutedBg))
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(done ? Color.clear : hexBorder, lineWidth: 1)
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.black)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text("\(i + 1)")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(hexDim)
                    .transition(.opacity)
            }
        }
        .frame(width: 36, height: 36)
        // Explicit animation on the `done` change — gives SwiftUI a
        // hint that this view's content depends on the bit and should
        // re-render when it flips. Also makes the state change visible
        // to the user as a quick fill animation.
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: done)
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
            let hasTimer = s.restEndsAt > Date()

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
                    HStack(spacing: 8) {
                        // Pack as many set buttons as fit — Dynamic Island
                        // expanded height is ~160pt, so 5+ usually still works.
                        ForEach(0..<s.setsTotal, id: \.self) { i in
                            islandSetButton(state: s, index: i)
                        }
                        Spacer(minLength: 0)
                        if hasTimer {
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.system(size: 10))
                                    .foregroundStyle(hexAccent)
                                Text(s.restEndsAt, style: .timer)
                                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(hexAccent)
                                    .contentTransition(.numericText(countsDown: true))
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }

            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(hexAccent)

            } compactTrailing: {
                if hasTimer {
                    Text(s.restEndsAt, style: .timer)
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
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(hexAccent)
            }
        }
    }

    /// Smaller set-button variant for the Dynamic Island expanded bottom row.
    /// Same plumbing rationale as `setButton` — widget deployment target
    /// is iOS 17, the runtime gate is redundant, and `.buttonStyle(.plain)`
    /// keeps the lime / dim-grey colours from `islandSetFace` intact.
    @ViewBuilder
    private func islandSetButton(state s: WorkoutActivityAttributes.ContentState,
                                 index i: Int) -> some View {
        Button(intent: ToggleSetIntent(setIndex: i)) {
            islandSetFace(done: s.setsCompleted[i], index: i)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func islandSetFace(done: Bool, index i: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(done ? hexAccentFill : AnyShapeStyle(hexMutedBg))
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.black)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text("\(i + 1)")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(hexDim)
                    .transition(.opacity)
            }
        }
        .frame(width: 32, height: 32)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: done)
    }
}
