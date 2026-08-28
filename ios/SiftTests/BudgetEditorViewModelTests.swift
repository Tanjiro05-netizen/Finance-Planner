import Foundation
@testable import Sift
import Testing

@MainActor
struct BudgetEditorViewModelTests {
    private static var referenceDate: Date {
        SeedData.referenceDate
    }

    private func makeViewModel(budgetID: String? = nil) -> BudgetEditorViewModel {
        BudgetEditorViewModel(
            budgetID: budgetID,
            repositories: .mock(),
            referenceDateProvider: { Self.referenceDate }
        )
    }

    @Test func loadingANewBudgetPreselectsTheFirstCategory() {
        let viewModel = makeViewModel()

        viewModel.load()

        #expect(viewModel.isEditing == false)
        #expect(viewModel.title == "New Budget")
        #expect(viewModel.categories.isEmpty == false)
        #expect(viewModel.categoryID == viewModel.categories.first?.id)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func loadingAnExistingBudgetPopulatesEveryField() {
        let viewModel = makeViewModel(budgetID: SeedData.ID.groceriesBudget)

        viewModel.load()

        #expect(viewModel.isEditing)
        #expect(viewModel.title == "Edit Budget")
        #expect(viewModel.categoryID == SeedData.ID.groceries)
        #expect(viewModel.period == .monthly)
        #expect(viewModel.rolloverEnabled == false)
        // Round-trips through the text field form, not the display form.
        #expect(viewModel.amountText == "400.00")
    }

    @Test func canSaveRequiresACategoryAndAPositiveAmount() {
        let viewModel = makeViewModel()
        viewModel.load()

        viewModel.amountText = ""
        #expect(viewModel.canSave == false)

        viewModel.amountText = "0"
        #expect(viewModel.canSave == false)

        viewModel.amountText = "not a number"
        #expect(viewModel.canSave == false)

        viewModel.amountText = "125.50"
        #expect(viewModel.canSave)

        viewModel.categoryID = nil
        #expect(viewModel.canSave == false)
    }

    @Test func savingANewBudgetInsertsIt() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = BudgetEditorViewModel(
            repositories: repositories,
            referenceDateProvider: { Self.referenceDate }
        )
        viewModel.load()
        let before = try repositories.budgets.all().count

        viewModel.categoryID = SeedData.ID.health
        viewModel.amountText = "75.25"
        viewModel.period = .weekly
        viewModel.rolloverEnabled = true

        #expect(viewModel.save())

        let all = try repositories.budgets.all()
        #expect(all.count == before + 1)
        let inserted = try #require(all.first { $0.categoryID == SeedData.ID.health })
        #expect(inserted.amount == .usd(7525))
        #expect(inserted.period == .weekly)
        #expect(inserted.rolloverEnabled)
        #expect(inserted.status == .active)
    }

    @Test func savingAnExistingBudgetUpdatesItInPlace() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = BudgetEditorViewModel(
            budgetID: SeedData.ID.groceriesBudget,
            repositories: repositories,
            referenceDateProvider: { Self.referenceDate }
        )
        viewModel.load()
        let before = try repositories.budgets.all().count

        viewModel.amountText = "525.00"
        viewModel.rolloverEnabled = true

        #expect(viewModel.save())

        // Editing must not create a second budget for the same category.
        #expect(try repositories.budgets.all().count == before)
        let updated = try #require(try repositories.budgets.budget(id: SeedData.ID.groceriesBudget))
        #expect(updated.amount == .usd(52500))
        #expect(updated.rolloverEnabled)
    }

    @Test func savingWithoutValidInputReportsAnErrorAndDoesNotDismiss() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = BudgetEditorViewModel(
            repositories: repositories,
            referenceDateProvider: { Self.referenceDate }
        )
        viewModel.load()
        let before = try repositories.budgets.all().count

        viewModel.amountText = ""

        #expect(viewModel.save() == false)
        #expect(viewModel.errorMessage != nil)
        #expect(try repositories.budgets.all().count == before)
    }

    @Test func deletingRemovesTheBudget() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = BudgetEditorViewModel(
            budgetID: SeedData.ID.groceriesBudget,
            repositories: repositories,
            referenceDateProvider: { Self.referenceDate }
        )
        viewModel.load()

        #expect(viewModel.delete())
        #expect(try repositories.budgets.budget(id: SeedData.ID.groceriesBudget) == nil)
    }

    @Test func deletingANewUnsavedBudgetIsANoOp() {
        let viewModel = makeViewModel()
        viewModel.load()

        #expect(viewModel.delete() == false)
    }
}
