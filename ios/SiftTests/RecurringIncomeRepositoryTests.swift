import Foundation
@testable import Sift
import SwiftData
import Testing

@MainActor
struct RecurringIncomeRepositoryTests {
    private let referenceDate = Date(timeIntervalSince1970: 1_720_000_000)

    private func makeRepository() throws -> LiveRecurringIncomeRepository {
        let container = try SiftModelContainerFactory.makeContainer(inMemory: true)
        return LiveRecurringIncomeRepository(modelContext: container.mainContext)
    }

    private func income(
        id: String,
        source: String = "Employer",
        nextExpected: Date?,
        status: RecurringIncomeStatus = .active
    ) -> RecurringIncome {
        RecurringIncome(
            id: id,
            userID: SeedData.defaultUserID,
            sourceName: source,
            merchantKey: MerchantKey(source),
            amount: .usd(200_000),
            cadence: .biweekly,
            nextExpected: nextExpected,
            status: status,
            detectionConfidence: 0.9,
            firstSeen: referenceDate.addingTimeInterval(-90 * 86400),
            lastReceived: referenceDate.addingTimeInterval(-2 * 86400)
        )
    }

    @Test func insertReadUpdateDelete() throws {
        let repository = try makeRepository()
        let row = income(id: "inc-1", nextExpected: referenceDate.addingTimeInterval(5 * 86400))
        try repository.insert(row)

        #expect(try repository.all().count == 1)
        let fetched = try #require(try repository.recurringIncome(id: "inc-1"))
        #expect(fetched.sourceName == "Employer")

        fetched.sourceName = "New Employer"
        try repository.update(fetched)
        #expect(try repository.recurringIncome(id: "inc-1")?.sourceName == "New Employer")

        try repository.delete(id: "inc-1")
        #expect(try repository.all().isEmpty)
    }

    @Test func nextExpectedIncomeReturnsSoonestActiveFutureRow() throws {
        let repository = try makeRepository()
        try repository.insert(income(id: "past", nextExpected: referenceDate.addingTimeInterval(-3 * 86400)))
        try repository.insert(income(id: "far", source: "Far", nextExpected: referenceDate.addingTimeInterval(20 * 86400)))
        try repository.insert(income(id: "soon", source: "Soon", nextExpected: referenceDate.addingTimeInterval(4 * 86400)))
        try repository.insert(income(
            id: "stopped",
            source: "Stopped",
            nextExpected: referenceDate.addingTimeInterval(1 * 86400),
            status: .stopped
        ))

        let next = try repository.nextExpectedIncome(after: referenceDate)
        #expect(next?.id == "soon")
    }

    @Test func nextExpectedIncomeIsNilWhenNoneUpcoming() throws {
        let repository = try makeRepository()
        try repository.insert(income(id: "past", nextExpected: referenceDate.addingTimeInterval(-3 * 86400)))
        #expect(try repository.nextExpectedIncome(after: referenceDate) == nil)
    }
}
