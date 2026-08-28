import Foundation
@testable import Sift
import Testing

@MainActor
struct BillEditorViewModelTests {
    private static var referenceDate: Date {
        SeedData.referenceDate
    }

    private func makeViewModel(
        billID: String? = nil,
        repositories: RepositoryContainer = .mock()
    ) -> BillEditorViewModel {
        BillEditorViewModel(
            billID: billID,
            repositories: repositories,
            referenceDateProvider: { Self.referenceDate }
        )
    }

    @Test func newBillStartsEmptyWithAPlausibleDate() {
        let viewModel = makeViewModel()

        viewModel.load()

        #expect(viewModel.isEditing == false)
        #expect(viewModel.title == "New Bill")
        #expect(viewModel.name.isEmpty)
        #expect(viewModel.cadence == .monthly)
        #expect(viewModel.hasNextDue == false)
        // The picker must not open on a date that has already passed.
        #expect(viewModel.nextDue > Self.referenceDate)
        #expect(viewModel.categories.isEmpty == false)
    }

    @Test func loadingAnExistingBillPopulatesEveryField() {
        let viewModel = makeViewModel(billID: SeedData.ID.rentBill)

        viewModel.load()

        #expect(viewModel.isEditing)
        #expect(viewModel.title == "Edit Bill")
        #expect(viewModel.name.isEmpty == false)
        #expect(viewModel.amountText.isEmpty == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func canSaveRequiresANameAndAPositiveAmount() {
        let viewModel = makeViewModel()
        viewModel.load()

        #expect(viewModel.canSave == false)

        viewModel.name = "Rent"
        #expect(viewModel.canSave == false)

        viewModel.amountText = "0"
        #expect(viewModel.canSave == false)

        viewModel.amountText = "1450.00"
        #expect(viewModel.canSave)

        viewModel.name = "   "
        #expect(viewModel.canSave == false)
    }

    @Test func aBillWithoutADateCannotMoveSafeToSpend() {
        let viewModel = makeViewModel()
        viewModel.load()

        // The whole point of manual bills is correcting safe-to-spend, and a bill with no
        // due date never lands in an upcoming window.
        #expect(viewModel.needsDateToAffectSafeToSpend)

        viewModel.hasNextDue = true
        #expect(viewModel.needsDateToAffectSafeToSpend == false)
    }

    @Test func savingANewBillInsertsIt() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = makeViewModel(repositories: repositories)
        viewModel.load()
        let before = try repositories.bills.all().count

        viewModel.name = "  Council tax  "
        viewModel.amountText = "182.50"
        viewModel.cadence = .monthly
        viewModel.hasNextDue = true

        #expect(viewModel.save())

        let all = try repositories.bills.all()
        #expect(all.count == before + 1)
        let inserted = try #require(all.first { $0.name == "Council tax" })
        #expect(inserted.amount == .usd(18250))
        #expect(inserted.status == .active)
        #expect(inserted.nextDue != nil)
        // Typed by hand, so it is not a low-confidence guess.
        #expect(inserted.detectionConfidence == 1.0)
    }

    @Test func turningTheDateToggleOffClearsTheStoredDate() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = makeViewModel(billID: SeedData.ID.rentBill, repositories: repositories)
        viewModel.load()

        viewModel.hasNextDue = false

        #expect(viewModel.save())
        let updated = try #require(try repositories.bills.bill(id: SeedData.ID.rentBill))
        #expect(updated.nextDue == nil)
    }

    @Test func renamingDoesNotBreakTheLinkToRealCharges() throws {
        let repositories = RepositoryContainer.mock()
        let original = try #require(try repositories.bills.bill(id: SeedData.ID.rentBill))
        let originalKey = original.merchantKey

        let viewModel = makeViewModel(billID: SeedData.ID.rentBill, repositories: repositories)
        viewModel.load()
        viewModel.name = "Renamed rent"

        #expect(viewModel.save())

        let updated = try #require(try repositories.bills.bill(id: SeedData.ID.rentBill))
        #expect(updated.name == "Renamed rent")
        // merchantKey ties a detected bill to its real charges, and
        // DiscretionarySpendEstimator uses it to keep those out of the everyday average.
        // Renaming the label must not sever that.
        #expect(updated.merchantKey == originalKey)
    }

    @Test func savingWithoutValidInputReportsAnError() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = makeViewModel(repositories: repositories)
        viewModel.load()
        let before = try repositories.bills.all().count

        #expect(viewModel.save() == false)
        #expect(viewModel.errorMessage != nil)
        #expect(try repositories.bills.all().count == before)
    }

    @Test func deletingRemovesTheBill() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = makeViewModel(billID: SeedData.ID.rentBill, repositories: repositories)
        viewModel.load()

        #expect(viewModel.delete())
        #expect(try repositories.bills.bill(id: SeedData.ID.rentBill) == nil)
    }

    @Test func deletingAnUnsavedBillIsANoOp() {
        let viewModel = makeViewModel()
        viewModel.load()

        #expect(viewModel.delete() == false)
    }

    @Test func theCadencePickerOffersNoUnknownOption() {
        // .unknown is a detection outcome, never something a person would choose.
        #expect(BillEditorViewModel.selectableCadences.contains(.unknown) == false)
        #expect(BillEditorViewModel.selectableCadences.isEmpty == false)
    }
}
