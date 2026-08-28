import Foundation
import Observation

/// Backs the rule list: load, reorder, delete, and reporting what a re-run actually moved.
@MainActor
@Observable
final class CategoryRulesViewModel {
    private let repositories: RepositoryContainer

    var rules: [CategoryRule] = []
    var categories: [Category] = []
    var errorMessage: String?
    /// Set after a re-run so the screen can say what happened. Cleared on the next edit.
    var lastRunSummary: String?

    init(repositories: RepositoryContainer) {
        self.repositories = repositories
    }

    var isEmpty: Bool {
        rules.isEmpty
    }

    func load() {
        do {
            rules = try repositories.categoryRules.all()
            categories = try repositories.categories.all()
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    func categoryName(for rule: CategoryRule) -> String {
        categories.first { $0.id == rule.categoryID }?.name ?? "Uncategorized"
    }

    /// What the rule reads as in the list, e.g. `Merchant name contains "BLUE BOTTLE"`.
    func summary(for rule: CategoryRule) -> String {
        "\(rule.kind.label) \"\(rule.pattern)\""
    }

    func move(from source: IndexSet, to destination: Int) {
        var reordered = rules
        reordered.move(fromOffsets: source, toOffset: destination)

        do {
            try repositories.categoryRules.reorder(ids: reordered.map(\.id))
            load()
            rerun()
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    func delete(id: String) {
        do {
            try repositories.categoryRules.delete(id: id)
            load()
            rerun()
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    func setEnabled(_ isEnabled: Bool, for rule: CategoryRule) {
        do {
            // CategoryRule is a value, so this edits a copy and hands it back to the
            // repository rather than mutating shared state in place.
            var updated = rule
            updated.isEnabled = isEnabled
            try repositories.categoryRules.update(updated)
            load()
            rerun()
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    /// Re-applies categorisation over the existing ledger.
    ///
    /// Called after every change rather than only on save: reordering or disabling a rule
    /// changes the outcome exactly as much as editing one does, and a list that only
    /// sometimes took effect would be worse than one that never did.
    func rerun() {
        do {
            let service = CategoryService(repositories: repositories)
            let changed = try service.applyAutoCategorizationForTransactions()
            try service.applyAutoCategorizationIfEnabled()
            lastRunSummary = Self.summaryText(changed: changed)
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    static func summaryText(changed: Int) -> String {
        switch changed {
        case 0:
            "No transactions changed category."
        case 1:
            "1 transaction recategorised."
        default:
            "\(changed) transactions recategorised."
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}
