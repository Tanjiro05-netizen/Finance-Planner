import Foundation
@testable import Sift
import SwiftData
import Testing

@MainActor
struct CategoryRuleRepositoryTests {
    private func makeRepository() throws -> (any CategoryRuleRepository, RepositoryContainer) {
        let container = try SiftModelContainerFactory.makeSeededInMemoryContainer()
        let repositories = RepositoryContainer.live(modelContext: container.mainContext)
        return (repositories.categoryRules, repositories)
    }

    private func rule(id: String, pattern: String, sortIndex: Int) -> CategoryRule {
        CategoryRule(
            id: id,
            userID: SeedData.defaultUserID,
            kind: .merchantContains,
            pattern: pattern,
            categoryID: SeedData.ID.dining,
            sortIndex: sortIndex
        )
    }

    /// §6 of the plan: seeding rules would re-run over the seeded ledger and move the
    /// value-pinned budget assertions. Asserted so nobody adds one casually.
    @Test func seededStoreShipsWithNoRules() throws {
        let (repository, _) = try makeRepository()
        #expect(try repository.all().isEmpty)
    }

    @Test func insertAndFetchRoundTrips() throws {
        let (repository, _) = try makeRepository()
        try repository.insert(rule(id: "r1", pattern: "GROCERY", sortIndex: 0))

        let fetched = try #require(try repository.rule(id: "r1"))
        #expect(fetched.pattern == "GROCERY")
        #expect(fetched.kind == .merchantContains)
        #expect(fetched.isEnabled)
    }

    @Test func allReturnsEvaluationOrderNotInsertionOrder() throws {
        let (repository, _) = try makeRepository()
        try repository.insert(rule(id: "third", pattern: "C", sortIndex: 2))
        try repository.insert(rule(id: "first", pattern: "A", sortIndex: 0))
        try repository.insert(rule(id: "second", pattern: "B", sortIndex: 1))

        #expect(try repository.all().map(\.id) == ["first", "second", "third"])
    }

    @Test func reorderRewritesOrderDenselyFromArrayPosition() throws {
        let (repository, _) = try makeRepository()
        try repository.insert(rule(id: "a", pattern: "A", sortIndex: 0))
        try repository.insert(rule(id: "b", pattern: "B", sortIndex: 1))
        try repository.insert(rule(id: "c", pattern: "C", sortIndex: 2))

        try repository.reorder(ids: ["c", "a", "b"])

        let reordered = try repository.all()
        #expect(reordered.map(\.id) == ["c", "a", "b"])
        // Dense and zero-based, so a later drag can't produce ties.
        #expect(reordered.map(\.sortIndex) == [0, 1, 2])
    }

    @Test func deleteRemovesOnlyTheNamedRule() throws {
        let (repository, _) = try makeRepository()
        try repository.insert(rule(id: "keep", pattern: "A", sortIndex: 0))
        try repository.insert(rule(id: "drop", pattern: "B", sortIndex: 1))

        try repository.delete(id: "drop")

        #expect(try repository.all().map(\.id) == ["keep"])
    }

    @Test func deleteThrowsForAnUnknownRule() throws {
        let (repository, _) = try makeRepository()
        #expect(throws: SiftError.self) {
            try repository.delete(id: "missing")
        }
    }

    @Test func rulesAreScopedToTheirUser() throws {
        let container = try SiftModelContainerFactory.makeSeededInMemoryContainer()
        let mine = RepositoryContainer.live(modelContext: container.mainContext)
        let theirs = RepositoryContainer.live(modelContext: container.mainContext, userID: "someone-else")

        try mine.categoryRules.insert(rule(id: "mine", pattern: "A", sortIndex: 0))

        #expect(try mine.categoryRules.all().map(\.id) == ["mine"])
        #expect(try theirs.categoryRules.all().isEmpty)
    }

    /// Rules are financial data. "Delete everything" has to mean it.
    @Test func wipeLocalDataClearsRules() throws {
        let (repository, repositories) = try makeRepository()
        try repository.insert(rule(id: "r1", pattern: "GROCERY", sortIndex: 0))

        try repositories.wipeLocalData()

        #expect(try repository.all().isEmpty)
    }
}
