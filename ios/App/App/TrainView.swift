import SwiftUI

struct TrainView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if app.activeProgramme == nil {
                    emptyState
                } else {
                    activeProgrammeContent
                }
            }
            .padding(HexTheme.padBase)
        }
        .hexBackground()
        .navigationTitle("Train")
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell")
                .font(.system(size: 44))
                .foregroundStyle(HexTheme.textMuted)
                .padding(.top, 60)
            Text("No active programme")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(HexTheme.text)
            Text("Create one to start tracking sessions.")
                .font(.system(size: 14))
                .foregroundStyle(HexTheme.textMuted)
                .multilineTextAlignment(.center)

            Button {
                // TODO: navigate to programme builder
            } label: {
                Text("Build a programme")
            }
            .buttonStyle(HexPrimaryButton())
            .padding(.top, 8)
        }
        .padding(HexTheme.padBase)
        .frame(maxWidth: .infinity)
    }

    private var activeProgrammeContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(app.activeProgramme?.name ?? "Programme")
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(HexTheme.text)
            Text("Programme view coming soon.")
                .font(.system(size: 14))
                .foregroundStyle(HexTheme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hexCard()
    }
}
