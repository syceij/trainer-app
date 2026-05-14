import SwiftUI

/// Onboarding choice screen, shown the first time after sign-in if the user
/// has no active programme. Three options: build, manual, import.
struct WelcomeView: View {

    let onBuild:  () -> Void
    let onManual: () -> Void
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {

            VStack(alignment: .leading, spacing: 8) {
                Text("HEX")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(HexTheme.accent)
                Text("Your strength. Tracked.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(HexTheme.textMuted)
            }
            .padding(.top, 40)

            Spacer()

            VStack(spacing: 12) {
                option(title: "Build my programme",
                       subtitle: "Answer a few questions and we'll generate one.",
                       icon: "sparkles",
                       primary: true,
                       action: onBuild)
                option(title: "Build manually",
                       subtitle: "Pick exercises, sets, reps yourself.",
                       icon: "slider.horizontal.3",
                       primary: false,
                       action: onManual)
                option(title: "Import existing programme",
                       subtitle: "Paste a JSON / spreadsheet you already use.",
                       icon: "tray.and.arrow.down",
                       primary: false,
                       action: onImport)
            }

            Spacer()
        }
        .padding(.horizontal, HexTheme.padBase)
        .hexBackground()
    }

    @ViewBuilder
    private func option(title: String,
                        subtitle: String,
                        icon: String,
                        primary: Bool,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(primary ? Color.black.opacity(0.15) : HexTheme.accent.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(primary ? .black : HexTheme.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(primary ? .black : HexTheme.text)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(primary ? Color.black.opacity(0.65) : HexTheme.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(primary ? .black.opacity(0.5) : HexTheme.textMuted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HexTheme.cornerCard, style: .continuous)
                    .fill(primary ? HexTheme.accent : HexTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HexTheme.cornerCard, style: .continuous)
                    .stroke(primary ? Color.clear : HexTheme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
