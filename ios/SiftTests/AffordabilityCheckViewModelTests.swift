import Foundation
@testable import Sift
import Testing

@MainActor
struct AffordabilityCheckViewModelTests {
    private static var referenceDate: Date {
        SeedData.referenceDate
    }

    private func makeViewModel(repositories: RepositoryContainer = .mock()) -> AffordabilityCheckViewModel {
        AffordabilityCheckViewModel(
            repositories: repositories,
            referenceDateProvider: { Self.referenceDate }
        )
    }

    @Test func loadPopulatesCategories() {
        let viewModel = makeViewModel()

        viewModel.load()

        #expect(viewModel.categories.isEmpty == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.assessment == nil)
    }

    @Test func canCheckRequiresAPositiveAmount() {
        let viewModel = makeViewModel()
        viewModel.load()

        #expect(viewModel.canCheck == false)

        viewModel.amountText = "0"
        #expect(viewModel.canCheck == false)

        viewModel.amountText = "abc"
        #expect(viewModel.canCheck == false)

        viewModel.amountText = "25"
        #expect(viewModel.canCheck)
    }

    @Test func checkingWithoutAnAmountReportsAnError() {
        let viewModel = makeViewModel()
        viewModel.load()

        viewModel.check()

        #expect(viewModel.assessment == nil)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func checkingWithoutACategoryAnswersFromCashAlone() throws {
        let viewModel = makeViewModel()
        viewModel.load()
        viewModel.amountText = "25.00"

        viewModel.check()

        let assessment = try #require(viewModel.assessment)
        #expect(assessment.amount == .usd(2500))
        #expect(assessment.budgetRemainingAfter == nil)
        #expect(assessment.reasons.isEmpty == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func checkingABudgetedCategoryIncludesTheBudgetRemainder() throws {
        let viewModel = makeViewModel()
        viewModel.load()
        viewModel.categoryID = SeedData.ID.groceries
        viewModel.amountText = "50.00"

        viewModel.check()

        let assessment = try #require(viewModel.assessment)
        // Groceries budget is $400 with $117.35 already spent this period, so a $50
        // purchase should leave $232.65.
        #expect(assessment.budgetRemainingAfter == .usd(23265))
    }

    @Test func checkingAnUnbudgetedCategoryOmitsTheBudgetSide() throws {
        let viewModel = makeViewModel()
        viewModel.load()
        // Seeded budgets cover groceries and dining only.
        viewModel.categoryID = SeedData.ID.security
        viewModel.amountText = "10.00"

        viewModel.check()

        let assessment = try #require(viewModel.assessment)
        #expect(assessment.budgetRemainingAfter == nil)
    }

    @Test func withoutAnyBalanceTheVerdictSaysSo() throws {
        let viewModel = makeViewModel(repositories: .emptyMock())
        viewModel.load()
        viewModel.amountText = "25.00"

        viewModel.check()

        let assessment = try #require(viewModel.assessment)
        #expect(assessment.verdict == .tight)
        #expect(assessment.remainingAfter == nil)
        #expect(assessment.reasons.contains { $0.id == "no-balance" })
    }

    @Test func rerunningReplacesThePreviousAssessment() throws {
        let viewModel = makeViewModel()
        viewModel.load()

        viewModel.amountText = "10.00"
        viewModel.check()
        let first = try #require(viewModel.assessment)

        viewModel.amountText = "20.00"
        viewModel.check()
        let second = try #require(viewModel.assessment)

        #expect(first.amount == .usd(1000))
        #expect(second.amount == .usd(2000))
    }
}
