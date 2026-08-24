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

/// Resolution of a stored rule into something evaluable.
///
/// Deliberately an extension rather than a member of the `@Model` class. SwiftData's macro
/// inspects every `var` in a class body to decide what to persist, and it traps at fetch
/// time on a computed property whose type it cannot persist -- `CategoryRuleMatcher` is an
/// enum with associated values and is `Equatable`, not `Codable`. `Subscription`'s computed
/// `monthlyEquivalent` is fine only because `Money` happens to be `Codable`. An extension
/// sits outside the macro expansion entirely, so the question never arises.
///
/// It also lands the layering in the right place: the model is storage, and turning a
/// stored pattern into a decision belongs next to the engine that makes the decision.
extension CategoryRule {
    /// The stored condition as something evaluable, or nil when `pattern` doesn't fit
    /// `kind` -- an empty merchant string (which would match every transaction) or an MCC
    /// rule whose pattern isn't an integer in range.
    var matcher: CategoryRuleMatcher? {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        switch kind {
        case .merchantContains:
            return .merchantContains(trimmed)
        case .merchantCategoryCode:
            guard let code = Int16(trimmed) else {
                return nil
            }
            return .merchantCategoryCode(code)
        }
    }
}
