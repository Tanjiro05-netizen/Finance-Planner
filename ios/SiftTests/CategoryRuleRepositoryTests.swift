import Foundation
@testable import Sift
import SwiftData
import Testing

@MainActor
struct CategoryRuleRepositoryTests {
    /// A suite per call. Rules live in `UserDefaults`, so without isolation these tests
    /// would share one process-wide blob with each other and with the simulator's real
    /// defaults, and would pass or fail depending on execution order.
    private func isolatedRules() throws -> any CategoryRuleRepository {
        let defaults = try #require(UserDefaults(suiteName: "sift-rules-\(UUID().uuidString)"))
        return UserDefaultsCategoryRuleRepository(defaults: defaults)
    }

    /// Holds the `ModelContainer`, which is the entire point of this struct.
    ///
    /// The previous version of this helper returned only the repositories and let the
    /// container go out of scope. Nothing else retained it, so it deallocated the moment
    /// the helper returned and left `mainContext` dangling -- every SwiftData call after
    /// that was a use-after-free, which traps with a silent EXC_BREAKPOINT carrying no
    /// message. Every other repository suite here keeps a `Fixture` with a `container`
    /// field for exactly this reason.
    private struct Fixture {
        let container: ModelContainer
        let repository: any CategoryRuleRepository
        let repositories: RepositoryContainer
    }

    private func makeFixture() throws -> Fixture {
        let container = try SiftModelContainerFactory.makeSeededInMemoryContainer()
        let repositories = try RepositoryContainer.live(
            modelContext: container.mainContext,
            categoryRules: isolatedRules()
        )
        return Fixture(
            container: container,
            repository: repositories.categoryRules,
            repositories: repositories
        )
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
        let fixture = try makeFixture()
        let repository = fixture.repository
        #expect(try repository.all().isEmpty)
    }

    @Test func insertAndFetchRoundTrips() throws {
        let fixture = try makeFixture()
        let repository = fixture.repository
        try repository.insert(rule(id: "r1", pattern: "GROCERY", sortIndex: 0))

        let fetched = try #require(try repository.rule(id: "r1"))
        #expect(fetched.pattern == "GROCERY")
        #expect(fetched.kind == .merchantContains)
        #expect(fetched.isEnabled)
    }

    @Test func allReturnsEvaluationOrderNotInsertionOrder() throws {
        let fixture = try makeFixture()
        let repository = fixture.repository
        try repository.insert(rule(id: "third", pattern: "C", sortIndex: 2))
        try repository.insert(rule(id: "first", pattern: "A", sortIndex: 0))
        try repository.insert(rule(id: "second", pattern: "B", sortIndex: 1))

        #expect(try repository.all().map(\.id) == ["first", "second", "third"])
    }

    @Test func reorderRewritesOrderDenselyFromArrayPosition() throws {
        let fixture = try makeFixture()
        let repository = fixture.repository
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
        let fixture = try makeFixture()
        let repository = fixture.repository
        try repository.insert(rule(id: "keep", pattern: "A", sortIndex: 0))
        try repository.insert(rule(id: "drop", pattern: "B", sortIndex: 1))

        try repository.delete(id: "drop")

        #expect(try repository.all().map(\.id) == ["keep"])
    }

    @Test func deleteThrowsForAnUnknownRule() throws {
        let fixture = try makeFixture()
        let repository = fixture.repository
        #expect(throws: SiftError.self) {
            try repository.delete(id: "missing")
        }
    }

    @Test func rulesAreScopedToTheirUser() throws {
        let container = try SiftModelContainerFactory.makeSeededInMemoryContainer()
        // One shared defaults suite, two users -- which is the point of the test.
        let defaults = try #require(UserDefaults(suiteName: "sift-rules-\(UUID().uuidString)"))
        let mine = RepositoryContainer.live(
            modelContext: container.mainContext,
            categoryRules: UserDefaultsCategoryRuleRepository(defaults: defaults)
        )
        let theirs = RepositoryContainer.live(
            modelContext: container.mainContext,
            userID: "someone-else",
            categoryRules: UserDefaultsCategoryRuleRepository(defaults: defaults, userID: "someone-else")
        )

        try mine.categoryRules.insert(rule(id: "mine", pattern: "A", sortIndex: 0))

        #expect(try mine.categoryRules.all().map(\.id) == ["mine"])
        #expect(try theirs.categoryRules.all().isEmpty)
    }

    /// Rules are financial data. "Delete everything" has to mean it.
    @Test func wipeLocalDataClearsRules() throws {
        let fixture = try makeFixture()
        let repository = fixture.repository
        let repositories = fixture.repositories
        try repository.insert(rule(id: "r1", pattern: "GROCERY", sortIndex: 0))

        try repositories.wipeLocalData()

        #expect(try repository.all().isEmpty)
    }
}
