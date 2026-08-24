import Foundation
import Observation

/// Backs the create/edit sheet for one rule. Mirrors `BudgetEditorViewModel`'s shape:
/// `canSave` gates the button, and `save()`/`delete()` return whether to dismiss.
@MainActor
@Observable
final class CategoryRuleEditorViewModel {
    private let repositories: RepositoryContainer
    private let ruleID: String?

    var kind: CategoryRuleKind = .merchantContains
    var pattern = ""
    var categoryID: String?
    var isEnabled = true
    var errorMessage: String?
    var categories: [Category] = []
    /// Set after a successful save so the list can report what the rule actually moved.
    private(set) var lastChangedCount = 0

    init(ruleID: String? = nil, repositories: RepositoryContainer) {
        self.ruleID = ruleID
        self.repositories = repositories
    }

    var isEditing: Bool {
        ruleID != nil
    }

    var title: String {
        isEditing ? "Edit Rule" : "New Rule"
    }

    /// The prompt under the pattern field, which has to differ by kind: one takes prose,
    /// the other takes four digits.
    var patternPrompt: String {
        switch kind {
        case .merchantContains:
            "e.g. BLUE BOTTLE"
        case .merchantCategoryCode:
            "e.g. 5411"
        }
    }

    var patternHelp: String {
        switch kind {
        case .merchantContains:
            "Matches any transaction whose merchant name contains this text. Case and accents are ignored."
        case .merchantCategoryCode:
            "Matches the card network's own four-digit classification. Useful when the merchant name is unreadable."
        }
    }

    /// Validated through the same `matcher` the engine uses, so the button can never enable
    /// a rule the engine would then skip -- an empty pattern, or a code that isn't a number.
    var canSave: Bool {
        guard categoryID != nil else {
            return false
        }
        return draftRule().matcher != nil
    }

    func load() {
        do {
            categories = try repositories.categories.all()

            if let ruleID, let rule = try repositories.categoryRules.rule(id: ruleID) {
                kind = rule.kind
                pattern = rule.pattern
                categoryID = rule.categoryID
                isEnabled = rule.isEnabled
            } else {
                categoryID = categories.first?.id
            }

            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    /// Returns true when the sheet should dismiss.
    func save() -> Bool {
        guard let categoryID, draftRule().matcher != nil else {
            errorMessage = validationMessage
            return false
        }

        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if let ruleID, let existing = try repositories.categoryRules.rule(id: ruleID) {
                existing.kind = kind
                existing.pattern = trimmed
                existing.categoryID = categoryID
                existing.isEnabled = isEnabled
                try repositories.categoryRules.update(existing)
            } else {
                let sortIndex = try repositories.categoryRules.all().count
                try repositories.categoryRules.insert(CategoryRule(
                    id: "rule-\(UUID().uuidString.lowercased())",
                    userID: SeedData.defaultUserID,
                    kind: kind,
                    pattern: trimmed,
                    categoryID: categoryID,
                    sortIndex: sortIndex,
                    isEnabled: isEnabled
                ))
            }

            lastChangedCount = try applyToExistingLedger()
            errorMessage = nil
            return true
        } catch {
            errorMessage = userFacingMessage(for: error)
            return false
        }
    }

    /// Returns true when the sheet should dismiss.
    func delete() -> Bool {
        guard let ruleID else {
            return false
        }

        do {
            try repositories.categoryRules.delete(id: ruleID)
            lastChangedCount = try applyToExistingLedger()
            return true
        } catch {
            errorMessage = userFacingMessage(for: error)
            return false
        }
    }

    /// A rule that only affected future transactions would look broken, so saving re-runs
    /// categorisation over what is already there. Manual assignments are still untouched.
    private func applyToExistingLedger() throws -> Int {
        let service = CategoryService(repositories: repositories)
        let changed = try service.applyAutoCategorizationForTransactions()
        try service.applyAutoCategorizationIfEnabled()
        return changed
    }

    private func draftRule() -> CategoryRule {
        CategoryRule(
            id: ruleID ?? "draft",
            userID: SeedData.defaultUserID,
            kind: kind,
            pattern: pattern,
            categoryID: categoryID ?? "",
            sortIndex: 0,
            isEnabled: isEnabled
        )
    }

    private var validationMessage: String {
        switch kind {
        case .merchantContains:
            "Enter some merchant text and pick a category."
        case .merchantCategoryCode:
            "Enter a numeric category code and pick a category."
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}
