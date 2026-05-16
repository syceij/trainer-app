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
        // 1:1 port of React's `LoadingScreen` in src/App.jsx:62-77.
        // Centred lime-tinted dumbbell that "breathes" — scale loops
        // 0.95 -> 1.05 -> 0.95 on a 1.2s ease-in-out cycle, forever.
        // No spinner (the React version has none either — the gentle
        // pulse is the only motion cue).
        LoadingPulseView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .hexBackground()
    }
}

/// The actual pulsing dumbbell. Lives in its own view so the @State
/// `pulse` flag survives splash dismissals and the animation kicks
/// off automatically via `.onAppear`. Template-rendered so the
/// dumbbell shape inherits the user's chosen accent colour.
private struct LoadingPulseView: View {
    @State private var pulse = false

    var body: some View {
        Image("LoadingLogo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(HexTheme.accent)
            .frame(width: 140, height: 140)
            .scaleEffect(pulse ? 1.05 : 0.95)
            .animation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: pulse
            )
            .onAppear { pulse = true }
    }
}
