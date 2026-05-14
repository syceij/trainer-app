import SwiftUI

/// Root tabbed interface — 5 tabs match the React BottomNav design:
/// Home / Train / Progress / Bros / PT. AccountView is reachable from the
/// chip in PTChatView's header (matches WelcomeScreen + ProfileTab routing
/// in the React app).
///
/// Icons use the outline SF Symbol variants to match the Lucide-style
/// stroke look of the React app — SwiftUI's TabView fills + tints them
/// on selection automatically via `.tint(HexTheme.accent)`.
struct MainTabView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        // Bind directly to the AppState tab so any view (e.g. HomeView's
        // "Today's session" card) can switch tabs by writing to
        // `app.activeTab` instead of having to drill a binding down.
        TabView(selection: $app.activeTab) {
            NavigationStack { HomeView() }
                .tabItem {
                    Label(app.language == "ar" ? "الرئيسية" : "Home",
                          systemImage: "house")
                }
                .tag(AppState.Tab.home)

            NavigationStack { TrainView() }
                .tabItem {
                    Label(app.language == "ar" ? "تدريب" : "Train",
                          systemImage: "dumbbell")
                }
                .tag(AppState.Tab.train)

            NavigationStack { ProgressTabView() }
                .tabItem {
                    Label(app.language == "ar" ? "تقدم" : "Progress",
                          systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(AppState.Tab.progress)

            NavigationStack { CrewView() }
                .tabItem {
                    Label(app.language == "ar" ? "أصدقاء" : "Bros",
                          systemImage: "person.3")
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
}
