import Foundation
@testable import Sift
import SwiftData
import Testing

@MainActor
struct GoalRepositoryTests {
    /// The fixture holds the container: a repository keeps only the `ModelContext`, so
    /// letting the container go out of scope leaves the context without a live store and
    /// the next write traps inside SwiftData.
    private struct Fixture {
        let container: ModelContainer
        let repository: LiveGoalRepository
    }

    private func makeFixture() throws -> Fixture {
        let container = try SiftModelContainerFactory.makeContainer(inMemory: true)
        return Fixture(
            container: container,
            repository: LiveGoalRepository(modelContext: container.mainContext)
        )
    }

    private func goal(id: String, created: TimeInterval = 0) -> Goal {
        Goal(
            id: id,
            userID: SeedData.defaultUserID,
            name: "Emergency fund",
            targetAmount: .usd(300_000),
            createdAt: Date(timeIntervalSince1970: 1_720_000_000 + created)
        )
    }

    private func contribution(id: String, goalID: String, cents: Int) -> GoalContribution {
        GoalContribution(
            id: id,
            userID: SeedData.defaultUserID,
            goalID: goalID,
            amount: .usd(cents),
            date: Date(timeIntervalSince1970: 1_720_000_000)
        )
    }

    @Test func insertReadUpdateDelete() throws {
        let fixture = try makeFixture()
        try fixture.repository.insert(goal(id: "g1"))

        #expect(try fixture.repository.all().count == 1)
        let fetched = try #require(try fixture.repository.goal(id: "g1"))
        #expect(fetched.targetAmount == .usd(300_000))

        fetched.name = "Rainy day"
        try fixture.repository.update(fetched)
        #expect(try fixture.repository.goal(id: "g1")?.name == "Rainy day")

        try fixture.repository.delete(id: "g1")
        #expect(try fixture.repository.all().isEmpty)
    }

    @Test func goalsAreSortedNewestFirst() throws {
        let fixture = try makeFixture()
        try fixture.repository.insert(goal(id: "older", created: 0))
        try fixture.repository.insert(goal(id: "newer", created: 86400))

        #expect(try fixture.repository.all().map(\.id) == ["newer", "older"])
    }

    @Test func contributionsAreScopedToTheirGoal() throws {
        let fixture = try makeFixture()
        try fixture.repository.insert(goal(id: "g1"))
        try fixture.repository.insert(goal(id: "g2"))
        try fixture.repository.addContribution(contribution(id: "c1", goalID: "g1", cents: 5000))
        try fixture.repository.addContribution(contribution(id: "c2", goalID: "g2", cents: 7000))

        #expect(try fixture.repository.contributions(forGoal: "g1").map(\.id) == ["c1"])
        #expect(try fixture.repository.contributions(forGoal: "g2").map(\.id) == ["c2"])
    }

    @Test func withdrawalsPersistAsNegativeAmounts() throws {
        let fixture = try makeFixture()
        try fixture.repository.insert(goal(id: "g1"))
        try fixture.repository.addContribution(contribution(id: "in", goalID: "g1", cents: 5000))
        try fixture.repository.addContribution(contribution(id: "out", goalID: "g1", cents: -2000))

        let saved = GoalProjector.saved(from: try fixture.repository.contributions(forGoal: "g1"))
        #expect(saved == .usd(3000))
    }

    @Test func deletingAGoalRemovesItsContributions() throws {
        let fixture = try makeFixture()
        try fixture.repository.insert(goal(id: "g1"))
        try fixture.repository.addContribution(contribution(id: "c1", goalID: "g1", cents: 5000))

        try fixture.repository.delete(id: "g1")

        // Orphaned contributions would be unreachable and undeletable.
        #expect(try fixture.repository.contributions(forGoal: "g1").isEmpty)
    }

    @Test func deleteContributionRemovesOnlyThatEntry() throws {
        let fixture = try makeFixture()
        try fixture.repository.insert(goal(id: "g1"))
        try fixture.repository.addContribution(contribution(id: "c1", goalID: "g1", cents: 5000))
        try fixture.repository.addContribution(contribution(id: "c2", goalID: "g1", cents: 2000))

        try fixture.repository.deleteContribution(id: "c1")

        #expect(try fixture.repository.contributions(forGoal: "g1").map(\.id) == ["c2"])
    }

    @Test func deleteUnknownGoalThrows() throws {
        let fixture = try makeFixture()

        #expect(throws: SiftError.self) {
            try fixture.repository.delete(id: "missing")
        }
    }

    @Test func deleteUnknownContributionThrows() throws {
        let fixture = try makeFixture()

        #expect(throws: SiftError.self) {
            try fixture.repository.deleteContribution(id: "missing")
        }
    }

    @Test func deleteAllClearsGoalsAndContributions() throws {
        let fixture = try makeFixture()
        try fixture.repository.insert(goal(id: "g1"))
        try fixture.repository.addContribution(contribution(id: "c1", goalID: "g1", cents: 5000))

        try fixture.repository.deleteAll()

        #expect(try fixture.repository.all().isEmpty)
        #expect(try fixture.repository.contributions(forGoal: "g1").isEmpty)
    }
}
