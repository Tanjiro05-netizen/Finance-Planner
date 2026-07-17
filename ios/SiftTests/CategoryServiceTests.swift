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

    @Test func mergeCategoryReassignsTransactionsToo() throws {
        let fixture = try makeFixture()
        try fixture.service.applyAutoCategorizationForTransactions()

        try fixture.service.mergeCategory(id: SeedData.ID.streaming, into: SeedData.ID.audio)

        let transaction = try #require(try fixture.repositories.transactions.transaction(id: SeedData.ID.streamlineTransaction))
        #expect(transaction.categoryID == SeedData.ID.audio)
        #expect(transaction.categoryManuallySet)
        #expect(try fixture.repositories.categories.category(id: SeedData.ID.streaming) == nil)
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
