import Foundation
import Observation

/// A budget paired with everything the row needs to render it.
struct BudgetRowModel: Identifiable, Equatable {
    let id: String
    let categoryID: String
    let categoryName: String
    let progress: BudgetProgress

    static func == (lhs: BudgetRowModel, rhs: BudgetRowModel) -> Bool {
        lhs.id == rhs.id && lhs.progress == rhs.progress && lhs.categoryName == rhs.categoryName
    }
}

@MainActor
@Observable
final class BudgetsViewModel {
    private let repositories: RepositoryContainer
    private let referenceDateProvider: () -> Date

    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?
    var rows: [BudgetRowModel] = []

    init(
        repositories: RepositoryContainer,
        referenceDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.repositories = repositories
        self.referenceDateProvider = referenceDateProvider
    }

    var isEmpty: Bool {
        hasLoaded && rows.isEmpty && errorMessage == nil
    }

    /// Budgets that need attention, for the Home summary card.
    var overPaceRows: [BudgetRowModel] {
        rows.filter { $0.progress.pace == .over }
    }

    var totalBudgeted: Money {
        (try? Money.sum(rows.map(\.progress.budgeted))) ?? .zeroUSD
    }

    var totalSpent: Money {
        (try? Money.sum(rows.map(\.progress.spent))) ?? .zeroUSD
    }

    func load() {
        if !hasLoaded {
            isLoading = true
        }
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            rows = try buildRows()
            errorMessage = nil
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
    }

    private func buildRows() throws -> [BudgetRowModel] {
        let today = referenceDateProvider()
        let budgets = try repositories.budgets.all().filter { $0.status == .active }

        guard !budgets.isEmpty else {
            return []
        }

        let categoryNames = try Dictionary(
            repositories.categories.all().map { ($0.id, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )

        // One ledger read covering the widest window any budget needs, rather than a query
        // per budget: monthly cycles are the longest, and the previous cycle is required
        // whenever rollover is on.
        let widest = widestWindow(for: budgets, today: today)
        let transactions = try repositories.transactions.transactions(from: widest.start, to: widest.end)

        return budgets.map { budget in
            let carry = rolloverCarry(for: budget, transactions: transactions, today: today)
            let progress = BudgetProgressCalculator.progress(
                budget: budget,
                transactions: transactions,
                referenceDate: today,
                rolloverCarry: carry
            )

            return BudgetRowModel(
                id: budget.id,
                categoryID: budget.categoryID,
                categoryName: categoryNames[budget.categoryID] ?? "Uncategorized",
                progress: progress
            )
        }
        .sorted { $0.categoryName.localizedStandardCompare($1.categoryName) == .orderedAscending }
    }

    private func rolloverCarry(for budget: Budget, transactions: [Transaction], today: Date) -> Money {
        guard budget.rolloverEnabled else {
            return .zeroUSD
        }

        let previous = BudgetPeriodCalculator.previousCycle(for: budget.period, containing: today)
        return BudgetProgressCalculator.rolloverCarry(
            budget: budget,
            previousCycleTransactions: transactions,
            previousCycle: previous
        )
    }

    private func widestWindow(for budgets: [Budget], today: Date) -> DateInterval {
        let starts = budgets.map { budget in
            BudgetPeriodCalculator.previousCycle(for: budget.period, containing: today).start
        }
        let ends = budgets.map { budget in
            BudgetPeriodCalculator.cycle(for: budget.period, containing: today).end
        }

        let start = starts.min() ?? today
        let end = max(ends.max() ?? today, start)
        return DateInterval(start: start, end: end)
    }

    private func userFacingMessage(for error: Error) -> String {
        if let siftError = error as? SiftError {
            return siftError.errorDescription ?? "Something went wrong."
        }

        return error.localizedDescription
    }
}
