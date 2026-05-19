import SwiftUI

/// Root view — switches between auth flow and the main tab bar based on
/// the current auth phase in AppState.
struct ContentView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            HexTheme.bg.ignoresSafeArea()

            Group {
                switch app.authPhase {
                case .checking:
                    splash
                case .signedOut:
                    NavigationStack {
                        LoginView()
                    }
                case .awaitingOTP(let email):
                    NavigationStack {
                        OTPView(email: email)
                    }
                case .signedIn:
                    MainTabView()
                }
            }
            // Global Arabic font override — applies to every Text view
            // that DOESN'T set its own `.font(...)`. View-level explicit
            // fonts win, but as a baseline default this routes uncustomised
            // text through ThmanyahSans-Bold instead of SF Pro. SwiftUI
            // ignores the env override entirely when language is English.
            .environment(\.font,
                         app.language == "ar"
                            ? .custom(HexTheme.thmanyahBold, size: 15)
                            : .system(size: 15))
            .animation(.easeInOut(duration: 0.25), value: app.authPhase)

            // Confetti overlay — fires when AppState.confettiTrigger changes
            ConfettiBurst(trigger: app.confettiTrigger)
                .allowsHitTesting(false)

            // Toast overlay
            if let msg = app.toast {
                VStack {
                    Text(msg)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(HexTheme.accentFill)
                        )
                        .shadow(color: HexTheme.accent.opacity(0.35), radius: 12)
                        .padding(.top, 8)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // When the app foregrounds, drain any sets the user completed on
        // the Lock Screen while the app was in the background. The queue
        // lives in the App Group store and is written by ToggleSetIntent.
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active, app.authPhase == .signedIn {
                Task { await app.drainPendingSets() }
            }
        }
        // Session Complete sheet — TrainView's Finish button populates
        // `app.pendingSessionSummary`; this presents the review modal.
        // Sheet dismisses automatically when the summary is cleared
        // (either via "Save Session" → `confirmFinishSession` or
        // "Cancel" → `cancelPendingSession`).
        .sheet(item: $app.pendingSessionSummary) { summary in
            SessionCompleteView(summary: summary)
                .environmentObject(app)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }

    private var splash: some View {
        // Replaces the old breathing-dumbbell loader with a multi-layer
        // orbital design — feels like a system booting, not a yoga
        // class. The splash dismisses as soon as `loadUserData()`
        // returns; this view is just what users see during that fetch.
        HexLoadingView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .hexBackground()
    }
}

/// Futuristic loading view.
///
/// Composition (back to front):
///   1. Radial accent halo — adds soft depth without being noisy.
///   2. Static brand hexagon outline (the "HEX" mark, subtle).
///   3. Slow CW-rotating dashed ring — base rhythm.
///   4. Three bright orbital nodes — fast CW, the eye locks onto these.
///   5. Inner gradient arc, counter-rotating — opposite direction
///      makes the composition feel like layers rotating in 3D.
///   6. Centred dumbbell logo with a rapid glow pulse (~0.4s cycle).
///
/// Driven by `TimelineView(.animation)` so every frame is computed
/// from a single time source — smoother than chaining
/// `.repeatForever` animations and produces no animation-glitch when
/// the splash dismisses mid-cycle.
private struct HexLoadingView: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                // 1. Soft accent halo behind everything
                RadialGradient(
                    colors: [HexTheme.accent.opacity(0.18), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 140
                )
                .frame(width: 280, height: 280)

                // 2. Static brand hexagon (matches the app name)
                HexagonShape()
                    .stroke(HexTheme.accent.opacity(0.22), lineWidth: 1)
                    .frame(width: 210, height: 210)

                // 3. Outer dashed ring — slow CW (30°/s)
                Circle()
                    .strokeBorder(
                        HexTheme.accent.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 10])
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(t * 30))

                // 4. Three orbital nodes at 120° spacing, fast CW (120°/s)
                ForEach(0..<3, id: \.self) { i in
                    let deg = Double(i) * 120.0 + t * 120.0
                    let rad = deg * .pi / 180.0
                    Circle()
                        .fill(HexTheme.accent)
                        .frame(width: 7, height: 7)
                        .shadow(color: HexTheme.accent, radius: 8)
                        .offset(x: 90 * cos(rad), y: 90 * sin(rad))
                }

                // 5. Inner gradient arc counter-rotating (180°/s CCW)
                Circle()
                    .trim(from: 0.0, to: 0.32)
                    .stroke(
                        AngularGradient(
                            colors: [.clear, HexTheme.accent, HexTheme.accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .frame(width: 115, height: 115)
                    .rotationEffect(.degrees(-t * 180))

                // 6. Core logo with pulsing glow halo
                core(t: t)
            }
        }
        .frame(width: 280, height: 280)
    }

    /// Centred dumbbell with a sinusoidal glow + scale pulse driven
    /// by the timeline `t`. ~0.4s cycle reads as a rapid heartbeat.
    @ViewBuilder
    private func core(t: Double) -> some View {
        // sin → 0..1
        let pulse = (sin(t * 5.0) + 1.0) * 0.5
        let scale = 0.94 + pulse * 0.10
        let glow  = 0.25 + pulse * 0.40

        ZStack {
            Circle()
                .fill(HexTheme.accent)
                .frame(width: 64, height: 64)
                .blur(radius: 18)
                .opacity(glow)

            Image("LoadingLogo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(HexTheme.accent)
                .frame(width: 64, height: 64)
                .scaleEffect(scale)
        }
    }
}

/// Regular hexagon, point-up. Used as the static brand mark behind
/// the orbital rings — the "HEX" in the app name made literal.
private struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius: CGFloat = min(rect.width, rect.height) / 2
        var path = Path()
        for i in 0..<6 {
            // Start angle at -90° so a vertex is at the top. Use
            // CGFloat throughout so the trig + multiply doesn't go
            // ambiguous between Double and CGFloat overloads.
            let angle: CGFloat = CGFloat(i) * .pi / 3.0 - .pi / 2.0
            let pt = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}
