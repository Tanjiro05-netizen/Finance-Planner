import Foundation
@testable import Sift
import SwiftData
import Testing

@MainActor
struct BudgetRepositoryTests {
    /// The fixture holds the container: a repository keeps only the `ModelContext`, so
    /// letting the container go out of scope leaves the context without a live store and
    /// the next write traps inside SwiftData.
    private struct Fixture {
        let container: ModelContainer
        let repository: LiveBudgetRepository
    }

    private func makeFixture() throws -> Fixture {
        let container = try SiftModelContainerFactory.makeContainer(inMemory: true)
        return Fixture(
            container: container,
            repository: LiveBudgetRepository(modelContext: container.mainContext)
        )
    }

    private func budget(id: String, categoryID: String, status: BudgetStatus = .active) -> Budget {
        Budget(
            id: id,
            userID: SeedData.defaultUserID,
            categoryID: categoryID,
            amount: .usd(40000),
            period: .monthly,
            rolloverEnabled: false,
            startDate: Date(timeIntervalSince1970: 1_720_000_000),
            status: status
        )
    }

    @Test func insertReadUpdateDelete() throws {
        let fixture = try makeFixture()
        try fixture.repository.insert(budget(id: "b1", categoryID: "cat-groceries"))

        #expect(try fixture.repository.all().count == 1)
        let fetched = try #require(try fixture.repository.budget(id: "b1"))
        #expect(fetched.amount == .usd(40000))

        fetched.amount = .usd(50000)
        try fixture.repository.update(fetched)
        #expect(try fixture.repository.budget(id: "b1")?.amount == .usd(50000))

        try fixture.repository.delete(id: "b1")
        #expect(try fixture.repository.all().isEmpty)
    }

    @Test func budgetForCategoryReturnsOnlyTheActiveOne() throws {
        let fixture = try makeFixture()
        try fixture.repository.insert(budget(id: "archived", categoryID: "cat-groceries", status: .archived))
        try fixture.repository.insert(budget(id: "active", categoryID: "cat-groceries"))

        #expect(try fixture.repository.budget(forCategory: "cat-groceries")?.id == "active")
        #expect(try fixture.repository.budget(forCategory: "cat-dining") == nil)
    }

    @Test func deleteUnknownBudgetThrows() throws {
        let fixture = try makeFixture()

        #expect(throws: SiftError.self) {
            try fixture.repository.delete(id: "missing")
        }
    }

    @Test func deleteAllClearsTheUserScopedRows() throws {
        let fixture = try makeFixture()
        try fixture.repository.insert(budget(id: "b1", categoryID: "cat-groceries"))
        try fixture.repository.insert(budget(id: "b2", categoryID: "cat-dining"))

        try fixture.repository.deleteAll()

        #expect(try fixture.repository.all().isEmpty)
    }
}
