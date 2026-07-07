@testable import Sift
import Testing
import UIKit

struct TypographyTests {
    @Test @MainActor func semanticFontsResolveToBundledFaces() {
        for family in SiftFontFamily.allCases {
            for face in family.requiredFaces {
                #expect(face.isRegistered, "\(family.displayName) missing \(face.rawValue)")
            }
        }
    }
}
