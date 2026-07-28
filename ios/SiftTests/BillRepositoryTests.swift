import Foundation
@testable import Sift
import SwiftData
import Testing

@MainActor
struct BillRepositoryTests {
    private let referenceDate = Date(timeIntervalSince1970: 1_720_000_000)

    /// The fixture holds the container: a repository keeps only the `ModelContext`, so
    /// letting the container go out of scope leaves the context without a live store and
    /// the next write traps inside SwiftData.
    private struct Fixture {
        let container: ModelContainer
        let repository: LiveBillRepository
    }

    private func makeFixture() throws -> Fixture {
        let container = try SiftModelContainerFactory.makeContainer(inMemory: true)
        return Fixture(
            container: container,
            repository: LiveBillRepository(modelContext: container.mainContext)
        )
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
        let fixture = try makeFixture()
        try fixture.repository.insert(bill(id: "bill-1", nextDue: referenceDate.addingTimeInterval(10 * 86400)))

        #expect(try fixture.repository.all().count == 1)
        let fetched = try #require(try fixture.repository.bill(id: "bill-1"))
        #expect(fetched.name == "Rent")

        fetched.name = "New Rent"
        try fixture.repository.update(fetched)
        #expect(try fixture.repository.bill(id: "bill-1")?.name == "New Rent")

        try fixture.repository.delete(id: "bill-1")
        #expect(try fixture.repository.all().isEmpty)
    }

    @Test func upcomingBillsFilterByWindowAndStatus() throws {
        let fixture = try makeFixture()
        try fixture.repository.insert(bill(id: "in", name: "Rent", nextDue: referenceDate.addingTimeInterval(5 * 86400)))
        try fixture.repository.insert(bill(id: "beyond", name: "Insurance", nextDue: referenceDate.addingTimeInterval(60 * 86400)))
        try fixture.repository.insert(bill(
            id: "stopped",
            name: "Old Loan",
            nextDue: referenceDate.addingTimeInterval(3 * 86400),
            status: .stopped
        ))

        let upcoming = try fixture.repository.upcomingBills(from: referenceDate, to: referenceDate.addingTimeInterval(30 * 86400))
        #expect(upcoming.map(\.id) == ["in"])
    }
}
