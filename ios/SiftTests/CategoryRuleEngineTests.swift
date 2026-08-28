@testable import Sift
import Testing

struct CategoryRuleEngineTests {
    private func rule(
        id: String = "rule-1",
        kind: CategoryRuleKind = .merchantContains,
        pattern: String,
        categoryID: String = SeedData.ID.dining,
        sortIndex: Int = 0,
        isEnabled: Bool = true
    ) -> CategoryRule {
        CategoryRule(
            id: id,
            userID: SeedData.defaultUserID,
            kind: kind,
            pattern: pattern,
            categoryID: categoryID,
            sortIndex: sortIndex,
            isEnabled: isEnabled
        )
    }

    // MARK: - Matching

    @Test func merchantMatchIsCaseInsensitive() {
        let subject = rule(pattern: "blue bottle")
        #expect(CategoryRuleEngine.matches(subject, merchantName: "BLUE BOTTLE COFFEE", merchantCategoryCode: nil))
    }

    /// Someone typing "cafe" should still catch "CAFÉ MONDRIAN" -- no card descriptor is
    /// worth losing a rule over an accent.
    @Test func merchantMatchIsDiacriticInsensitive() {
        let subject = rule(pattern: "cafe")
        #expect(CategoryRuleEngine.matches(subject, merchantName: "CAFÉ MONDRIAN", merchantCategoryCode: nil))
    }

    @Test func merchantMatchIsSubstringNotEquality() {
        let subject = rule(pattern: "GROCERY")
        #expect(CategoryRuleEngine.matches(subject, merchantName: "CORNER GROCERY #4471", merchantCategoryCode: nil))
        #expect(CategoryRuleEngine.matches(subject, merchantName: "SAIGON KITCHEN", merchantCategoryCode: nil) == false)
    }

    @Test func categoryCodeMatchesExactly() {
        let subject = rule(kind: .merchantCategoryCode, pattern: "5411")
        #expect(CategoryRuleEngine.matches(subject, merchantName: "anything", merchantCategoryCode: 5411))
        #expect(CategoryRuleEngine.matches(subject, merchantName: "anything", merchantCategoryCode: 5412) == false)
        #expect(CategoryRuleEngine.matches(subject, merchantName: "anything", merchantCategoryCode: nil) == false)
    }

    /// The point of the code kind: it fires on descriptors no keyword could ever catch.
    @Test func categoryCodeMatchesUnreadableDescriptors() {
        let subject = rule(kind: .merchantCategoryCode, pattern: "5812")
        #expect(CategoryRuleEngine.matches(subject, merchantName: "SQ *4471 ABC", merchantCategoryCode: 5812))
    }

    // MARK: - Malformed rules

    /// The dangerous direction. An empty merchant pattern would otherwise substring-match
    /// every transaction in the ledger and recategorise the lot.
    @Test func anEmptyMerchantPatternMatchesNothing() {
        #expect(rule(pattern: "").matcher == nil)
        #expect(CategoryRuleEngine.matches(rule(pattern: ""), merchantName: "anything", merchantCategoryCode: nil) == false)
        #expect(CategoryRuleEngine.matches(rule(pattern: "   "), merchantName: "anything", merchantCategoryCode: nil) == false)
    }

    @Test func aNonNumericCodePatternMatchesNothing() {
        let subject = rule(kind: .merchantCategoryCode, pattern: "groceries")
        #expect(subject.matcher == nil)
        #expect(CategoryRuleEngine.matches(subject, merchantName: "anything", merchantCategoryCode: 5411) == false)
    }

    @Test func anOutOfRangeCodePatternMatchesNothing() {
        // Int16 tops out at 32767; a pattern past it must not trap on conversion.
        let subject = rule(kind: .merchantCategoryCode, pattern: "99999")
        #expect(subject.matcher == nil)
        #expect(CategoryRuleEngine.matches(subject, merchantName: "anything", merchantCategoryCode: 5411) == false)
    }

    @Test func patternsAreTrimmedBeforeUse() {
        #expect(rule(pattern: "  grocery  ").matcher == .merchantContains("grocery"))
        #expect(rule(kind: .merchantCategoryCode, pattern: " 5411 ").matcher == .merchantCategoryCode(5411))
    }

    // MARK: - Precedence

    @Test func lowestOrderWinsWhenSeveralMatch() {
        let rules = [
            rule(id: "second", pattern: "CORNER", categoryID: SeedData.ID.dining, sortIndex: 1),
            rule(id: "first", pattern: "GROCERY", categoryID: SeedData.ID.groceries, sortIndex: 0),
        ]

        let winner = CategoryRuleEngine.firstMatch(
            rules: rules, merchantName: "CORNER GROCERY", merchantCategoryCode: nil
        )

        #expect(winner?.id == "first")
    }

    @Test func disabledRulesAreSkippedEvenWhenTheyWouldWin() {
        let rules = [
            rule(id: "disabled", pattern: "GROCERY", sortIndex: 0, isEnabled: false),
            rule(id: "enabled", pattern: "CORNER", sortIndex: 1),
        ]

        let winner = CategoryRuleEngine.firstMatch(
            rules: rules, merchantName: "CORNER GROCERY", merchantCategoryCode: nil
        )

        #expect(winner?.id == "enabled")
    }

    @Test func aMalformedRuleDoesNotBlockALaterValidOne() {
        let rules = [
            rule(id: "malformed", kind: .merchantCategoryCode, pattern: "not-a-number", sortIndex: 0),
            rule(id: "valid", pattern: "GROCERY", sortIndex: 1),
        ]

        let winner = CategoryRuleEngine.firstMatch(
            rules: rules, merchantName: "CORNER GROCERY", merchantCategoryCode: nil
        )

        #expect(winner?.id == "valid")
    }

    @Test func noMatchReturnsNil() {
        let rules = [rule(pattern: "NETFLIX")]

        #expect(CategoryRuleEngine.firstMatch(
            rules: rules, merchantName: "CORNER GROCERY", merchantCategoryCode: 5411
        ) == nil)
    }

    @Test func emptyRuleListReturnsNil() {
        #expect(CategoryRuleEngine.firstMatch(rules: [], merchantName: "anything", merchantCategoryCode: 5411) == nil)
    }

    /// The caller's array order must not matter -- only `order` does.
    @Test func evaluationIgnoresArrayOrder() {
        let rules = [
            rule(id: "c", pattern: "GROCERY", sortIndex: 2),
            rule(id: "a", pattern: "GROCERY", sortIndex: 0),
            rule(id: "b", pattern: "GROCERY", sortIndex: 1),
        ]

        #expect(CategoryRuleEngine.firstMatch(
            rules: rules, merchantName: "CORNER GROCERY", merchantCategoryCode: nil
        )?.id == "a")
    }
}
