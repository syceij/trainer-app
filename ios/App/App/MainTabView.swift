import SwiftUI

/// 5-tab main interface. Liquid Glass appearance is applied via UITabBar
/// appearance in HEXApp init.
struct MainTabView: View {
    @EnvironmentObject var app: AppState
    @State private var selection: Tab = .home

    enum Tab: Hashable {
        case home, train, progress, crew, pt
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(Tab.home)

            NavigationStack { TrainView() }
                .tabItem { Label("Train", systemImage: "dumbbell.fill") }
                .tag(Tab.train)

            NavigationStack { ProgressTabView() }
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(Tab.progress)

            NavigationStack { CrewView() }
                .tabItem { Label("Crew", systemImage: "person.3.fill") }
                .tag(Tab.crew)

            NavigationStack { PTChatView() }
                .tabItem { Label("PT", systemImage: "message.fill") }
                .tag(Tab.pt)
        }
        .tint(HexTheme.accent)
    }
}
