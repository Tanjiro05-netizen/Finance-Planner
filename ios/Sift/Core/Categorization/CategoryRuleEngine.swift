import Foundation

/// Evaluates user-written categorisation rules against a transaction.
///
/// Pure and framework-free, matching `TransactionClassifier`'s shape, so the precedence
/// contract is testable without a store. `CategoryService` owns *when* this runs; this owns
/// only *which rule wins*.
enum CategoryRuleEngine {
    /// The first enabled rule whose condition holds, in `order`, or nil when none match.
    ///
    /// First-match-wins rather than most-specific-wins: the person can see the order and
    /// change it, which makes the outcome predictable in a way a hidden specificity
    /// heuristic never is. It is also what Lunch Money and Actual Budget do, so anyone
    /// arriving from those already knows the model.
    static func firstMatch(
        rules: [CategoryRule],
        merchantName: String,
        merchantCategoryCode: Int16?
    ) -> CategoryRule? {
        rules
            .filter(\.isEnabled)
            .sorted { $0.order < $1.order }
            .first { matches($0, merchantName: merchantName, merchantCategoryCode: merchantCategoryCode) }
    }

    static func matches(
        _ rule: CategoryRule,
        merchantName: String,
        merchantCategoryCode: Int16?
    ) -> Bool {
        // A rule whose stored pattern doesn't fit its kind resolves to nil and is skipped.
        // Treating it as "matches nothing" is the safe direction: the alternative for an
        // empty merchant pattern would be matching every transaction in the ledger.
        guard let matcher = rule.matcher else {
            return false
        }

        switch matcher {
        case let .merchantContains(needle):
            // Diacritic- as well as case-insensitive: someone typing "cafe" should catch
            // "CAFÉ MONDRIAN", and no card descriptor is worth losing a rule over an accent.
            return merchantName.range(
                of: needle,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) != nil
        case let .merchantCategoryCode(code):
            return merchantCategoryCode == code
        }
    }
}
