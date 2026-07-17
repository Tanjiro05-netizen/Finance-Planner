import Foundation
@testable import Sift
import Testing

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
            date: referenceDate.addingTimeInterval(TimeInterval(-daysAgo * 86400)),
            isPending: isPending,
            isDebit: isDebit
        )
    }

    // MARK: - Mapper

    @Test func minorUnitsRoundsToCents() throws {
        #expect(try FinancialDataMapper.minorUnits(from: #require(Decimal(string: "15.49"))) == 1549)
        #expect(try FinancialDataMapper.minorUnits(from: #require(Decimal(string: "9.999"))) == 1000)
        #expect(try FinancialDataMapper.minorUnits(from: #require(Decimal(string: "-12.30"))) == 1230)
        #expect(FinancialDataMapper.minorUnits(from: Decimal(0)) == 0)
    }

    @Test func remoteTransactionCarriesUserAndMagnitude() throws {
        let mapped = try FinancialDataMapper.remoteTransaction(
            from: snapshot(id: "t1", merchant: "Tonebox", amount: #require(Decimal(string: "-9.99")), daysAgo: 0),
            userID: "user-42"
        )

        #expect(mapped.id == "t1")
        #expect(mapped.userId == "user-42")
        #expect(mapped.accountId == "acct-1")
        #expect(mapped.merchantName == "Tonebox")
        #expect(mapped.amountMinor == 999)
        #expect(mapped.isoCurrency == "USD")
        #expect(mapped.category == nil)
        #expect(mapped.direction == "debit")
    }

    @Test func remoteTransactionCarriesCreditDirection() {
        let mapped = FinancialDataMapper.remoteTransaction(
            from: snapshot(id: "t2", merchant: "Payroll", amount: 500, daysAgo: 0, isDebit: false),
            userID: "user-42"
        )

        #expect(mapped.direction == "credit")
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

    @Test func remoteAccountCarriesBalanceWhenPresent() throws {
        let withBalance = FinancialDataMapper.remoteAccount(from: FinancialAccountSnapshot(
            id: "a3",
            displayName: "Apple Card",
            institutionName: "Goldman Sachs",
            currencyCode: "USD",
            isLiability: true,
            currentBalance: try #require(Decimal(string: "125.50")),
            availableBalance: try #require(Decimal(string: "874.50"))
        ))
        let withoutBalance = FinancialDataMapper.remoteAccount(from: FinancialAccountSnapshot(
            id: "a4", displayName: "Apple Cash", institutionName: "Apple", currencyCode: "USD", isLiability: false
        ))

        #expect(withBalance.currentBalanceMinor == 12550)
        #expect(withBalance.availableBalanceMinor == 87450)
        #expect(withBalance.isoCurrency == "USD")
        #expect(withoutBalance.currentBalanceMinor == nil)
        #expect(withoutBalance.availableBalanceMinor == nil)
    }

    @Test func minorUnitsRespectsCurrencyScale() throws {
        #expect(try FinancialDataMapper.minorUnits(from: #require(Decimal(string: "1500")), currencyCode: "JPY") == 1500)
        #expect(try FinancialDataMapper.minorUnits(from: #require(Decimal(string: "15.49")), currencyCode: "USD") == 1549)
        #expect(try FinancialDataMapper.minorUnits(from: #require(Decimal(string: "1.234")), currencyCode: "BHD") == 1234)
        #expect(FinancialDataMapper.fractionDigits(for: "jpy") == 0)
        #expect(FinancialDataMapper.fractionDigits(for: "kwd") == 3)
        #expect(FinancialDataMapper.fractionDigits(for: "eur") == 2)
    }

    @Test func linkedAccountFromRemoteCarriesFields() {
        let remote = RemoteAccount(
            id: "a1", plaidItemId: "a1", institutionName: "Apple",
            mask: nil, name: "Apple Card", type: "credit", status: "active"
        )
        let account = LinkedAccount(remote: remote, userID: "user-1")

        #expect(account.id == "a1")
        #expect(account.userID == "user-1")
        #expect(account.institutionName == "Apple")
        #expect(account.mask == "")
        #expect(account.status == .connected)
        #expect(account.currentBalance == nil)
        #expect(account.balanceAsOf == nil)
    }

    @Test func linkedAccountFromRemoteCarriesBalance() {
        let syncedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let remote = RemoteAccount(
            id: "a1", plaidItemId: "a1", institutionName: "Apple",
            mask: nil, name: "Apple Card", type: "credit", status: "active",
            currentBalanceMinor: 12550, availableBalanceMinor: 87450, isoCurrency: "USD"
        )
        let account = LinkedAccount(remote: remote, userID: "user-1", syncedAt: syncedAt)

        #expect(account.currentBalance == Money.usd(12550))
        #expect(account.availableBalance == Money.usd(87450))
        #expect(account.balanceAsOf == syncedAt)
    }

    // MARK: - Incremental sync window

    @Test func syncWindowFullLookbackWhenNoPriorSync() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let start = FinancialSyncWindow.startDate(lastSync: nil, now: now)
        #expect(start == now.addingTimeInterval(-FinancialSyncWindow.fullLookback))
    }

    @Test func syncWindowUsesOverlapAfterPriorSync() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let last = now.addingTimeInterval(-10 * 86400)
        let start = FinancialSyncWindow.startDate(lastSync: last, now: now)
        #expect(start == last.addingTimeInterval(-FinancialSyncWindow.overlap))
    }

    @Test func userDefaultsSyncStateRoundTrips() throws {
        let defaults = try #require(UserDefaults(suiteName: "sift-test-\(UUID().uuidString)"))
        let state = UserDefaultsFinancialSyncState(defaults: defaults)

        #expect(state.lastSyncDate == nil)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        state.recordSync(at: now)
        #expect(state.lastSyncDate == now)
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

    @Test func syncReportsAvailableLedgerRowCount() async throws {
        // added now counts every ledger row (debits and credits), not just subscription-
        // eligible charges: the ledger wants the full picture, and subscription detection
        // reads its own debit-only path downstream, not this count.
        let store = MockFinancialDataStore(transactions: [
            snapshot(id: "t1", merchant: "A", amount: 5, daysAgo: 1),
            snapshot(id: "t2", merchant: "B", amount: 6, daysAgo: 2),
            snapshot(id: "credit", merchant: "C", amount: 6, daysAgo: 3, isDebit: false),
        ])
        let client = FinanceKitAPIClient(store: store, userID: "user-1")

        let response = try await client.syncTransactions()

        #expect(response.added == 3)
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

    @Test func listTransactionsIncludesCredits() async throws {
        let store = MockFinancialDataStore(transactions: [
            snapshot(id: "t1", merchant: "A", amount: 5, daysAgo: 1),
            snapshot(id: "credit", merchant: "B", amount: 6, daysAgo: 2, isDebit: false),
        ])
        let client = FinanceKitAPIClient(store: store, userID: "user-1")

        let rows = try await client.listTransactions(limit: 50, offset: 0)

        #expect(rows.map(\.id).sorted() == ["credit", "t1"])
        #expect(rows.first { $0.id == "credit" }?.direction == "credit")
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
