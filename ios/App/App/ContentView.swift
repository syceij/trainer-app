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

/// Minimal radar-ping loader. Just the logo + three rings emanating
/// outward continuously. No rotation, no orbital nodes, no static
/// brand mark — restraint is the design.
///
/// How the motion works:
///   • Each ring's "phase" loops 0 → 1 over 1.6s. Phase 0 means the
///     ring is small + bright; phase 1 means fully expanded + invisible.
///   • Three rings share the same loop but are offset by 1/3 of the
///     period — so there's always at least one ring mid-expand and
///     one fading out, never a dead frame.
///   • The logo itself has a subtle glow + scale pulse on a faster
///     sin wave (~0.6s cycle) so the core feels alive.
///
/// Driven by `TimelineView(.animation)` so every frame derives from
/// one time source — layers stay in sync, no animation-glitch when
/// the splash dismisses mid-cycle.
private struct HexLoadingView: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate

            ZStack {
                // Three radar rings, phase-offset by 1/3 of the cycle.
                ForEach(0..<3, id: \.self) { i in
                    let phase = (t / 1.6 + Double(i) / 3.0)
                        .truncatingRemainder(dividingBy: 1.0)
                    let size: CGFloat = 60 + CGFloat(phase) * 200
                    let opacity = (1.0 - phase) * 0.55
                    Circle()
                        .stroke(HexTheme.accent, lineWidth: 1.5)
                        .frame(width: size, height: size)
                        .opacity(opacity)
                }

                // Centred logo + soft glow halo. Same sin wave drives
                // glow opacity and a small scale pulse so the core
                // breathes slightly.
                let pulse = (sin(t * 3.5) + 1.0) * 0.5

                Circle()
                    .fill(HexTheme.accent)
                    .frame(width: 60, height: 60)
                    .blur(radius: 18)
                    .opacity(0.25 + pulse * 0.25)

                Image("LoadingLogo")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(HexTheme.accent)
                    .frame(width: 60, height: 60)
                    .scaleEffect(0.95 + pulse * 0.08)
            }
        }
        .frame(width: 280, height: 280)
    }
}
