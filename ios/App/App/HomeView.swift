import SwiftUI

struct HomeView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Greeting
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.system(size: 15))
                        .foregroundStyle(HexTheme.textMuted)
                    Text(displayName)
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(HexTheme.text)
                }

                // Today's session card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("TODAY")
                            .font(.system(size: 11, weight: .semibold))
                            .kerning(1.4)
                            .foregroundStyle(Color.black.opacity(0.55))
                        Spacer()
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.black)
                    }
                    Text(app.currentSession?.name ?? "Rest day")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(.black)
                    if let s = app.currentSession {
                        Text("Week \(s.weekNumber ?? 1) · \(s.data?.exercises.count ?? 0) exercises")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.6))
                    } else {
                        Text("Nothing scheduled.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.6))
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: HexTheme.cornerCard, style: .continuous)
                        .fill(HexTheme.accent)
                )

                // Quick stats placeholder
                HStack(spacing: 12) {
                    statCard(value: "—", label: "This week")
                    statCard(value: "—", label: "Total sessions")
                }

                Spacer(minLength: 0)
            }
            .padding(HexTheme.padBase)
        }
        .hexBackground()
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: AccountView()) {
                    Image(systemName: "person.crop.circle")
                        .foregroundStyle(HexTheme.text)
                }
            }
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(HexTheme.text)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(HexTheme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hexCard()
    }

    private var displayName: String {
        app.currentProfile?.name ?? app.currentProfile?.username ?? "Athlete"
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:       return "Hello"
        }
    }
}
