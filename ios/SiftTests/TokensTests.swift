import SwiftUI
import Testing
@testable import Sift

struct TokensTests {
    @Test func hexParsingProducesExpectedRGBA() {
        #expect(Palette.rgba(.ink) == RGBAComponents(red: 26, green: 22, blue: 18, alpha: 1))
        #expect(Palette.rgba(.bone) == RGBAComponents(red: 246, green: 242, blue: 234, alpha: 1))
        #expect(Palette.rgba(.gold) == RGBAComponents(red: 182, green: 138, blue: 78, alpha: 1))
        #expect(Palette.rgba(.green) == RGBAComponents(red: 63, green: 107, blue: 58, alpha: 1))
    }

    @Test func everySemanticColorIsDefined() {
        #expect(ColorToken.allCases.count == 11)

        for token in ColorToken.allCases {
            let components = Palette.rgba(token)
            #expect(components.alpha == 1)
            _ = token.color
        }
    }

    @Test func reducedMotionHelpersDisableMovementAnimations() {
        #expect(Motion.reduced(Motion.gentle, reduceMotion: true) == nil)
        #expect(Motion.staggered(index: 3, reduceMotion: true) == nil)
        #expect(Motion.reduced(Motion.gentle, reduceMotion: false) != nil)
        #expect(Motion.staggered(index: 3, reduceMotion: false) != nil)
    }
}
