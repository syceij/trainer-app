import SwiftUI
import Foundation

/// User-selectable accent colour. Stored as a raw `String` (the case
/// name) in shared App Group UserDefaults so both the main app AND the
/// WorkoutWidget extension read the same source of truth.
///
/// Adding a new choice = add a case + entry in `palette` below. Both
/// `HexTheme.accent` and `HexTheme.accentDark` derive from this enum,
/// so picking a new option in Settings recolours every accent surface
/// (set-button fills, weight pills, progress bars, "Start LA" button,
/// confetti highlight, primary-button background, tab-bar tint, etc.)
/// without touching individual call sites.
enum AccentChoice: String, CaseIterable, Identifiable {
    case lime
    case cream
    case electric
    case magenta
    case orange

    var id: String { rawValue }

    /// Hex code for the "main" (full-saturation) accent surface.
    /// Lime is the historical HEX brand colour and remains the default.
    var hex: String {
        switch self {
        case .lime:     return "#B8FF00"
        case .cream:    return "#E7E5E0"
        case .electric: return "#00E5FF"
        case .magenta:  return "#FF2D9C"
        case .orange:   return "#FF8C00"
        }
    }
    /// Hex code for the darker pressed-state variant used by
    /// `HexPrimaryButton` and `accentDark` consumers.
    var hexDark: String {
        switch self {
        case .lime:     return "#8ACC00"
        case .cream:    return "#BDB9B0"
        case .electric: return "#00B8CC"
        case .magenta:  return "#CC247D"
        case .orange:   return "#CC7000"
        }
    }
    /// Human-readable label (English) for the picker swatch tooltip.
    var label: String {
        switch self {
        case .lime:     return "Lime"
        case .cream:    return "Cream"
        case .electric: return "Electric"
        case .magenta:  return "Magenta"
        case .orange:   return "Orange"
        }
    }
}

extension Color {
    /// Decode a `#RRGGBB` (or `RRGGBB`) hex string into a SwiftUI Color.
    /// Falls back to the lime accent if parsing fails so we never end
    /// up with a transparent or invisible surface.
    init(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let int = UInt32(s, radix: 16) else {
            self = Color(red: 0.722, green: 1.0, blue: 0.0)
            return
        }
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >>  8) & 0xFF) / 255.0
        let b = Double( int        & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }

    /// Linearly blend this colour toward white. `amount` is 0…1 where
    /// 0 returns the original colour and 1 returns pure white. Used to
    /// build the bright highlight stops in glossy / metal / neon
    /// material gradients without needing a hardcoded HSB pipeline.
    func blendWhite(_ amount: Double) -> Color {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let t = CGFloat(min(max(amount, 0), 1))
        return Color(
            red:   Double(r + (1 - r) * t),
            green: Double(g + (1 - g) * t),
            blue:  Double(b + (1 - b) * t)
        )
    }
    /// Linearly blend this colour toward black. Same shape as
    /// `blendWhite` — `0` keeps the original, `1` returns pure black.
    func blendBlack(_ amount: Double) -> Color {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let t = CGFloat(1 - min(max(amount, 0), 1))
        return Color(
            red:   Double(r * t),
            green: Double(g * t),
            blue:  Double(b * t)
        )
    }
}

/// Surface finish applied on top of the accent colour. Lets the user
/// pick how the lime/cream/etc. should LOOK in addition to which hue
/// it is. Stored as `rawValue` in App Group UserDefaults under
/// `accent_material_v1`.
///
/// All four options reuse the active `AccentChoice` as the base colour
/// — material only changes the gradient stops, not the hue. That keeps
/// the colour-swatch picker decoupled from the material picker.
enum AccentMaterial: String, CaseIterable, Identifiable {
    /// Flat solid colour. The historical look — every accent surface
    /// was a single uniform fill until this picker shipped.
    case matte
    /// Vertical highlight → base → soft shadow gradient. Reads like
    /// wet plastic or a lacquered button face.
    case glossy
    /// Multi-stop diagonal gradient with alternating light/dark bands.
    /// Reads like brushed metal — small angle keeps the streaks
    /// visible without making the colour identity disappear.
    case metal
    /// Radial gradient with a bright "hot spot" at the centre. Reads
    /// like a glowing light source (matches the HEX gym/energy
    /// aesthetic — was the natural "you decide" pick).
    case neon

    var id: String { rawValue }

