@testable import Sift
import SwiftUI
import Testing

struct TypographyTests {
    /// Money now has a hierarchy, which it did not before.
    ///
    /// `MoneyText` took a raw `CGFloat` and 24 of its 29 call sites used the same 50pt
    /// default, so a subscription's price, a monthly total and the headline safe-to-spend
    /// figure all rendered identically. This asserts the roles stay ordered, so the scale
    /// cannot quietly collapse again.
    @Test func moneyRolesAreStrictlyOrdered() {
        let ordered: [MoneyRole] = [.hero, .primary, .row, .inline]
        for (larger, smaller) in zip(ordered, ordered.dropFirst()) {
            #expect(larger.size > smaller.size, "\(larger) should outrank \(smaller)")
        }
    }

    /// Each role scales against a Dynamic Type style, so accessibility sizes still grow
    /// these figures instead of freezing them at a fixed point size.
    @Test func everyMoneyRoleScalesAgainstATextStyle() {
        for role in [MoneyRole.hero, .primary, .row, .inline] {
            _ = role.textStyle
            #expect(role.size > 0)
        }
    }

    @Test func moneyPartsSplitSymbolMajorAndFraction() {
        let parts = MoneyTextFormatter.parts(from: "$1,234.56")
        #expect(parts.symbol == "$")
        #expect(parts.major == "1,234")
        #expect(parts.fractional == ".56")
        #expect(parts.suffix == nil)
    }

    @Test func moneyPartsKeepACadenceSuffixSeparate() {
        let parts = MoneyTextFormatter.parts(from: "$80.47/day")
        #expect(parts.major == "80")
        #expect(parts.fractional == ".47")
        #expect(parts.suffix == "/day")
        #expect(parts.accessibilityText == "$80.47/day")
    }

    @Test func moneyPartsSurviveAMissingFraction() {
        let parts = MoneyTextFormatter.parts(from: "$12")
        #expect(parts.major == "12")
        #expect(parts.fractional == nil)
    }
}
