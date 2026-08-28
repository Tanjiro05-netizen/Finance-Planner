import Foundation
@testable import Sift
import Testing

@MainActor
struct ManualTransactionEntryViewModelTests {
    private let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func canSaveRequiresMerchantAmountAndAccount() {
        let viewModel = ManualTransactionEntryViewModel(
            repositories: .mock(),
            referenceDateProvider: { referenceDate }
        )
        viewModel.load()

        #expect(viewModel.canSave == false)

        viewModel.merchantName = "Corner Market"
        #expect(viewModel.canSave == false)

        viewModel.amountText = "12.50"
        #expect(viewModel.canSave)

        viewModel.amountText = "0"
        #expect(viewModel.canSave == false)

        viewModel.amountText = "not-a-number"
        #expect(viewModel.canSave == false)
    }

    @Test func canSaveIsFalseWithoutAnyAccounts() {
        let viewModel = ManualTransactionEntryViewModel(
            repositories: .emptyMock(),
            referenceDateProvider: { referenceDate }
        )
        viewModel.load()
        viewModel.merchantName = "Corner Market"
        viewModel.amountText = "12.50"

        #expect(viewModel.canSave == false)
    }

    @Test func saveInsertsManualDebitTransaction() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = ManualTransactionEntryViewModel(
            repositories: repositories,
            referenceDateProvider: { referenceDate }
        )
        viewModel.load()
        viewModel.merchantName = "Corner Market"
        viewModel.amountText = "12.50"

        let saved = viewModel.save()

        #expect(saved)
        let inserted = try #require(try repositories.transactions.all().first { $0.merchantRaw == "Corner Market" })
        #expect(inserted.source == .manual)
        #expect(inserted.direction == .debit)
        #expect(inserted.kind == .purchase)
        #expect(inserted.amount == Money.usd(1250))
    }

    @Test func saveInsertsManualIncomeTransaction() throws {
        let repositories = RepositoryContainer.mock()
        let viewModel = ManualTransactionEntryViewModel(
            repositories: repositories,
            referenceDateProvider: { referenceDate }
        )
        viewModel.load()
        viewModel.merchantName = "Freelance Client"
        viewModel.amountText = "500"
        viewModel.direction = .credit

        let saved = viewModel.save()

        #expect(saved)
        let inserted = try #require(try repositories.transactions.all().first { $0.merchantRaw == "Freelance Client" })
        #expect(inserted.direction == .credit)
        #expect(inserted.kind == .income)
    }

    @Test func saveFailsWithoutValidInput() throws {
        let repositories = RepositoryContainer.mock()
        let before = try repositories.transactions.all().count
        let viewModel = ManualTransactionEntryViewModel(
            repositories: repositories,
            referenceDateProvider: { referenceDate }
        )
        viewModel.load()

        let saved = viewModel.save()

        #expect(saved == false)
        #expect(try repositories.transactions.all().count == before)
    }
}
