import Foundation
@testable import Sift
import Testing

@MainActor
struct IncomeEditorViewModelTests {
    private static var referenceDate: Date {
        SeedData.referenceDate
    }

    private func makeViewModel(
        incomeID: String? = nil,
        repositories: RepositoryContainer = .mock()
    ) -> IncomeEditorViewModel {
        IncomeEditorViewModel(
            incomeID: incomeID,
            repositories: repositories,
            referenceDateProvider: { Self.referenceDate }
        )
    }

    @Test func newIncomeStartsEmptyWithAPlausibleDate() {
        let viewModel = makeViewModel()

        viewModel.load()

        #expect(viewModel.isEditing == false)
        #expect(viewModel.title == "New Income")
        #expect(viewModel.sourceName.isEmpty)
        #expect(viewModel.hasNextExpected == false)
        #expect(viewModel.nextExpected > Self.referenceDate)
    }

    @Test func loadingExistingIncomePopulatesEveryField() {
        let viewModel = makeViewModel(incomeID: SeedData.ID.payrollIncome)

        viewModel.load()

        #expect(viewModel.isEditing)
        #expect(viewModel.title == "Edit Income")
        #expect(viewModel.sourceName.isEmpty == false)
        #expect(viewModel.amountText.isEmpty == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func canSaveRequiresASourceAndAPositiveAmount() {
        let viewModel = makeViewModel()
        viewModel.load()

        #expect(viewModel.canSave == false)

        viewModel.sourceName = "Freelance"
        #expect(viewModel.canSave == false)

        viewModel.amountText = "0"
        #expect(viewModel.canSave == false)

        viewModel.amountText = "2400"
        #expect(viewModel.canSave)
    }

    @Test func incomeWithoutADateCannotMoveSafeToSpend() {
        let viewModel = makeViewModel()
        viewModel.load()

        // Safe-to-spend runs to the next expected payday, so undated income moves nothing.
        #expect(viewModel.needsDateToAffectSafeToSpend)

        viewModel.hasNextExpected = true
        #expect(viewModel.needsDateToAffectSafeToSpend == false)
    }

    @Test func savingNewIncomeInsertsIt() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = makeViewModel(repositories: repositories)
        viewModel.load()
        let before = try repositories.recurringIncome.all().count

        viewModel.sourceName = "  Side project  "
        viewModel.amountText = "640.00"
        viewModel.cadence = .biweekly
        viewModel.hasNextExpected = true

        #expect(viewModel.save())

        let all = try repositories.recurringIncome.all()
        #expect(all.count == before + 1)
        let inserted = try #require(all.first { $0.sourceName == "Side project" })
        #expect(inserted.amount == .usd(64000))
        #expect(inserted.cadence == .biweekly)
        #expect(inserted.status == .active)
        #expect(inserted.detectionConfidence == 1.0)
    }

    @Test func savingExistingIncomeUpdatesItInPlace() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = makeViewModel(incomeID: SeedData.ID.payrollIncome, repositories: repositories)
        viewModel.load()
        let before = try repositories.recurringIncome.all().count

        viewModel.amountText = "3100.00"

        #expect(viewModel.save())

        #expect(try repositories.recurringIncome.all().count == before)
        let updated = try #require(try repositories.recurringIncome.recurringIncome(id: SeedData.ID.payrollIncome))
        #expect(updated.amount == .usd(310_000))
    }

    @Test func savingWithoutValidInputReportsAnError() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = makeViewModel(repositories: repositories)
        viewModel.load()
        let before = try repositories.recurringIncome.all().count

        #expect(viewModel.save() == false)
        #expect(viewModel.errorMessage != nil)
        #expect(try repositories.recurringIncome.all().count == before)
    }

    @Test func deletingRemovesTheIncome() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = makeViewModel(incomeID: SeedData.ID.payrollIncome, repositories: repositories)
        viewModel.load()

        #expect(viewModel.delete())
        #expect(try repositories.recurringIncome.recurringIncome(id: SeedData.ID.payrollIncome) == nil)
    }

    @Test func deletingUnsavedIncomeIsANoOp() {
        let viewModel = makeViewModel()
        viewModel.load()

        #expect(viewModel.delete() == false)
    }
}
