@testable import Sift
import SwiftUI
import Testing

struct TokensTests {
    /// WCAG relative luminance, so contrast can be asserted rather than eyeballed.
    private static func luminance(_ rgba: RGBAComponents) -> Double {
        func channel(_ value: UInt8) -> Double {
            let scaled = Double(value) / 255
            return scaled <= 0.04045 ? scaled / 12.92 : pow((scaled + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * channel(rgba.red) + 0.7152 * channel(rgba.green) + 0.0722 * channel(rgba.blue)
    }

    private static func contrast(_ lhs: RGBAComponents, _ rhs: RGBAComponents) -> Double {
        let first = luminance(lhs)
        let second = luminance(rhs)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    /// Tokens that carry text, and therefore have to clear the AA floor.
    private static let textTokens: [ColorToken] = [
        .ink, .inkSoft, .inkFaint, .accent, .positive, .negative, .warning,
    ]

    @Test func hexParsingProducesExpectedRGBA() {
        #expect(Palette.rgba(.ink) == RGBAComponents(red: 16, green: 20, blue: 24, alpha: 1))
        #expect(Palette.rgba(.ground) == RGBAComponents(red: 241, green: 244, blue: 247, alpha: 1))
        #expect(Palette.rgba(.accent) == RGBAComponents(red: 11, green: 79, blue: 216, alpha: 1))
        #expect(Palette.rgba(.positive) == RGBAComponents(red: 18, green: 101, blue: 59, alpha: 1))
    }

    @Test func everySemanticColorIsDefined() {
        #expect(ColorToken.allCases.count == 12)

        for token in ColorToken.allCases {
            #expect(token.components.alpha == 1)
            #expect(token.darkComponents.alpha == 1)
            _ = token.color
        }
    }

    /// The regression this palette was rebuilt to prevent.
    ///
    /// The previous set had three tokens below the AA floor — `inkFaint` at 2.74:1 was the
    /// most-used colour in the app, and `gold` at 2.79:1 was the chart fill. Nobody noticed
    /// because nothing measured it. Now something does.
    @Test func everyTextTokenClearsWCAGAAInLightAppearance() {
        for token in Self.textTokens {
            for surface in [ColorToken.ground, .surface] {
                let ratio = Self.contrast(token.components, surface.components)
                #expect(
                    ratio >= 4.5,
                    "\(token.rawValue) on \(surface.rawValue) is \(ratio), below the 4.5:1 AA floor"
                )
            }
        }
    }

    @Test func everyTextTokenClearsWCAGAAInDarkAppearance() {
        for token in Self.textTokens {
            for surface in [ColorToken.ground, .surface] {
                let ratio = Self.contrast(token.darkComponents, surface.darkComponents)
                #expect(
                    ratio >= 4.5,
                    "\(token.rawValue) on dark \(surface.rawValue) is \(ratio), below the 4.5:1 AA floor"
                )
            }
        }
    }

    /// A surface has to be able to read as a surface by fill alone.
    ///
    /// `card` against `bone` used to measure 1.10:1, which is why every card needed a fill
    /// *and* a border *and* a shadow to exist. Once the value step does the work, the
    /// scaffolding becomes optional — and that is what stops the app looking stamped.
    @Test func surfacesSeparateFromTheGroundByValue() {
        for appearance in ["light", "dark"] {
            let ground = appearance == "light" ? ColorToken.ground.components : ColorToken.ground.darkComponents
            let surface = appearance == "light" ? ColorToken.surface.components : ColorToken.surface.darkComponents
            let ratio = Self.contrast(ground, surface)
            #expect(ratio > 1.05, "surface and ground are \(ratio) apart in \(appearance) — too flat to read")
        }
    }

    /// Light and dark must be genuinely different values, not the same hex twice. A token
    /// that forgot its dark variant is invisible in dark mode and easy to miss by eye.
    @Test func everyTokenDefinesADistinctDarkValue() {
        for token in ColorToken.allCases {
            #expect(token.components != token.darkComponents, "\(token.rawValue) has no dark variant")
        }
    }

    @Test func reducedMotionHelpersDisableMovementAnimations() {
        #expect(Motion.reduced(Motion.gentle, reduceMotion: true) == nil)
        #expect(Motion.staggered(index: 3, reduceMotion: true) == nil)
        #expect(Motion.reduced(Motion.gentle, reduceMotion: false) != nil)
        #expect(Motion.staggered(index: 3, reduceMotion: false) != nil)
    }
}
