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
        // Title slot is VISIBLE now (per user request — "add name of the
        // page under each icon"). 9pt heavy keeps it compact under the
        // 22pt icons without forcing a taller bar. Colours: the system
        // tints automatically — the "selected" attribute is intentionally
        // left at default so SwiftUI's `.tint(HexTheme.accent)` on the
        // TabView picks both the icon and the label colour for free.
        let normalAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(white: 0.55, alpha: 1.0),
            .font: UIFont.systemFont(ofSize: 9, weight: .heavy)
        ]
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.titleTextAttributes   = normalAttrs
        itemAppearance.selected.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 9, weight: .heavy)
        ]

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.stackedLayoutAppearance       = itemAppearance
        appearance.inlineLayoutAppearance        = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        // Reset image insets back to the system default — we want the
        // icon to leave room for the title below it. Empty UIEdgeInsets
        // gives the standard iOS spacing between icon top + label bottom.
        UITabBarItem.appearance().imageInsets = .zero
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
                    Label(app.language == "ar" ? "المدرب" : "PT",
                          systemImage: "bubble.left")
                }
                .tag(AppState.Tab.pt)
        }
        .tint(HexTheme.accent)
        .onChange(of: app.activeTab) { _ in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    /// Build a `Label` that renders the supplied title text underneath
    /// the custom PNG icon. Titles are bilingual — passed in from the
    /// tab declaration site using `app.language` — and styled by the
    /// `UITabBarItemAppearance` configured above (9pt heavy, dim grey
    /// when unselected, accent tint when selected).
    @ViewBuilder
    private func customTabLabel(title: String, imageName: String) -> some View {
        if let ui = Self.tabBarIcon(named: imageName) {
            Label {
                Text(title)
            } icon: {
                Image(uiImage: ui)
            }
        } else {
            Label(title, systemImage: "circle")
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
