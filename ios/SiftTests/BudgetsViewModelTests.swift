import Foundation
@testable import Sift
import Testing

@MainActor
struct BudgetsViewModelTests {
    private static var referenceDate: Date {
        SeedData.referenceDate
    }

    @Test func loadsSeededBudgetsWithCategoryNames() {
        let viewModel = BudgetsViewModel(repositories: .mock(), referenceDateProvider: { Self.referenceDate })

        viewModel.load()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.rows.count == 2)
        #expect(viewModel.rows.map(\.categoryName) == ["Dining", "Groceries"])
        #expect(viewModel.isEmpty == false)
    }

    @Test func groceriesProgressMatchesTheSeededSpend() throws {
        let viewModel = BudgetsViewModel(repositories: .mock(), referenceDateProvider: { Self.referenceDate })

        viewModel.load()

        let groceries = try #require(viewModel.rows.first { $0.categoryName == "Groceries" })
        // The two seeded CORNER GROCERY debits in June: $62.47 + $54.88.
        #expect(groceries.progress.spent == .usd(11735))
        #expect(groceries.progress.budgeted == .usd(40000))
        #expect(groceries.progress.isOverspent == false)
    }

    @Test func emptyStoreReportsEmptyRatherThanFailing() {
        let viewModel = BudgetsViewModel(repositories: .emptyMock(), referenceDateProvider: { Self.referenceDate })

        viewModel.load()

        #expect(viewModel.rows.isEmpty)
        #expect(viewModel.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func totalsSumAcrossBudgets() {
        let viewModel = BudgetsViewModel(repositories: .mock(), referenceDateProvider: { Self.referenceDate })

        viewModel.load()

        // Groceries $400 + Dining $100, the latter carrying rollover from an empty May.
        #expect(viewModel.totalBudgeted.amountMinor >= 50000)
        #expect(viewModel.totalSpent.amountMinor > 0)
    }

    @Test func seededBudgetsAreNotOverPace() {
        // Demo data is deliberately healthy, so the Home nudge stays hidden for it.
        let viewModel = BudgetsViewModel(repositories: .mock(), referenceDateProvider: { Self.referenceDate })

        viewModel.load()

        #expect(viewModel.overPaceRows.isEmpty)
    }
}
