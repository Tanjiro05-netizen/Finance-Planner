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
            .sorted { $0.sortIndex < $1.sortIndex }
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

/// Temporary scaffolding for the isolation probe described on `CategoryRule`.
///
/// These four were stored properties until any use of the entity started trapping
/// SwiftData. They are computed over a single packed `String` here so the model stores
/// nothing but `String`s, while every caller keeps the same property names, types and
/// mutability it had before. Delete this and restore the stored properties once the cause
/// is known.
extension CategoryRule {
    private static let separator = "\u{1}"

    static func pack(kind: CategoryRuleKind, categoryID: String, sortIndex: Int, isEnabled: Bool) -> String {
        [kind.rawValue, categoryID, String(sortIndex), isEnabled ? "1" : "0"]
            .joined(separator: separator)
    }

    private var fields: [String] {
        metadata.components(separatedBy: Self.separator)
    }

    private func rewrite(kind: CategoryRuleKind? = nil, categoryID: String? = nil, sortIndex: Int? = nil, isEnabled: Bool? = nil) {
        metadata = Self.pack(
            kind: kind ?? self.kind,
            categoryID: categoryID ?? self.categoryID,
            sortIndex: sortIndex ?? self.sortIndex,
            isEnabled: isEnabled ?? self.isEnabled
        )
    }

    var kind: CategoryRuleKind {
        get { fields.first.flatMap(CategoryRuleKind.init(rawValue:)) ?? .merchantContains }
        set { rewrite(kind: newValue) }
    }

    var categoryID: String {
        get { fields.count > 1 ? fields[1] : "" }
        set { rewrite(categoryID: newValue) }
    }

    var sortIndex: Int {
        get { fields.count > 2 ? Int(fields[2]) ?? 0 : 0 }
        set { rewrite(sortIndex: newValue) }
    }

    var isEnabled: Bool {
        get { fields.count > 3 ? fields[3] == "1" : true }
        set { rewrite(isEnabled: newValue) }
    }
}
