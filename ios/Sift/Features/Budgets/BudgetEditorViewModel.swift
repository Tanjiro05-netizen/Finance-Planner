import Foundation
import Observation

@MainActor
@Observable
final class BudgetEditorViewModel {
    private let repositories: RepositoryContainer
    private let budgetID: String?
    private let referenceDateProvider: () -> Date

    var categoryID: String?
    var amountText = ""
    var period: BudgetPeriod = .monthly
    var rolloverEnabled = false
    var errorMessage: String?
    var categories: [Category] = []

    init(
        budgetID: String? = nil,
        repositories: RepositoryContainer,
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.budgetID = budgetID
        self.repositories = repositories
        self.referenceDateProvider = referenceDateProvider
    }

    var isEditing: Bool {
        budgetID != nil
    }

    var title: String {
        isEditing ? "Edit Budget" : "New Budget"
    }

    var canSave: Bool {
        categoryID != nil && parsedAmountMinor != nil
    }

    /// Parsed via `Decimal` and the shared minor-unit helper, matching manual transaction
    /// entry — money never round-trips through a binary floating point type.
    private var parsedAmountMinor: Int? {
        guard let decimal = Decimal(string: amountText), decimal > 0 else {
            return nil
        }
        return FinancialDataMapper.minorUnits(from: decimal)
    }

    func load() {
        do {
            categories = try repositories.categories.all()

            if let budgetID, let budget = try repositories.budgets.budget(id: budgetID) {
                categoryID = budget.categoryID
                amountText = budget.amount.editableAmountText
                period = budget.period
                rolloverEnabled = budget.rolloverEnabled
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
        guard let categoryID, let amountMinor = parsedAmountMinor else {
            errorMessage = "Pick a category and enter an amount."
            return false
        }

        let amount = Money(amountMinor: amountMinor, currency: "USD")

        do {
            if let budgetID, let existing = try repositories.budgets.budget(id: budgetID) {
                existing.categoryID = categoryID
                existing.amount = amount
                existing.period = period
                existing.rolloverEnabled = rolloverEnabled
                try repositories.budgets.update(existing)
            } else {
                try repositories.budgets.insert(Budget(
                    id: "budget-\(UUID().uuidString.lowercased())",
                    userID: SeedData.defaultUserID,
                    categoryID: categoryID,
                    amount: amount,
                    period: period,
                    rolloverEnabled: rolloverEnabled,
                    startDate: referenceDateProvider()
                ))
            }

            errorMessage = nil
            return true
        } catch {
            errorMessage = userFacingMessage(for: error)
            return false
        }
    }

    /// Returns true when the sheet should dismiss.
    func delete() -> Bool {
        guard let budgetID else {
            return false
        }

        do {
            try repositories.budgets.delete(id: budgetID)
            return true
        } catch {
            errorMessage = userFacingMessage(for: error)
            return false
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}
