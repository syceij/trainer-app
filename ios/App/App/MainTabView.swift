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
    /// rendered as a tintable template. Using a UIImage with
    /// `withRenderingMode(.alwaysTemplate)` is the cleanest way to
    /// guarantee the tab tint propagates through — wrapping a
    /// SwiftUI `Image(...).renderingMode(.template)` inside a Label
    /// works for selection states but iOS pre-17 sometimes shows the
    /// raw PNG colours on unselected tabs.
    @ViewBuilder
    private func customTabLabel(title: String, imageName: String) -> some View {
        if let ui = UIImage(named: imageName)?
            .withRenderingMode(.alwaysTemplate) {
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
}
