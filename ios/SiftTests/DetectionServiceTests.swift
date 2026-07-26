import Foundation
@testable import Sift
import SwiftData
import Testing

@MainActor
struct DetectionServiceTests {
    @Test func recomputePersistsCandidateAndPriceChange() async throws {
        let container = try SiftModelContainerFactory.makeContainer(inMemory: true)
        try insertTransactions(
            monthlyPersistentSeries(
                merchant: "STREAMLINE PLUS",
                amountByIndex: { index in index < 3 ? 1199 : 1399 },
                firstCharge: date(2026, 1, 1),
                count: 6
            ),
            into: container
        )
        let service = LiveDetectionService(modelContainer: container)

        let result = try await service.recompute(referenceDate: date(2026, 6, 15))

        let subscriptions = try fetchSubscriptions(in: container)
        let priceChanges = try fetchPriceChanges(in: container)
        #expect(result.candidates.count == 1)
        #expect(subscriptions.count == 1)
        #expect(subscriptions[0].amount == .usd(1399))
        #expect(priceChanges.count == 1)
        #expect(priceChanges[0].oldAmount == .usd(1199))
        #expect(priceChanges[0].newAmount == .usd(1399))
    }

    @Test func rerunUpdatesExistingSubscriptionWithoutDuplicate() async throws {
        let container = try SiftModelContainerFactory.makeContainer(inMemory: true)
        try insertTransactions(
            monthlyPersistentSeries(
                merchant: "NETFLIX",
                amountByIndex: { _ in 1549 },
                firstCharge: date(2026, 1, 15),
                count: 3
            ),
            into: container
        )
        let service = LiveDetectionService(modelContainer: container)
        _ = try await service.recompute(referenceDate: date(2026, 4, 1))

        try insertTransactions([
            transaction(
                id: "netflix-3",
                merchant: "NETFLIX",
                amount: 1549,
                date: date(2026, 4, 15)
            ),
        ], into: container)
        _ = try await service.recompute(referenceDate: date(2026, 5, 1))

        let subscriptions = try fetchSubscriptions(in: container)
        #expect(subscriptions.count == 1)
        #expect(subscriptions[0].lastCharge == date(2026, 4, 15))
        #expect(subscriptions[0].nextRenewal == date(2026, 5, 15))
    }

    @Test func stoppedStreamMarksExistingSubscriptionCancelled() async throws {
        let container = try SiftModelContainerFactory.makeContainer(inMemory: true)
        let context = container.mainContext
        context.insert(Subscription(
            id: "sub-quiet-app",
            userID: SeedData.defaultUserID,
            name: "Quiet App",
            merchantKey: MerchantKey("Quiet App"),
            monogramLetter: "Q",
            tileColorToken: .ink,
            amount: .usd(999),
            cadence: .monthly,
            nextRenewal: date(2026, 2, 15),
            lastUsed: nil,
            categoryID: nil,
            status: .active,
            detectionConfidence: 0.91,
            firstSeen: date(2025, 9, 15),
            lastCharge: date(2026, 1, 15)
        ))
        try context.save()

        let service = LiveDetectionService(modelContainer: container)
        _ = try await service.recompute(referenceDate: date(2026, 4, 15))

        let subscriptions = try fetchSubscriptions(in: container)
        #expect(subscriptions.count == 1)
        #expect(subscriptions[0].status == .cancelled)
        #expect(subscriptions[0].nextRenewal == nil)
    }

    @Test func creditTransactionsAreExcludedFromDetection() async throws {
        // Regression check: once the ledger stopped dropping credits, transactionInputs
        // needed an explicit direction filter, since amount.amountMinor >= 0 is always
        // true (amounts are unsigned magnitudes) and was never actually filtering credits.
        let container = try SiftModelContainerFactory.makeContainer(inMemory: true)
        try insertTransactions(
            monthlyPersistentSeries(
                merchant: "REFUND CO",
                amountByIndex: { _ in 1999 },
                firstCharge: date(2026, 1, 1),
                count: 6,
                direction: .credit
            ),
            into: container
        )
        let service = LiveDetectionService(modelContainer: container)

        let result = try await service.recompute(referenceDate: date(2026, 6, 15))

        let subscriptions = try fetchSubscriptions(in: container)
        #expect(result.candidates.isEmpty)
        #expect(subscriptions.isEmpty)
    }

