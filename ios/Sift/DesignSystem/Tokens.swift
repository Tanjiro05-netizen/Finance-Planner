import SwiftUI
import UIKit

struct RGBAComponents: Equatable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: Double
}

/// The palette, as semantic roles rather than as colour names.
///
/// The previous set was named for its material — `bone`, `sand`, `clay`, `gold` — which is
/// how `clay` ended up being both "you overspent" and a decorative tile fill. A name that
/// describes a colour invites reuse by appearance; a name that describes a job does not.
///
/// Every token carries a light and a dark value, resolved at draw time by the trait
/// collection. Apple's HIG asks for both even from an app that ships in one appearance,
/// because Liquid Glass adapts against them. The dark values are *chosen*, not inverted:
/// the ground goes to a near-black with the same blue bias, and the chromatic tokens gain
/// lightness and lose chroma so they stay legible without glowing.
///
/// Contrast was measured, not eyeballed. Every token used for text clears WCAG AA (4.5:1)
/// against both `ground` and `surface`, in both appearances. The old palette had three
/// tokens below that floor, including `inkFaint`, which was the most-used colour in the app.
enum ColorToken: String, Codable, CaseIterable {
    /// Primary text.
    case ink
    /// Secondary text — supporting detail that should still read comfortably.
    case inkSoft
    /// Tertiary text — captions and labels. Still AA, unlike its predecessor.
    case inkFaint
    /// The app background. Grey, so that white rows sit *above* it.
    case ground
    /// Rows, list sections, and anything that should read as raised off the ground.
    case surface
    /// Recessed fills: input wells, unselected segments, incoming message bubbles.
    case surfaceSunken
    /// Hairlines between rows. Never a border around a card.
    case separator
    /// The single interactive accent. Actions, active state, links. Never decoration.
    case accent
    /// A tint of the accent for selected rows and quiet emphasis.
    case accentSoft
    /// Money in, under budget, on track. Semantic only.
    case positive
    /// Money out, over budget, destructive. Semantic only.
    case negative
    /// Attention that is not yet a failure. Semantic only.
    case warning

    /// Light appearance.
    fileprivate var light: String {
        switch self {
        case .ink: "#101418"
        case .inkSoft: "#49545C"
        case .inkFaint: "#616D75"
        case .ground: "#F1F4F7"
        case .surface: "#FFFFFF"
        case .surfaceSunken: "#E3E9ED"
        case .separator: "#D9E0E5"
        case .accent: "#0B4FD8"
        case .accentSoft: "#E6EDFC"
        case .positive: "#12653B"
        case .negative: "#B02A20"
        case .warning: "#7E5300"
        }
    }

    /// Dark appearance. Chosen against a warm-free near-black, not derived by inversion.
    fileprivate var dark: String {
        switch self {
        case .ink: "#E7ECEF"
        case .inkSoft: "#A6B2BA"
        case .inkFaint: "#8D99A1"
        case .ground: "#0C1013"
        case .surface: "#161B1F"
        case .surfaceSunken: "#1E252A"
        case .separator: "#2A333A"
        case .accent: "#6C9BFF"
        case .accentSoft: "#152541"
        case .positive: "#5BC98B"
        case .negative: "#F0857A"
        case .warning: "#DFB160"
        }
    }

    var color: Color {
        // The two values are parsed up front so the provider closure captures plain value
        // types. It is called on every trait change, and should not be doing string work.
        let lightComponents = parseHex(light)
        let darkComponents = parseHex(dark)

        return Color(uiColor: UIColor { traits in
            UIColor(components: traits.userInterfaceStyle == .dark ? darkComponents : lightComponents)
        })
    }

    /// The light value, for tests and for anywhere a static value is genuinely needed.
    var components: RGBAComponents {
        parseHex(light)
    }

    /// The dark value, so the pair can be asserted on together.
    var darkComponents: RGBAComponents {
        parseHex(dark)
    }
}

enum Palette {
    static var ink: Color {
        ColorToken.ink.color
    }

    static var inkSoft: Color {
        ColorToken.inkSoft.color
    }