    /// Human-readable label rendered under the picker swatch.
    var label: String {
        switch self {
        case .matte:  return "Matte"
        case .glossy: return "Glossy"
        case .metal:  return "Metal"
        case .neon:   return "Neon"
        }
    }
}

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

    /// Shared App Group suite the widget extension also reads.
    private static let appGroup = "group.com.hexapp.training"
    /// UserDefaults key for the user's chosen `AccentChoice.rawValue`.
    static let accentChoiceKey = "accent_choice_v1"
    /// UserDefaults key for the user's chosen `AccentMaterial.rawValue`.
    static let accentMaterialKey = "accent_material_v1"

    /// Resolve the currently-active `AccentChoice` from App Group
    /// UserDefaults (falls back to standard UserDefaults if the App
    /// Group isn't reachable, e.g. simulator without the entitlement).
    static var currentAccentChoice: AccentChoice {
        let raw =
            UserDefaults(suiteName: appGroup)?.string(forKey: accentChoiceKey)
            ?? UserDefaults.standard.string(forKey: accentChoiceKey)
            ?? AccentChoice.lime.rawValue
        return AccentChoice(rawValue: raw) ?? .lime
    }

    /// Resolve the currently-active `AccentMaterial` from App Group
    /// UserDefaults. Defaults to `.matte` (the historical flat look)
    /// when nothing's been picked yet.
    static var currentAccentMaterial: AccentMaterial {
        let raw =
            UserDefaults(suiteName: appGroup)?.string(forKey: accentMaterialKey)
            ?? UserDefaults.standard.string(forKey: accentMaterialKey)
            ?? AccentMaterial.matte.rawValue
        return AccentMaterial(rawValue: raw) ?? .matte
    }

    /// Current accent color — the brand surface seen on set-button
    /// fills, progress bars, weight pills, etc. Computed on every read
    /// from App Group UserDefaults so flipping the user's choice
    /// immediately recolours every consumer once the surrounding view
    /// re-renders (AppState's `accentChoice` @Published drives that).
    static var accent: Color { Color(hexString: currentAccentChoice.hex) }
    /// Pressed-state darker variant — same source as `accent`.
    static var accentDark: Color { Color(hexString: currentAccentChoice.hexDark) }

    /// ShapeStyle for FILLING shapes with the accent. Apply at
    /// `.fill(HexTheme.accentFill)` instead of `.fill(HexTheme.accent)`
    /// for surfaces that should show the user's material choice
    /// (glossy / metal / neon). Plain `HexTheme.accent` (the Color)
    /// remains for foreground/icon/text use where material doesn't
    /// apply, and for `.opacity()` chains that need a flat hue.
    ///
    /// Returns `AnyShapeStyle` so the call site can substitute either
    /// a `Color` (matte) or a `Gradient` (glossy/metal/neon) without
    /// the SwiftUI type system caring which.
    static var accentFill: AnyShapeStyle {
        let base = accent
        switch currentAccentMaterial {
        case .matte:
            return AnyShapeStyle(base)
        case .glossy:
            // Bright highlight at the top, base in the middle, soft
            // shadow at the bottom — reads like a glossy lacquered
            // button face.
            return AnyShapeStyle(LinearGradient(
                colors: [
                    base.blendWhite(0.40),
                    base,
                    base.blendBlack(0.15),
                ],
                startPoint: .top,
                endPoint: .bottom
            ))
        case .metal:
            // Alternating light/dark bands along a slight diagonal —
            // brushed-metal look. The angle keeps the streaks visible
            // without overwhelming the base hue identity.
            return AnyShapeStyle(LinearGradient(
                colors: [
                    base.blendBlack(0.18),
                    base.blendWhite(0.30),
                    base.blendBlack(0.25),
                    base.blendWhite(0.15),
                    base.blendBlack(0.10),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case .neon:
            // Radial hot-spot in the middle fading out to a slightly
            // darker rim — simulates an internal light source without
            // needing an outer shadow (which `.fill` can't emit).
            return AnyShapeStyle(RadialGradient(
                colors: [
                    base.blendWhite(0.45),
                    base,
                    base.blendBlack(0.10),
                ],
                center: .center,
                startRadius: 0,
                endRadius: 50
            ))
        }
    }

    /// Success green (#ADFF2F).
    static let success     = Color(red: 0.678, green: 1.0, blue: 0.184)
    /// Error red (#E24B4A).
    static let danger      = Color(red: 0.886, green: 0.294, blue: 0.290)

    // MARK: - Fonts

    /// PostScript name of the custom Arabic typeface (ThmanyahSans-Bold)
    /// shipped in `ios/App/App/Fonts/`. Registered via the `UIAppFonts`
    /// array in Info.plist so it's available globally without per-launch
    /// CTFontManager registration.
    static let thmanyahBold = "ThmanyahSans-Bold"

    /// Resolve the right text font for the given language. Arabic uses
    /// `ThmanyahSans-Bold` at the requested size (only Bold ships, so
    /// every Arabic weight collapses to Bold — matches the React app's
    /// behaviour where the woff2 is single-weight). English keeps SF
    /// Pro at the caller's requested weight.
    ///
    /// Call sites can either:
    ///   • Explicitly pass `ar:` from the view's `app.language` flag.
    ///   • Inherit from an environment override applied at the root
    ///     (see `.environment(\.font, ...)` in ContentView).
    static func font(size: CGFloat, weight: Font.Weight, ar: Bool) -> Font {
        if ar {
            return .custom(thmanyahBold, size: size)
        }
        return .system(size: size, weight: weight)
    }

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
