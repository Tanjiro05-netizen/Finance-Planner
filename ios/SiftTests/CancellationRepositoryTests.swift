import Foundation
@testable import Sift
import Testing

@MainActor
struct CancellationRepositoryTests {
    @Test func createRequestAndStatusTransitionPersist() throws {
        let container = try SiftModelContainerFactory.makeSeededInMemoryContainer()
        let repository = LiveCancellationRepository(modelContext: container.mainContext)
        let createdAt = SeedData.referenceDate
        let updatedAt = try #require(Calendar.utc.date(byAdding: .hour, value: 2, to: createdAt))

        let request = try repository.create(
            subscriptionID: SeedData.ID.tonebox,
            method: .concierge,
            note: "Please cancel after renewal check.",
            now: createdAt
        )
        let updated = try repository.updateStatus(id: request.id, status: .contacting, now: updatedAt)
        let verifyingRepository = LiveCancellationRepository(modelContext: container.mainContext)
        let fetched = try verifyingRepository.requests(for: SeedData.ID.tonebox).first

        #expect(request.status == .contacting)
        #expect(updated.status == .contacting)
        #expect(updated.updatedAt == updatedAt)
        #expect(fetched?.id == request.id)
        #expect(fetched?.status == .contacting)
    }
}
