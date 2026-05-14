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
    @State private var selection: Tab = .home

    enum Tab: Hashable {
        case home, train, progress, bros, pt
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { HomeView() }
                .tabItem {
                    Label(app.language == "ar" ? "الرئيسية" : "Home",
                          systemImage: "house")
                }
                .tag(Tab.home)

            NavigationStack { TrainView() }
                .tabItem {
                    Label(app.language == "ar" ? "تدريب" : "Train",
                          systemImage: "dumbbell")
                }
                .tag(Tab.train)

            NavigationStack { ProgressTabView() }
                .tabItem {
                    Label(app.language == "ar" ? "تقدم" : "Progress",
                          systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(Tab.progress)

            NavigationStack { CrewView() }
                .tabItem {
                    Label(app.language == "ar" ? "أصدقاء" : "Bros",
                          systemImage: "person.3")
                }
                .tag(Tab.bros)

            NavigationStack { PTChatView() }
                .tabItem {
                    Label(app.language == "ar" ? "المدرب" : "PT",
                          systemImage: "bubble.left")
                }
                .tag(Tab.pt)
        }
        .tint(HexTheme.accent)
        .onChange(of: selection) { _ in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}
