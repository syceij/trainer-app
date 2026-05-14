import SwiftUI

/// Root tabbed interface — 5 tabs match src/components/BottomNav.jsx
/// (Home / Train / Progress / Bros / Profile). Standard SwiftUI TabView
/// chrome — the global UITabBarAppearance set in HEXApp tints it to the
/// HEX palette. PT chat is accessible from inside Profile, not as a
/// top-level tab (matches the React design).
struct MainTabView: View {
    @EnvironmentObject var app: AppState
    @State private var selection: Tab = .home

    enum Tab: Hashable {
        case home, train, progress, bros, profile
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { HomeView() }
                .tabItem {
                    Label(app.language == "ar" ? "الرئيسية" : "Home",
                          systemImage: "house.fill")
                }
                .tag(Tab.home)

            NavigationStack { TrainView() }
                .tabItem {
                    Label(app.language == "ar" ? "تدريب" : "Train",
                          systemImage: "dumbbell.fill")
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
                          systemImage: "person.3.fill")
                }
                .tag(Tab.bros)

            NavigationStack { AccountView() }
                .tabItem {
                    Label(app.language == "ar" ? "الحساب" : "Profile",
                          systemImage: "person.fill")
                }
                .tag(Tab.profile)
        }
        .tint(HexTheme.accent)
        .onChange(of: selection) { _ in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}
