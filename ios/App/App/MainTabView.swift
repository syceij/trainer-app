import SwiftUI

/// Root tabbed interface — mirrors src/components/BottomNav.jsx.
/// Five tabs in a floating glass pill: Home, Train, Progress, Bros, Profile.
/// PT chat is accessible from inside the Profile tab (matches React's
/// setAccountView pattern — not a top-level tab).
struct MainTabView: View {
    @EnvironmentObject var app: AppState
    @State private var selection: Tab = .home

    enum Tab: Hashable, CaseIterable {
        case home, train, progress, bros, profile
    }

    var body: some View {
        Group {
            switch selection {
            case .home:     NavigationStack { HomeView() }
            case .train:    NavigationStack { TrainView() }
            case .progress: NavigationStack { ProgressTabView() }
            case .bros:     NavigationStack { CrewView() }
            case .profile:  NavigationStack { AccountView() }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingTabBar(selection: $selection)
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 0)
        }
    }
}

/// Floating glass-pill tab bar — five buttons, active state shows
/// an accent-tinted dark glass capsule behind the icon + label.
private struct FloatingTabBar: View {
    @Binding var selection: MainTabView.Tab

    private struct Item: Identifiable {
        let id: MainTabView.Tab
        let label: String
        let icon: String         // SF Symbol (filled used when active)
        let iconActive: String   // SF Symbol for active state
    }

    private let items: [Item] = [
        .init(id: .home,     label: "Home",     icon: "house",                          iconActive: "house.fill"),
        .init(id: .train,    label: "Train",    icon: "dumbbell",                       iconActive: "dumbbell.fill"),
        .init(id: .progress, label: "Progress", icon: "chart.line.uptrend.xyaxis",      iconActive: "chart.line.uptrend.xyaxis"),
        .init(id: .bros,     label: "Bros",     icon: "person.3",                       iconActive: "person.3.fill"),
        .init(id: .profile,  label: "Profile",  icon: "person",                         iconActive: "person.fill"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let active = selection == item.id
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selection = item.id
                    }
                } label: {
                    ZStack {
                        // Active capsule pill behind icon
                        if active {
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(HexTheme.accent.opacity(0.13))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                                        .stroke(HexTheme.accent.opacity(0.28), lineWidth: 1)
                                )
                                .shadow(color: HexTheme.accent.opacity(0.14), radius: 8)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 4)
                        }
                        VStack(spacing: 3) {
                            Image(systemName: active ? item.iconActive : item.icon)
                                .font(.system(size: 21, weight: active ? .heavy : .regular))
                                .foregroundColor(active ? HexTheme.accent : Color.white.opacity(0.38))
                            Text(item.label)
                                .font(.system(size: 10, weight: active ? .heavy : .medium))
                                .foregroundColor(active ? HexTheme.accent : Color.white.opacity(0.38))
                                .kerning(0.3)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 64)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color(red: 0.086, green: 0.086, blue: 0.086).opacity(0.82))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .overlay(
                // Top specular sheen
                VStack {
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, Color.white.opacity(0.22), .clear]),
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(height: 1)
                    Spacer()
                }
                .padding(.horizontal, 36)
            )
            .shadow(color: .black.opacity(0.45), radius: 32, x: 0, y: 8)
            .shadow(color: .black.opacity(0.30), radius: 8, x: 0, y: 2)
        )
    }
}
