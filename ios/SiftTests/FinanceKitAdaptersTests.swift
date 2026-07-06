import Foundation
import Testing
@testable import Sift

struct FinanceKitAdaptersTests {
    private let referenceDate = Date(timeIntervalSince1970: 1_735_000_000)

    private func snapshot(
        id: String,
        merchant: String,
        amount: Decimal,
        daysAgo: Int,
        isDebit: Bool = true,
        isPending: Bool = false,
        currency: String = "USD"
    ) -> FinancialTransactionSnapshot {
        FinancialTransactionSnapshot(
            id: id,
            accountID: "acct-1",
            merchantName: merchant,
            amount: amount,
            currencyCode: currency,
            date: referenceDate.addingTimeInterval(TimeInterval(-daysAgo * 86_400)),
            isPending: isPending,
            isDebit: isDebit
        )
    }

    // MARK: - Mapper

    @Test func minorUnitsRoundsToCents() {
        #expect(FinancialDataMapper.minorUnits(from: Decimal(string: "15.49")!) == 1549)
        #expect(FinancialDataMapper.minorUnits(from: Decimal(string: "9.999")!) == 1000)
        #expect(FinancialDataMapper.minorUnits(from: Decimal(string: "-12.30")!) == 1230)
        #expect(FinancialDataMapper.minorUnits(from: Decimal(0)) == 0)
    }

    @Test func remoteTransactionCarriesUserAndMagnitude() {
        let mapped = FinancialDataMapper.remoteTransaction(
            from: snapshot(id: "t1", merchant: "Tonebox", amount: Decimal(string: "-9.99")!, daysAgo: 0),
            userID: "user-42"
        )

        #expect(mapped.id == "t1")
        #expect(mapped.userId == "user-42")
        #expect(mapped.accountId == "acct-1")
        #expect(mapped.merchantName == "Tonebox")
        #expect(mapped.amountMinor == 999)
        #expect(mapped.isoCurrency == "USD")
        #expect(mapped.category == nil)
    }

    @Test func remoteAccountMapsLiabilityToCredit() {
        let asset = FinancialDataMapper.remoteAccount(from: FinancialAccountSnapshot(
            id: "a1", displayName: "Apple Cash", institutionName: "Apple", currencyCode: "USD", isLiability: false
        ))
        let liability = FinancialDataMapper.remoteAccount(from: FinancialAccountSnapshot(
            id: "a2", displayName: "Apple Card", institutionName: "Goldman Sachs", currencyCode: "USD", isLiability: true
        ))

        #expect(asset.type == "depository")
        #expect(liability.type == "credit")
        #expect(liability.name == "Apple Card")
    }

    @Test func spendTransactionsDropCreditsAndSortNewestFirst() {
        let charges = FinancialDataMapper.spendTransactions(from: [
            snapshot(id: "old", merchant: "A", amount: 5, daysAgo: 10),
            snapshot(id: "refund", merchant: "B", amount: 5, daysAgo: 1, isDebit: false),
            snapshot(id: "new", merchant: "C", amount: 5, daysAgo: 1),
        ])

        #expect(charges.map(\.id) == ["new", "old"])
    }

    // MARK: - FinanceKitAPIClient

    @Test func syncReportsAvailableChargeCount() async throws {
        let store = MockFinancialDataStore(transactions: [
            snapshot(id: "t1", merchant: "A", amount: 5, daysAgo: 1),
            snapshot(id: "t2", merchant: "B", amount: 6, daysAgo: 2),
            snapshot(id: "credit", merchant: "C", amount: 6, daysAgo: 3, isDebit: false),
        ])
        let client = FinanceKitAPIClient(store: store, userID: "user-1")

        let response = try await client.syncTransactions()

        #expect(response.added == 2)
        #expect(response.hasMore == false)
    }

    @Test func listTransactionsPagesDeterministically() async throws {
        let store = MockFinancialDataStore(transactions: [
            snapshot(id: "t1", merchant: "A", amount: 5, daysAgo: 1),
            snapshot(id: "t2", merchant: "B", amount: 6, daysAgo: 2),
            snapshot(id: "t3", merchant: "C", amount: 7, daysAgo: 3),
        ])
        let client = FinanceKitAPIClient(store: store, userID: "user-1")

        let firstPage = try await client.listTransactions(limit: 2, offset: 0)
        let secondPage = try await client.listTransactions(limit: 2, offset: 2)

        #expect(firstPage.map(\.id) == ["t1", "t2"])
        #expect(secondPage.map(\.id) == ["t3"])
        #expect(firstPage.allSatisfy { $0.userId == "user-1" })
    }

    @Test func unauthorizedStoreYieldsNoData() async throws {
        let store = MockFinancialDataStore(
            status: .denied,
            transactions: [snapshot(id: "t1", merchant: "A", amount: 5, daysAgo: 1)]
        )
        let client = FinanceKitAPIClient(store: store)

        #expect(try await client.syncTransactions().added == 0)
        #expect(try await client.listTransactions(limit: 50, offset: 0).isEmpty)
    }

    @Test func unavailableStoreYieldsNoData() async throws {
        let store = MockFinancialDataStore(
            available: false,
            transactions: [snapshot(id: "t1", merchant: "A", amount: 5, daysAgo: 1)]
        )
        let client = FinanceKitAPIClient(store: store)

        #expect(try await client.listTransactions(limit: 50, offset: 0).isEmpty)
        #expect(try await client.listAccounts().isEmpty)
    }

    @Test func conciergeCancellationIsUnsupported() async throws {
        let client = FinanceKitAPIClient(store: MockFinancialDataStore())

        await #expect(throws: SiftError.self) {
            _ = try await client.createCancellation(
                subscriptionRef: "sub-1",
                merchantName: "Tonebox",
                method: .concierge
            )
        }
        #expect(try await client.listCancellations().isEmpty)
    }

    // MARK: - FinanceKitLinkPresenter

    @MainActor
    @Test func authorizedGrantReadsAsLinked() async throws {
        let presenter = FinanceKitLinkPresenter(store: MockFinancialDataStore(status: .authorized))

        let result = try await presenter.link(with: "on-device", institutionName: nil)

        #expect(result == .success(publicToken: "on-device"))
    }

    @MainActor
    @Test func deniedGrantReadsAsCancelled() async throws {
        let presenter = FinanceKitLinkPresenter(store: MockFinancialDataStore(status: .denied))

        let result = try await presenter.link(with: "on-device", institutionName: nil)

        #expect(result == .cancelled)
    }

    @MainActor
    @Test func unavailableDeviceThrows() async {
        let presenter = FinanceKitLinkPresenter(store: MockFinancialDataStore(available: false))

        await #expect(throws: SiftError.self) {
            _ = try await presenter.link(with: "on-device", institutionName: nil)
        }
    }
}
