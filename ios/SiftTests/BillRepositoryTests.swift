import Foundation
@testable import Sift
import SwiftData
import Testing

@MainActor
struct BillRepositoryTests {
    private let referenceDate = Date(timeIntervalSince1970: 1_720_000_000)

    private func makeRepository() throws -> LiveBillRepository {
        let container = try SiftModelContainerFactory.makeContainer(inMemory: true)
        return LiveBillRepository(modelContext: container.mainContext)
    }

    private func bill(
        id: String,
        name: String = "Rent",
        nextDue: Date?,
        status: BillStatus = .active
    ) -> Bill {
        Bill(
            id: id,
            userID: SeedData.defaultUserID,
            name: name,
            merchantKey: MerchantKey(name),
            amount: .usd(185_000),
            cadence: .monthly,
            nextDue: nextDue,
            status: status,
            detectionConfidence: 0.9,
            firstSeen: referenceDate.addingTimeInterval(-120 * 86400),
            lastCharge: referenceDate.addingTimeInterval(-5 * 86400)
        )
    }

    @Test func insertReadUpdateDelete() throws {
        let repository = try makeRepository()
        try repository.insert(bill(id: "bill-1", nextDue: referenceDate.addingTimeInterval(10 * 86400)))

        #expect(try repository.all().count == 1)
        let fetched = try #require(try repository.bill(id: "bill-1"))
        #expect(fetched.name == "Rent")

        fetched.name = "New Rent"
        try repository.update(fetched)
        #expect(try repository.bill(id: "bill-1")?.name == "New Rent")

        try repository.delete(id: "bill-1")
        #expect(try repository.all().isEmpty)
    }

    @Test func upcomingBillsFilterByWindowAndStatus() throws {
        let repository = try makeRepository()
        try repository.insert(bill(id: "in", name: "Rent", nextDue: referenceDate.addingTimeInterval(5 * 86400)))
        try repository.insert(bill(id: "beyond", name: "Insurance", nextDue: referenceDate.addingTimeInterval(60 * 86400)))
        try repository.insert(bill(id: "stopped", name: "Old Loan", nextDue: referenceDate.addingTimeInterval(3 * 86400), status: .stopped))

        let upcoming = try repository.upcomingBills(from: referenceDate, to: referenceDate.addingTimeInterval(30 * 86400))
        #expect(upcoming.map(\.id) == ["in"])
    }
}
