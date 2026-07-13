import Foundation
@testable import Sift
import Testing

@MainActor
struct SubscriptionRefreshServiceTests {
    @Test func refreshPersistsAccountsFromAPIClient() async throws {
        let repositories = RepositoryContainer.emptyMock()
        let apiClient = MockSiftAPIClient()
        let service = DefaultSubscriptionRefreshService(
            apiClient: apiClient,
            detectionService: MockDetectionService(detections: []),
            repositories: repositories,
            userID: SeedData.defaultUserID
        )

        _ = try await service.refresh(referenceDate: SeedData.referenceDate)

        let accounts = try repositories.accounts.all()
        #expect(accounts.count == apiClient.accounts.count)
        let checking = try #require(accounts.first { $0.id == SeedData.ID.checking })
        #expect(checking.institutionName == "Northstar Bank")
        #expect(checking.userID == SeedData.defaultUserID)
        #expect(checking.status == .connected)
    }

    @Test func refreshWithNoRemoteAccountsDoesNotWipeStoredAccounts() async throws {
        let repositories = RepositoryContainer.emptyMock()
        try repositories.accounts.insert(LinkedAccount(
            id: "acct-existing",
            userID: SeedData.defaultUserID,
            institutionName: "Existing Bank",
            mask: "0000",
            type: "Checking",
            status: .connected
        ))

        var apiClient = MockSiftAPIClient()
        apiClient.accounts = []
        let service = DefaultSubscriptionRefreshService(
            apiClient: apiClient,
            detectionService: MockDetectionService(detections: []),
            repositories: repositories,
            userID: SeedData.defaultUserID
        )

        _ = try await service.refresh(referenceDate: SeedData.referenceDate)

        let accounts = try repositories.accounts.all()
        #expect(accounts.map(\.id) == ["acct-existing"])
    }
}
