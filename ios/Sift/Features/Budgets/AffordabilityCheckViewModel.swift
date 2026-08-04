import Foundation
import Observation

@MainActor
@Observable
final class AffordabilityCheckViewModel {
    private let repositories: RepositoryContainer
    private let referenceDateProvider: () -> Date

    var amountText = ""
    var categoryID: String?
    var categories: [Category] = []
    var assessment: AffordabilityAssessment?
    var errorMessage: String?

    init(
        repositories: RepositoryContainer,
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.repositories = repositories
        self.referenceDateProvider = referenceDateProvider
    }

    var canCheck: Bool {
        parsedAmountMinor != nil
    }

    private var parsedAmountMinor: Int? {
        guard let decimal = Decimal(string: amountText), decimal > 0 else {
            return nil
        }
        return FinancialDataMapper.minorUnits(from: decimal)
    }

    func load() {
        do {
            categories = try repositories.categories.all()
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    func check() {
        guard let amountMinor = parsedAmountMinor else {
            errorMessage = "Enter an amount first."
            return
        }

        do {
            let today = referenceDateProvider()
            let amount = Money(amountMinor: amountMinor, currency: "USD")
            let safeToSpend = try SafeToSpendProvider.outcome(repositories: repositories, today: today)

            assessment = AffordabilityAdvisor.assess(
                amount: amount,
                safeToSpend: safeToSpend,
                budgetProgress: try budgetProgress(today: today)
            )
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    /// Only meaningful when a category is chosen and that category is actually budgeted —
    /// otherwise the answer rests on the cash position alone.
    private func budgetProgress(today: Date) throws -> BudgetProgress? {
        guard let categoryID, let budget = try repositories.budgets.budget(forCategory: categoryID) else {
            return nil
        }

        let cycle = BudgetPeriodCalculator.cycle(for: budget.period, containing: today)
        let transactions = try repositories.transactions.transactions(from: cycle.start, to: cycle.end)
        return BudgetProgressCalculator.progress(
            budget: budget,
            transactions: transactions,
            referenceDate: today
        )
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}
