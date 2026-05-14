import SwiftUI

/// HEX design tokens — colors, fonts, spacing.
enum HexTheme {

    // MARK: - Colors

    /// Pure black background.
    static let bg          = Color(red: 0.0,   green: 0.0,   blue: 0.0)
    /// Neon green accent. #CFFF00
    static let accent      = Color(red: 0.812, green: 1.0,   blue: 0.0)
    /// Card background. #1a1a1a
    static let card        = Color(red: 0.102, green: 0.102, blue: 0.102)
    /// Card border. #222
    static let cardBorder  = Color(red: 0.133, green: 0.133, blue: 0.133)
    /// Primary text.
    static let text        = Color.white
    /// Secondary / dim text. #555
    static let textDim     = Color(red: 0.333, green: 0.333, blue: 0.333)
    /// Tertiary muted text. white 38%
    static let textMuted   = Color.white.opacity(0.38)
    /// Error / red.
    static let danger      = Color(red: 1.0,   green: 0.298, blue: 0.298)

    // MARK: - Radius

    static let cornerSmall: CGFloat  = 8
    static let cornerCard:  CGFloat  = 14
    static let cornerLarge: CGFloat  = 20

    // MARK: - Spacing

    static let padTight: CGFloat  = 8
    static let padBase:  CGFloat  = 16
    static let padWide:  CGFloat  = 24
}

// MARK: - View modifiers

extension View {

    /// Apply the standard HEX card style: dark fill, thin border, rounded corners.
    func hexCard(padding: CGFloat = HexTheme.padBase) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: HexTheme.cornerCard, style: .continuous)
                    .fill(HexTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HexTheme.cornerCard, style: .continuous)
                    .stroke(HexTheme.cardBorder, lineWidth: 1)
            )
    }

    /// Apply the standard HEX screen background.
    func hexBackground() -> some View {
        self.background(HexTheme.bg.ignoresSafeArea())
    }
}

// MARK: - Primary button style

struct HexPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: HexTheme.cornerCard, style: .continuous)
                    .fill(HexTheme.accent.opacity(configuration.isPressed ? 0.85 : 1.0))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct HexSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(HexTheme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: HexTheme.cornerCard, style: .continuous)
                    .fill(HexTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HexTheme.cornerCard, style: .continuous)
                    .stroke(HexTheme.cardBorder, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Text field style

struct HexTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 16))
            .foregroundStyle(HexTheme.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: HexTheme.cornerCard, style: .continuous)
                    .fill(HexTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HexTheme.cornerCard, style: .continuous)
                    .stroke(HexTheme.cardBorder, lineWidth: 1)
            )
    }
}
