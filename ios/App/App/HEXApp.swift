import SwiftUI

/// HEX — native SwiftUI app entry point.
@main
struct HEXApp: App {

    /// Shared app state, injected into the environment.
    @StateObject private var appState = AppState()

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
