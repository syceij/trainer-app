import SwiftUI

/// Root tabbed interface — 5 tabs match the React BottomNav design:
/// Home / Train / Progress / Bros / PT.
///
/// The first four tabs use custom PNG icons shipped in Assets.xcassets
/// (HomeIcon / TrainIcon / ProgressIcon / BrosIcon — same source artwork
/// as `public/{home,train,progress,bros}.png` on the React side, so the
/// two clients look identical). The PT tab keeps its SF Symbol because
/// no custom icon was provided for it.
///
/// Custom-asset tab icons require:
///   • The image rendered as a template (so `tint(...)` recolours the
///     stroke instead of the icon shipping with a fixed colour).
///   • Asking SwiftUI to render the symbolic variant, not the colour
///     variant — done via `.renderingMode(.template)` on the Image
///     before it goes into Label. iOS's TabView handles the rest.
struct MainTabView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        // Bind directly to the AppState tab so any view (e.g. HomeView's
        // "Today's session" card) can switch tabs by writing to
        // `app.activeTab` instead of having to drill a binding down.
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

    /// Build a `Label` whose icon comes from an Asset-catalog PNG
    /// rendered as a tintable template. Source PNGs are 512×512 (or
    /// 2000×2000 for train.png) which would render at 170-667pt if
    /// passed straight to the tab bar — we explicitly redraw them at
    /// 25pt × 25pt before display so they look like normal tab icons.
    @ViewBuilder
    private func customTabLabel(title: String, imageName: String) -> some View {
        if let ui = Self.tabBarIcon(named: imageName) {
            Label {
                Text(title)
            } icon: {
                Image(uiImage: ui)
            }
        } else {
            // Fallback if the asset is missing — keeps the tab usable
            // instead of rendering an empty icon slot.
            Label(title, systemImage: "circle")
        }
    }

    /// Load an Asset-catalog image, downscale it to a tab-bar-appropriate
    /// 25pt × 25pt UIImage at the device's @3x scale, and return it as a
    /// template image so the tab bar tints the silhouette with the
    /// active / inactive colour automatically.
    ///
    /// Done eagerly via `UIGraphicsImageRenderer` rather than relying on
    /// SwiftUI's `.resizable()` because SwiftUI's TabView ignores frame
    /// modifiers on the tab-item icon — the icon's natural UIImage size
    /// is what the tab bar lays out against.
    private static func tabBarIcon(named: String) -> UIImage? {
        guard let raw = UIImage(named: named) else { return nil }
        let pointSize: CGFloat = 25
        let format = UIGraphicsImageRendererFormat.default()
        // Lock the scale to the screen's so the resulting image's
        // `scale` is correct and the tab bar renders it at 25pt.
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
