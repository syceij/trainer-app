import SwiftUI

/// Root tabbed interface — 5 icon-only tabs (Home / Train / Progress /
/// Bros / PT). First four use custom PNG icons shipped in
/// Assets.xcassets (HomeIcon / TrainIcon / ProgressIcon / BrosIcon);
/// PT keeps its SF Symbol because no custom PNG was provided.
///
/// No text labels appear under the icons — VoiceOver still announces
/// each tab via the Label's transparent Text so accessibility isn't
/// degraded.
struct MainTabView: View {
    @EnvironmentObject var app: AppState

    /// Runs ONCE at type-initialisation time (before the first View
    /// instance is created), so UITabBar appearance is set before
    /// SwiftUI's TabView captures it. Doing this in an instance `init`
    /// can be too late on some iOS versions — the tab bar reads
    /// appearance at layout time and caches it.
    private static let appearanceConfigured: Void = {
        // Zero-out the title slot completely: 0.01pt font so the title
        // takes zero vertical space, clear colour so even if the system
        // ignores the tiny font it renders invisibly, and a huge
        // off-screen position offset as a third layer of defence.
        let clear: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.clear,
            .font: UIFont.systemFont(ofSize: 0.01)
        ]
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.titleTextAttributes      = clear
        itemAppearance.selected.titleTextAttributes    = clear
        itemAppearance.focused.titleTextAttributes     = clear
        itemAppearance.disabled.titleTextAttributes    = clear
        itemAppearance.normal.titlePositionAdjustment   = UIOffset(horizontal: 0, vertical: 9999)
        itemAppearance.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 9999)

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.stackedLayoutAppearance       = itemAppearance
        appearance.inlineLayoutAppearance        = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        // Push the icon down so it sits visually centred in the tab
        // cell. `top: 6` (down from 10) lifts the whole icon row a
        // touch higher, which combined with the smaller 22pt icons
        // makes the bar feel more compact without changing the
        // system-controlled overall tab-bar height.
        UITabBarItem.appearance().imageInsets =
            UIEdgeInsets(top: 6, left: 0, bottom: -6, right: 0)
    }()

    init() {
        _ = Self.appearanceConfigured
    }

    var body: some View {
        TabView(selection: $app.activeTab) {
            NavigationStack { HomeView() }
                .tabItem {
                    customTabLabel(
                        title: app.language == "ar" ? "الرئيسية" : "Home",
                        imageName: "HomeIcon"
                    )
                }
                .tag(AppState.Tab.home)

            NavigationStack { TrainView() }
                .tabItem {
                    customTabLabel(
                        title: app.language == "ar" ? "تدريب" : "Train",
                        imageName: "TrainIcon"
                    )
                }
                .tag(AppState.Tab.train)

            NavigationStack { ProgressTabView() }
                .tabItem {
                    customTabLabel(
                        title: app.language == "ar" ? "تقدم" : "Progress",
                        imageName: "ProgressIcon"
                    )
                }
                .tag(AppState.Tab.progress)

            NavigationStack { CrewView() }
                .tabItem {
                    customTabLabel(
                        title: app.language == "ar" ? "أصدقاء" : "Bros",
                        imageName: "BrosIcon"
                    )
                }
                .tag(AppState.Tab.bros)

            NavigationStack { PTChatView() }
                .tabItem {
                    Label("", systemImage: "bubble.left")
                }
                .tag(AppState.Tab.pt)
        }
        .tint(HexTheme.accent)
        .onChange(of: app.activeTab) { _ in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    /// Build a Label with an empty title Text — combined with the
    /// appearance-level title hiding above, this guarantees no text
    /// renders below the icon AND that the layout doesn't reserve
    /// any visible character box for it. Accessibility falls back
    /// to "Tab N of 5" announcement (acceptable trade-off for a
    /// cleanly empty visual).
    @ViewBuilder
    private func customTabLabel(title: String, imageName: String) -> some View {
        if let ui = Self.tabBarIcon(named: imageName) {
            Label {
                Text("")
            } icon: {
                Image(uiImage: ui)
            }
        } else {
            Label("", systemImage: "circle")
        }
    }

    /// Load an Asset-catalog image and downscale it to a tab-bar-
    /// appropriate point size. Source PNGs are 512x512 or 2000x2000
    /// (the train one) at @1x, which would render unreasonably large
    /// — we explicitly redraw at the requested point size at the
    /// device's @3x scale.
    private static func tabBarIcon(named imageName: String) -> UIImage? {
        guard let raw = UIImage(named: imageName) else { return nil }
        // 22pt — smaller still after a second pass of user feedback
        // ("make the whole navbar a bit smaller"). iOS doesn't expose
        // the system tab-bar height as settable, so the bar appears
        // smaller by virtue of the icon row taking less vertical space.
        let pointSize: CGFloat = 22
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: pointSize, height: pointSize),
            format: format
        )
        let scaled = renderer.image { _ in
            raw.draw(in: CGRect(
                x: 0, y: 0, width: pointSize, height: pointSize
            ))
        }
        return scaled.withRenderingMode(.alwaysTemplate)
    }
}
