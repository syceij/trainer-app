import SwiftUI

struct AccountView: View {
    @EnvironmentObject var app: AppState

    @State private var liveActivitiesEnabled = LiveActivityService.shared.isEnabled
    @State private var showSignOutConfirm   = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Circle()
                        .fill(HexTheme.card)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Text(initial)
                                .font(.system(size: 22, weight: .heavy))
                                .foregroundStyle(HexTheme.accent)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.currentProfile?.name ?? "Athlete")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(HexTheme.text)
                        if let u = app.currentProfile?.username {
                            Text("@\(u)")
                                .font(.system(size: 13))
                                .foregroundStyle(HexTheme.textMuted)
                        }
                    }
                    Spacer()
                }
                .listRowBackground(HexTheme.card)
            }

            Section("Preferences") {
                HStack {
                    Text("Language")
                    Spacer()
                    Picker("", selection: $app.language) {
                        Text("EN").tag("en")
                        Text("AR").tag("ar")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 110)
                }
                .listRowBackground(HexTheme.card)

                Toggle(isOn: $liveActivitiesEnabled) {
                    Text("Live Activities")
                }
                .tint(HexTheme.accent)
                .listRowBackground(HexTheme.card)
            }

            Section {
                Button(role: .destructive) {
                    showSignOutConfirm = true
                } label: {
                    Text("Sign out")
                }
                .listRowBackground(HexTheme.card)
            }
        }
        .scrollContentBackground(.hidden)
        .background(HexTheme.bg)
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Sign out?",
                            isPresented: $showSignOutConfirm,
                            titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task { await app.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var initial: String {
        let s = app.currentProfile?.name ?? app.currentProfile?.username ?? "?"
        return String(s.prefix(1)).uppercased()
    }
}
