import Foundation

/// A user-written rule assigning a category to anything matching a condition.
///
/// Exists because `CategoryService.keywordRules` is compiled into the app: when it puts a
/// merchant in the wrong place, the only recourse otherwise is correcting every transaction
/// by hand, forever. These rules are evaluated ahead of those built-ins, so a person can
/// override Sift's opinion without waiting for a release.
///
/// **A `Codable` value rather than a SwiftData `@Model` -- for now, and on a premise that
/// turned out to be wrong.** This was moved off SwiftData while chasing a silent
/// `EXC_BREAKPOINT` that fired on any use of the entity. The actual cause was a test
/// fixture that let its `ModelContainer` deallocate, leaving `mainContext` dangling; it had
/// nothing to do with this type, and SwiftData was never at fault.
///
/// Storing rules as a value is still defensible on its own terms -- they are a short,
/// ordered list of user-authored configuration, never queried relationally and never joined
/// against the ledger, and the whole list is read on every evaluation pass anyway. But that
/// is a reason it *can* be a value, not the reason it became one. Reverting to `@Model`
/// would match every sibling repository and is a live option.
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
