import SwiftUI

/// HEX — native SwiftUI app entry point.
@main
struct HEXApp: App {

    /// Shared app state, injected into the environment.
    @StateObject private var appState = AppState()

    /// Adopt UIApplicationDelegate so we can receive APNs token
    /// callbacks (didRegisterForRemoteNotificationsWithDeviceToken)
    /// and notification-tap callbacks — neither is available in pure
    /// SwiftUI. AppDelegate forwards everything to PushService.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        configureGlobalAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .tint(HexTheme.accent)
                .environment(\.layoutDirection,
                             appState.language == "ar" ? .rightToLeft : .leftToRight)
                .onAppear {
                    // PushService is a singleton owned by UIKit; pass
                    // it the AppState reference so tap routing works.
                    PushService.shared.app = appState
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    /// Handle a `hex://invite/<CODE>` deep link by extracting the code and
    /// asking AppState to redeem it once the user is signed in. If they're
    /// not signed in yet, we stash the code and replay it on signedIn.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "hex" else { return }
        // Path is either /invite/CODE or .host == "invite" + /CODE — accept both
        let parts = url.pathComponents.filter { $0 != "/" }
        let code: String?
        if (url.host?.lowercased() ?? "") == "invite", let first = parts.first {
            code = first
        } else if let invite = parts.first(where: { $0.lowercased() == "invite" }),
                  let idx = parts.firstIndex(of: invite), idx + 1 < parts.count {
            code = parts[idx + 1]
        } else {
            code = nil
        }
        guard let code, !code.isEmpty else { return }
        Task { @MainActor in
            if appState.authPhase == .signedIn {
                if let name = await appState.acceptInvite(code: code) {
                    appState.toast = appState.language == "ar"
                        ? "أنت الآن صديق \(name) ✓"
                        : "You're now Bros with \(name) ✓"
                }
            } else {
                appState.pendingInviteCode = code
            }
        }
    }

    // MARK: - Appearance

    /// Global UIKit appearance overrides so the navigation bar and tab bar
    /// match the HEX design (pure black, neon accent).
    private func configureGlobalAppearance() {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = .black
        nav.titleTextAttributes      = [.foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance   = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance    = nav

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = .black
        UITabBar.appearance().standardAppearance   = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}
