import Foundation
@testable import Sift
import SwiftData
import Testing

@MainActor
struct CategoryServiceTests {
    @Test func autoCategoriseMapsKnownMerchants() throws {
        let repositories = RepositoryContainer.mock()
        let subscription = try #require(try repositories.subscriptions.subscription(id: SeedData.ID.figma))
        subscription.categoryID = nil
        subscription.categoryManuallySet = false
        try repositories.subscriptions.update(subscription)

        try CategoryService(repositories: repositories).applyAutoCategorizationIfEnabled()

        let updated = try #require(try repositories.subscriptions.subscription(id: SeedData.ID.figma))
        let design = try #require(try repositories.categories.category(id: SeedData.ID.design))
        #expect(updated.categoryID == design.id)
    }

    @Test func manualOverrideSurvivesAutoCategorisation() throws {
        let repositories = RepositoryContainer.mock()
        let service = CategoryService(repositories: repositories)

        try service.manuallyAssign(subscriptionID: SeedData.ID.streamline, categoryID: SeedData.ID.health)
        try service.applyAutoCategorizationIfEnabled()

        let subscription = try #require(try repositories.subscriptions.subscription(id: SeedData.ID.streamline))
        #expect(subscription.categoryID == SeedData.ID.health)
        #expect(subscription.categoryManuallySet)
    }

    @Test func applyAutoCategorizationForTransactionsSetsMatchingCategory() throws {
        let fixture = try makeFixture()

        try fixture.service.applyAutoCategorizationForTransactions()

        let transaction = try #require(try fixture.repositories.transactions.transaction(id: SeedData.ID.streamlineTransaction))
        let category = try #require(transaction.categoryID.flatMap { try? fixture.repositories.categories.category(id: $0) })
        #expect(category.name == "Streaming")
        #expect(transaction.categoryManuallySet == false)
    }

    @Test func applyAutoCategorizationForTransactionsNeverOverwritesManualAssignment() throws {
        let fixture = try makeFixture()

        try fixture.service.manuallyAssign(transactionID: SeedData.ID.streamlineTransaction, categoryID: SeedData.ID.security)
        try fixture.service.applyAutoCategorizationForTransactions()

        let transaction = try #require(try fixture.repositories.transactions.transaction(id: SeedData.ID.streamlineTransaction))
        #expect(transaction.categoryID == SeedData.ID.security)
        #expect(transaction.categoryManuallySet)
    }

