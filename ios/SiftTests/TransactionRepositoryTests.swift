import Foundation
@testable import Sift
import SwiftData
import Testing

@MainActor
struct TransactionRepositoryTests {
    @Test func transactionsInRangeExcludesOutsideDates() throws {
        let fixture = try makeFixture()

        let june = try fixture.repository.transactions(
            from: date(year: 2026, month: 6, day: 1),
            to: date(year: 2026, month: 6, day: 30)
        )

        #expect(june.map(\.id).sorted() == ["txn-creative-jun", "txn-streamline-jun", "txn-tonebox-jun"])
    }

    @Test func totalSpendAndIncomeSplitByDirection() throws {
        let fixture = try makeFixture()
        try fixture.repository.insert(makeCreditTransaction(id: "txn-payroll-jun", amount: .usd(200_000)))

        let range = (
            date(year: 2026, month: 6, day: 1),
            date(year: 2026, month: 6, day: 30)
        )
        let spend = try fixture.repository.totalSpend(from: range.0, to: range.1)
        let income = try fixture.repository.totalIncome(from: range.0, to: range.1)

        #expect(spend == Money.usd(1549 + 1299 + 5999))
        #expect(income == Money.usd(200_000))
    }

    @Test func byCategoryGroupsTransactionsAndLabelsUncategorized() throws {
        let fixture = try makeFixture()

        let groups = try fixture.repository.byCategory(
            from: date(year: 2026, month: 6, day: 1),
            to: date(year: 2026, month: 6, day: 30)
        )

        #expect(groups.count == 1)
        #expect(groups.first?.categoryID == nil)
        #expect(groups.first?.categoryName == "Uncategorized")
        #expect(groups.first?.transactions.count == 3)
    }

    @Test func byCategoryUsesRealCategoryName() throws {
        let fixture = try makeFixture()
        guard let transaction = try fixture.repository.transaction(id: "txn-streamline-jun") else {
            Issue.record("Expected seeded transaction")
            return
        }
        transaction.categoryID = SeedData.ID.streaming
        try fixture.repository.update(transaction)

        let groups = try fixture.repository.byCategory(
            from: date(year: 2026, month: 6, day: 1),
            to: date(year: 2026, month: 6, day: 30)
        )

        let streamingGroup = try #require(groups.first { $0.categoryID == SeedData.ID.streaming })
        #expect(streamingGroup.categoryName == "Streaming")
        #expect(streamingGroup.transactions.map(\.id) == ["txn-streamline-jun"])
    }

    @Test func deleteRemovesTransaction() throws {
        let fixture = try makeFixture()

        try fixture.repository.delete(id: "txn-tonebox-jun")

        #expect(try fixture.repository.transaction(id: "txn-tonebox-jun") == nil)
        #expect(try fixture.repository.all().count == 3)
    }

    @Test func deleteUnknownTransactionThrows() throws {
        let fixture = try makeFixture()

        #expect(throws: SiftError.self) {
            try fixture.repository.delete(id: "missing")
        }
    }

    @Test func upsertPreservesManuallyAssignedCategoryOnResync() throws {
        let fixture = try makeFixture()
        guard let transaction = try fixture.repository.transaction(id: "txn-streamline-jun") else {
            Issue.record("Expected seeded transaction")
            return
        }
        transaction.categoryID = SeedData.ID.security
        transaction.categoryManuallySet = true
        try fixture.repository.update(transaction)

        // Simulate a re-sync of the same row from FinanceKit: a freshly-constructed
        // transaction never carries a resolved category.
        try fixture.repository.upsert(Transaction(
            id: "txn-streamline-jun",
            userID: SeedData.defaultUserID,
            accountID: SeedData.ID.travelCard,
            merchantRaw: "STREAMLINE PLUS",
            merchantKey: MerchantKey("Streamline Plus"),
            amount: .usd(1549),
            date: date(year: 2026, month: 6, day: 12),
            categoryHint: "Streaming",
            source: .financeKit
        ))

        let resynced = try fixture.repository.transaction(id: "txn-streamline-jun")
        #expect(resynced?.categoryID == SeedData.ID.security)
        #expect(resynced?.categoryManuallySet == true)
    }

    private func makeCreditTransaction(id: String, amount: Money) -> Transaction {
        Transaction(
            id: id,
            userID: SeedData.defaultUserID,
            accountID: SeedData.ID.checking,
            merchantRaw: "Employer Inc",
            merchantKey: MerchantKey("Employer Inc"),
            amount: amount,
            date: date(year: 2026, month: 6, day: 15),
            direction: .credit,
            kind: .income,
            source: .financeKit
        )
    }

    private func makeFixture() throws -> Fixture {
        let container = try SiftModelContainerFactory.makeSeededInMemoryContainer()
        return Fixture(
            container: container,
            repository: LiveTransactionRepository(modelContext: container.mainContext)
        )
    }

    private struct Fixture {
        let container: ModelContainer
        let repository: LiveTransactionRepository
    }
}

private func date(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.calendar = Calendar.utc
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    components.hour = 12
    return components.date ?? Date(timeIntervalSince1970: 0)
}