    @Test func recomputeIncomePersistsBiweeklyPayroll() async throws {
        let container = try SiftModelContainerFactory.makeContainer(inMemory: true)
        let payroll = (0 ..< 6).map { index -> Transaction in
            transaction(
                id: "pay-\(index)",
                merchant: "NORTHWIND LABS PAYROLL",
                amount: 210_000,
                date: Calendar.utc.date(byAdding: .day, value: index * 14, to: date(2026, 1, 2)) ?? date(2026, 1, 2),
                direction: .credit
            )
        }
        try insertTransactions(payroll, into: container)
        let service = LiveIncomeDetectionService(modelContainer: container)

        let result = try await service.recompute(referenceDate: date(2026, 5, 1))

        #expect(result.candidates.count == 1)
        let incomes = try fetchRecurringIncome(in: container)
        #expect(incomes.count == 1)
        #expect(incomes[0].cadence == .biweekly)
        #expect(incomes[0].status == .active)
    }

    @Test func recurringDebitWithBillKeywordRoutesToBillNotSubscription() async throws {
        let container = try SiftModelContainerFactory.makeContainer(inMemory: true)
        try insertTransactions(
            monthlyPersistentSeries(
                merchant: "NORTHGATE APARTMENTS RENT",
                amountByIndex: { _ in 185_000 },
                firstCharge: date(2026, 1, 1),
                count: 6
            ),
            into: container
        )
        let service = LiveDetectionService(modelContainer: container)

        let result = try await service.recompute(referenceDate: date(2026, 6, 15))

        #expect(result.candidates.isEmpty)
        #expect(try fetchSubscriptions(in: container).isEmpty)
        let bills = try fetchBills(in: container)
        #expect(bills.count == 1)
        #expect(bills[0].cadence == .monthly)
        #expect(bills[0].status == .active)
    }
}

private func monthlyPersistentSeries(
    merchant: String,
    amountByIndex: (Int) -> Int,
    firstCharge: Date,
    count: Int,
    direction: TransactionDirection = .debit
) -> [Transaction] {
    (0 ..< count).map { index in
        transaction(
            id: "\(merchant)-\(index)",
            merchant: merchant,
            amount: amountByIndex(index),
            date: Calendar.utc.date(byAdding: .month, value: index, to: firstCharge) ?? firstCharge,
            direction: direction
        )
    }
}

@MainActor
private func insertTransactions(_ transactions: [Transaction], into container: ModelContainer) throws {
    let context = container.mainContext
    transactions.forEach(context.insert)
    try context.save()
}

private func transaction(
    id: String,
    merchant: String,
    amount: Int,
    date: Date,
    direction: TransactionDirection = .debit
) -> Transaction {
    Transaction(
        id: id,
        userID: SeedData.defaultUserID,
        accountID: SeedData.ID.checking,
        merchantRaw: merchant,
        merchantKey: MerchantKey(merchant),
        amount: .usd(amount),
        date: date,
        direction: direction
    )
}

private func fetchSubscriptions(in container: ModelContainer) throws -> [Subscription] {
    let context = ModelContext(container)
    return try context.fetch(FetchDescriptor<Subscription>())
        .filter { $0.userID == SeedData.defaultUserID }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
}

private func fetchPriceChanges(in container: ModelContainer) throws -> [PriceChange] {
    let context = ModelContext(container)
    return try context.fetch(FetchDescriptor<PriceChange>())
        .filter { $0.userID == SeedData.defaultUserID }
}

private func fetchRecurringIncome(in container: ModelContainer) throws -> [RecurringIncome] {
    let context = ModelContext(container)
    return try context.fetch(FetchDescriptor<RecurringIncome>())
        .filter { $0.userID == SeedData.defaultUserID }
}

private func fetchBills(in container: ModelContainer) throws -> [Bill] {
    let context = ModelContext(container)
    return try context.fetch(FetchDescriptor<Bill>())
        .filter { $0.userID == SeedData.defaultUserID }
}

private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var components = DateComponents()
    components.calendar = Calendar.utc
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    components.hour = 12
    return components.date ?? Date(timeIntervalSince1970: 0)
}