    @Test func manuallyAssignThrowsForUnknownTransaction() throws {
        let fixture = try makeFixture()

        #expect(throws: SiftError.self) {
            try fixture.service.manuallyAssign(transactionID: "missing", categoryID: SeedData.ID.security)
        }
    }

    @Test func merchantCategoryCodeHintResolvesToGroceries() throws {
        let fixture = try makeFixture()
        let transaction = Transaction(
            id: "txn-mcc-grocery",
            userID: SeedData.defaultUserID,
            accountID: "acct-1",
            merchantRaw: "UNRECOGNIZABLE MERCHANT 4471",
            merchantKey: MerchantKey("UNRECOGNIZABLE MERCHANT 4471"),
            amount: Money.usd(2150),
            date: Date(),
            categoryHint: MerchantCategoryCodeMapper.categoryHint(for: 5411)
        )
        try fixture.repositories.transactions.insert(transaction)

        try fixture.service.applyAutoCategorizationForTransactions()

        let updated = try #require(try fixture.repositories.transactions.transaction(id: "txn-mcc-grocery"))
        let category = try #require(updated.categoryID.flatMap { try? fixture.repositories.categories.category(id: $0) })
        #expect(category.name == "Groceries")
    }

    @Test func mergeCategoryReassignsTransactionsToo() throws {
        let fixture = try makeFixture()
        try fixture.service.applyAutoCategorizationForTransactions()

        try fixture.service.mergeCategory(id: SeedData.ID.streaming, into: SeedData.ID.audio)

        let transaction = try #require(try fixture.repositories.transactions.transaction(id: SeedData.ID.streamlineTransaction))
        #expect(transaction.categoryID == SeedData.ID.audio)
        #expect(transaction.categoryManuallySet)
        #expect(try fixture.repositories.categories.category(id: SeedData.ID.streaming) == nil)
    }

    // MARK: - User rule precedence

    private func insertRule(
        _ fixture: Fixture,
        id: String = "rule-1",
        kind: CategoryRuleKind = .merchantContains,
        pattern: String,
        categoryID: String,
        order: Int = 0
    ) throws {
        try fixture.repositories.categoryRules.insert(CategoryRule(
            id: id,
            userID: SeedData.defaultUserID,
            kind: kind,
            pattern: pattern,
            categoryID: categoryID,
            order: order
        ))
    }

    private func transaction(_ fixture: Fixture, merchantContaining needle: String) throws -> Transaction {
        let match = try fixture.repositories.transactions.all()
            .first { $0.merchantRaw.localizedCaseInsensitiveContains(needle) }
        return try #require(match)
    }

    /// The whole point of the feature: the built-in keyword list is Sift's guess, and a rule
    /// is the person correcting it. "coffee" is a built-in Dining keyword, so this only
    /// passes if the user's rule is consulted first.
    @Test func aUserRuleBeatsAConflictingBuiltInKeyword() throws {
        let fixture = try makeFixture()
        try insertRule(fixture, pattern: "BLUE BOTTLE", categoryID: SeedData.ID.audio)

        try fixture.service.applyAutoCategorizationForTransactions()

        let coffee = try transaction(fixture, merchantContaining: "BLUE BOTTLE")
        #expect(coffee.categoryID == SeedData.ID.audio)
    }

    @Test func aManualAssignmentBeatsAUserRule() throws {
        let fixture = try makeFixture()
        let coffee = try transaction(fixture, merchantContaining: "BLUE BOTTLE")
        try fixture.service.manuallyAssign(transactionID: coffee.id, categoryID: SeedData.ID.security)
        try insertRule(fixture, pattern: "BLUE BOTTLE", categoryID: SeedData.ID.audio)

        try fixture.service.applyAutoCategorizationForTransactions()

        let after = try transaction(fixture, merchantContaining: "BLUE BOTTLE")
        #expect(after.categoryID == SeedData.ID.security)
        #expect(after.categoryManuallySet)
    }

    /// A code rule reaches descriptors no keyword could: this merchant name contains no
    /// dining word at all, and is categorised purely on the card network's classification.
    @Test func aCategoryCodeRuleCategorisesAnUnreadableDescriptor() throws {
        let fixture = try makeFixture()
        let opaque = Transaction(
            id: "txn-opaque",
            userID: SeedData.defaultUserID,
            accountID: "acct-1",
            merchantRaw: "SQ *4471 ABC",
            merchantKey: MerchantKey("SQ *4471 ABC"),
            amount: Money.usd(1840),
            date: Date(),
            merchantCategoryCode: 5814
        )
        try fixture.repositories.transactions.insert(opaque)
        try insertRule(fixture, kind: .merchantCategoryCode, pattern: "5814", categoryID: SeedData.ID.dining)

        try fixture.service.applyAutoCategorizationForTransactions()

        let after = try #require(try fixture.repositories.transactions.transaction(id: "txn-opaque"))
        #expect(after.categoryID == SeedData.ID.dining)
    }

    @Test func lowestOrderWinsWhenTwoRulesMatchTheSameTransaction() throws {
        let fixture = try makeFixture()
        try insertRule(fixture, id: "loser", pattern: "BLUE", categoryID: SeedData.ID.security, order: 1)
        try insertRule(fixture, id: "winner", pattern: "BOTTLE", categoryID: SeedData.ID.audio, order: 0)

        try fixture.service.applyAutoCategorizationForTransactions()

        let coffee = try transaction(fixture, merchantContaining: "BLUE BOTTLE")
        #expect(coffee.categoryID == SeedData.ID.audio)
    }

    @Test func theChangedCountReportsWhatActuallyMoved() throws {
        let fixture = try makeFixture()

        // Settle the ledger on the built-ins first, so the second pass measures only the
        // rule's effect rather than the backlog.
        try fixture.service.applyAutoCategorizationForTransactions()
        try insertRule(fixture, pattern: "BLUE BOTTLE", categoryID: SeedData.ID.audio)

        let changed = try fixture.service.applyAutoCategorizationForTransactions()
        let expected = try fixture.repositories.transactions.all()
            .filter { $0.merchantRaw.localizedCaseInsensitiveContains("BLUE BOTTLE") }
            .count

        #expect(changed == expected)
        #expect(changed > 0)
    }

    /// A settled ledger with nothing to do reports zero rather than recounting every row.
    @Test func aSecondPassWithNoChangesReportsZero() throws {
        let fixture = try makeFixture()
        try fixture.service.applyAutoCategorizationForTransactions()

        #expect(try fixture.service.applyAutoCategorizationForTransactions() == 0)
    }

    private func makeFixture() throws -> Fixture {
        let container = try SiftModelContainerFactory.makeSeededInMemoryContainer()
        let repositories = RepositoryContainer.live(modelContext: container.mainContext)
        return Fixture(container: container, repositories: repositories, service: CategoryService(repositories: repositories))
    }

    private struct Fixture {
        let container: ModelContainer
        let repositories: RepositoryContainer
        let service: CategoryService
    }
}
