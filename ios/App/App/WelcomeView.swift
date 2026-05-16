import SwiftUI

/// Welcome / onboarding-choice screen — mirrors WelcomeScreen.jsx.
/// Logo image, headline with accent split, three CTAs, footer.
struct WelcomeView: View {
    @EnvironmentObject var app: AppState

    let onBuild:  () -> Void
    let onManual: () -> Void
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Logo + top-right sign out ─────────────────────────
            ZStack(alignment: .topTrailing) {
                HStack {
                    Spacer()
                    Image("HexLogo")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(HexTheme.accent)
                        .frame(height: 120)
                    Spacer()
                }

                Button {
                    Task { await app.signOut() }
                } label: {
                    Text(app.language == "ar" ? "تسجيل الخروج" : "Sign out")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(HexTheme.mute)
                }
            }
            .padding(.bottom, 48)

            // ── Headline ──────────────────────────────────────────
            (
                Text(app.language == "ar" ? "قوّتك. " : "Your strength. ")
                    .foregroundColor(HexTheme.text)
                + Text(app.language == "ar" ? "موثّقة." : "Tracked.")
                    .foregroundColor(HexTheme.accent)
            )
            .font(.system(size: 36, weight: .heavy))
            .lineSpacing(2)
            .padding(.bottom, 16)

            Text(app.language == "ar"
                 ? "ابنِ برنامجك، سجّل تمارينك، تحكّم."
                 : "Build your programme, log your sessions, dominate.")
                .font(.system(size: 16))
                .foregroundStyle(HexTheme.dim)
                .lineSpacing(4)
                .padding(.bottom, 36)

            // ── CTAs ──────────────────────────────────────────────
            VStack(spacing: 10) {
                ctaButton(
                    title:    app.language == "ar" ? "ابنِ برنامجي" : "Build my programme",
                    subtitle: app.language == "ar"
                        ? "٧ خطوات · مولّد تلقائياً"
                        : "7-step setup · auto-generated",
                    icon: "bolt.fill",
                    primary: true,
                    action: onBuild
                )
                ctaButton(
                    title:    app.language == "ar" ? "بناء يدوي" : "Build manually",
                    subtitle: app.language == "ar"
                        ? "٦ خطوات · قابل للتخصيص"
                        : "6-step wizard · fully customisable",
                    icon: "pencil.line",
                    primary: false,
                    action: onManual
                )
                ctaButton(
                    title:    app.language == "ar"
                        ? "استيراد برنامج موجود"
                        : "Import existing programme",
                    subtitle: app.language == "ar"
                        ? "الصق JSON · دعم متعدد الأسابيع"
                        : "Paste JSON · multi-week support",
                    icon: "doc.text",
                    primary: false,
                    action: onImport
                )
            }

            Spacer(minLength: 40)

            // ── Footer ────────────────────────────────────────────
            Text(app.language == "ar"
                 ? "بياناتك تتزامن عبر جميع الأجهزة"
                 : "YOUR DATA SYNCS ACROSS DEVICES")
                .font(.system(size: 11, weight: .heavy))
                .kerning(app.language == "ar" ? 0 : 1.2)
                .foregroundStyle(HexTheme.mute)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
        }
        .padding(.horizontal, 24)
        .padding(.top, 48)
        .padding(.bottom, 40)
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .hexBackground()
    }

    // MARK: - CTA button

    @ViewBuilder
    private func ctaButton(
        title: String,
        subtitle: String,
        icon: String,
        primary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(primary ? .black : HexTheme.text)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(primary
                                         ? Color.black.opacity(0.7)
                                         : HexTheme.dim)
                }
                Spacer(minLength: 12)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: primary ? .heavy : .semibold))
                    .foregroundStyle(primary ? .black : HexTheme.dim)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HexTheme.cornerCard, style: .continuous)
                    .fill(primary ? HexTheme.accent : HexTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HexTheme.cornerCard, style: .continuous)
                    .stroke(primary ? Color.clear : HexTheme.border, lineWidth: 1.5)
            )
        }
        .buttonStyle(WelcomeCTAButtonStyle())
    }
}

/// Press feedback: scale-down on tap.
private struct WelcomeCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
