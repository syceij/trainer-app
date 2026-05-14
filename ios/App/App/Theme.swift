import SwiftUI

/// HEX design tokens — mirrors src/tokens.js exactly.
enum HexTheme {

    // MARK: - Colors (from src/tokens.js)

    /// #0A0A0A — primary background.
    static let bg          = Color(red: 0.039, green: 0.039, blue: 0.039)
    /// #141414 — card surface.
    static let surface     = Color(red: 0.078, green: 0.078, blue: 0.078)
    /// #1E1E1E — input / secondary surface.
    static let surface2    = Color(red: 0.118, green: 0.118, blue: 0.118)
    /// #252525 — borders.
    static let border      = Color(red: 0.145, green: 0.145, blue: 0.145)
    /// #F5F5F5 — primary text.
    static let text        = Color(red: 0.961, green: 0.961, blue: 0.961)
    /// #888888 — dim text.
    static let dim         = Color(red: 0.533, green: 0.533, blue: 0.533)
    /// #555555 — muted text.
    static let mute        = Color(red: 0.333, green: 0.333, blue: 0.333)
    /// #B8FF00 — neon-lime accent.
    static let accent      = Color(red: 0.722, green: 1.0, blue: 0.0)
    /// #8ACC00 — accent dark (pressed).
    static let accentDark  = Color(red: 0.541, green: 0.8, blue: 0.0)

    /// Success green (#ADFF2F).
    static let success     = Color(red: 0.678, green: 1.0, blue: 0.184)
    /// Error red (#E24B4A).
    static let danger      = Color(red: 0.886, green: 0.294, blue: 0.290)

    // MARK: - Aliases (legacy names used elsewhere in the codebase)

    static let card        = surface
    static let cardBorder  = border
    static let textMuted   = dim
    static let textDim     = mute

    // MARK: - Radius

    static let cornerSmall: CGFloat  = 8
    static let cornerInput: CGFloat  = 12
    static let cornerCard:  CGFloat  = 14
    static let cornerLarge: CGFloat  = 20

    // MARK: - Spacing

    static let padTight: CGFloat  = 8
    static let padBase:  CGFloat  = 16
    static let padWide:  CGFloat  = 24
}

// MARK: - View modifiers

extension View {

    /// Standard card style: dark fill, 1px border, rounded corners.
    func hexCard(padding: CGFloat = HexTheme.padBase) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: HexTheme.cornerCard, style: .continuous)
                    .fill(HexTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HexTheme.cornerCard, style: .continuous)
                    .stroke(HexTheme.border, lineWidth: 1)
            )
    }

    /// Plain HEX background (solid #0A0A0A).
    func hexBackground() -> some View {
        self.background(HexTheme.bg.ignoresSafeArea())
    }

    /// Auth-screen background — solid bg + a soft accent radial glow top-left,
    /// matching `radial-gradient(ellipse 60% 45% at top left, rgba(200,255,0,0.10)…)`
    /// from AuthScreen.jsx.
    func hexAuthBackground() -> some View {
        self.background(
            ZStack {
                HexTheme.bg
                GeometryReader { geo in
                    RadialGradient(
                        gradient: Gradient(colors: [
                            HexTheme.accent.opacity(0.10),
                            Color.clear
                        ]),
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: max(geo.size.width, geo.size.height) * 0.7
                    )
                }
            }
            .ignoresSafeArea()
        )
    }
}

// MARK: - Primary button (#B8FF00 fill, black text, 14pt radius)

struct HexPrimaryButton: ButtonStyle {
    var disabled: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .heavy))
            .foregroundStyle(disabled ? HexTheme.mute : .black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: HexTheme.cornerCard, style: .continuous)
                    .fill(disabled ? HexTheme.surface2
                                   : (configuration.isPressed ? HexTheme.accentDark : HexTheme.accent))
            )
            .scaleEffect(configuration.isPressed && !disabled ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Secondary button (dark fill, 1.5px border)

struct HexSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(HexTheme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: HexTheme.cornerCard, style: .continuous)
                    .fill(HexTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HexTheme.cornerCard, style: .continuous)
                    .stroke(HexTheme.border, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Form text field (matches React's <Field>)

struct HexTextFieldStyle: TextFieldStyle {
    var focused: Bool = false
    var hasError: Bool = false
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 16))
            .foregroundStyle(HexTheme.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: HexTheme.cornerInput, style: .continuous)
                    .fill(HexTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HexTheme.cornerInput, style: .continuous)
                    .stroke(borderColor, lineWidth: 1.5)
            )
    }
    private var borderColor: Color {
        if hasError { return HexTheme.danger }
        if focused  { return HexTheme.accent }
        return HexTheme.border
    }
}

// MARK: - Error banner (translucent red, used in auth views)

struct HexErrorBanner: View {
    let msg: String
    var body: some View {
        Text(msg)
            .font(.system(size: 13))
            .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.42))
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.31, blue: 0.31).opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(red: 1.0, green: 0.31, blue: 0.31).opacity(0.30), lineWidth: 1)
            )
    }
}

// MARK: - Form label (uppercase, dim, letter-spaced)

struct HexFieldLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(HexTheme.dim)
            .kerning(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
