import Foundation

/// A user-written rule assigning a category to anything matching a condition.
///
/// Exists because `CategoryService.keywordRules` is compiled into the app: when it puts a
/// merchant in the wrong place, the only recourse otherwise is correcting every transaction
/// by hand, forever. These rules are evaluated ahead of those built-ins, so a person can
/// override Sift's opinion without waiting for a release.
///
/// **A `Codable` value, not a SwiftData `@Model`.** Every use of this type as an `@Model`
/// trapped SwiftData with a silent `EXC_BREAKPOINT` carrying no message anywhere -- not in
/// the crash report's `asi`, not in the test process's stderr. An isolation probe reducing
/// the model to `String`-only storage still trapped, which ruled out the property types and
/// left no further hypothesis worth testing blind without a local toolchain.
///
/// Storing rules as a value is also defensible on its own terms rather than purely as a
/// workaround: they are a short, ordered list of user-authored configuration, never queried
/// relationally and never joined against the ledger. `Money` and `MerchantKey` are already
/// `Codable` values here for similar reasons.
///
/// The condition is stored as `kind` + `pattern` rather than as separate typed columns;
/// `matcher` (in `CategoryRuleEngine.swift`) resolves it into a typed value and returns nil
/// for a malformed row. `sortIndex` is dense and zero-based, rewritten wholesale by
/// `CategoryRuleRepository.reorder(ids:)` -- first match wins, so order is the whole
/// disambiguation story when two rules could both fire.
struct CategoryRule: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var userID: String
    var kind: CategoryRuleKind
    var pattern: String
    var categoryID: String
    var sortIndex: Int
    var isEnabled: Bool

    init(
        id: String,
        userID: String,
        kind: CategoryRuleKind,
        pattern: String,
        categoryID: String,
        sortIndex: Int,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.userID = userID
        self.kind = kind
        self.pattern = pattern
        self.categoryID = categoryID
        self.sortIndex = sortIndex
        self.isEnabled = isEnabled
    }
}