    static var inkFaint: Color {
        ColorToken.inkFaint.color
    }

    static var ground: Color {
        ColorToken.ground.color
    }

    static var surface: Color {
        ColorToken.surface.color
    }

    static var surfaceSunken: Color {
        ColorToken.surfaceSunken.color
    }

    static var separator: Color {
        ColorToken.separator.color
    }

    static var accent: Color {
        ColorToken.accent.color
    }

    static var accentSoft: Color {
        ColorToken.accentSoft.color
    }

    static var positive: Color {
        ColorToken.positive.color
    }

    static var negative: Color {
        ColorToken.negative.color
    }

    static var warning: Color {
        ColorToken.warning.color
    }

    static func rgba(_ token: ColorToken) -> RGBAComponents {
        token.components
    }
}

/// Three steps, not nine.
///
/// The previous ladder hand-tuned nine values — card 26, row 17, control 16, tile 11,
/// pill 20, tabBar 24, actionBar 24, segmented 15, sheet 38 — which is per-component
/// improvisation rather than a system. The names are kept so call sites do not churn, but
/// they now resolve to three real values, which is what makes nesting look deliberate.
enum Radius {
    /// Tiles, badges, small controls.
    static let tight: CGFloat = 8
    /// Rows, grouped sections, containers.
    static let standard: CGFloat = 12
    /// Sheets and other large presented surfaces.
    static let large: CGFloat = 28

    static let card: CGFloat = standard
    static let row: CGFloat = standard
    static let control: CGFloat = standard
    static let tile: CGFloat = tight
    static let segmented: CGFloat = tight
    static let tabBar: CGFloat = standard
    static let actionBar: CGFloat = standard
    static let sheet: CGFloat = large
    /// Genuinely a capsule; kept large so `Capsule()`-like shapes stay round.
    static let pill: CGFloat = 999
}

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    /// Matches the inset iOS uses for grouped list content.
    static let screenHorizontal: CGFloat = 16
}

/// Elevation is now carried by value and position, not by shadow.
///
/// When `surface` sits above `ground` by a real lightness step, a row does not need a
/// border *and* a shadow to read as a surface — which is what the old palette forced,
/// because `card` and `bone` were 1.10:1 apart and fill alone could not do the work.
/// What remains is one genuinely floating shadow for presented chrome.
enum Elevation {
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat
    }

    /// Flat. Grouped content sits on the ground; it does not hover above it.
    static var card: Shadow {
        Shadow(color: .clear, radius: 0, offsetX: 0, offsetY: 0)
    }

    static var row: Shadow {
        Shadow(color: .clear, radius: 0, offsetX: 0, offsetY: 0)
    }

    /// Floating chrome only — the one place a shadow still says something true.
    static var control: Shadow {
        Shadow(color: Color.black.opacity(0.18), radius: 18, offsetX: 0, offsetY: 6)
    }
}

private extension UIColor {
    convenience init(components: RGBAComponents) {
        self.init(
            red: CGFloat(components.red) / 255.0,
            green: CGFloat(components.green) / 255.0,
            blue: CGFloat(components.blue) / 255.0,
            alpha: CGFloat(components.alpha)
        )
    }
}

private func parseHex(_ hex: String) -> RGBAComponents {
    let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    var value: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&value)

    switch cleaned.count {
    case 6:
        return RGBAComponents(
            red: UInt8((value & 0xFF0000) >> 16),
            green: UInt8((value & 0x00FF00) >> 8),
            blue: UInt8(value & 0x0000FF),
            alpha: 1
        )
    case 8:
        return RGBAComponents(
            red: UInt8((value & 0xFF00_0000) >> 24),
            green: UInt8((value & 0x00FF_0000) >> 16),
            blue: UInt8((value & 0x0000_FF00) >> 8),
            alpha: Double(value & 0x0000_00FF) / 255.0
        )
    default:
        assertionFailure("Invalid color token")
        return RGBAComponents(red: 0, green: 0, blue: 0, alpha: 1)
    }
}
