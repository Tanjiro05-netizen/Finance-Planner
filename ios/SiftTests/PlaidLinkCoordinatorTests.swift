import Testing
@testable import Sift

@MainActor
struct PlaidLinkCoordinatorTests {
    @Test func successfulLinkExchangesPublicTokenOnce() async throws {
        let apiClient = TrackingAPIClient()
        let presenter = MockPlaidLinkPresenter(result: .success(publicToken: "public-good"))
        let coordinator = PlaidLinkCoordinator(apiClient: apiClient, presenter: presenter)

        let outcome = try await coordinator.linkAccount(institution: BankInstitution.popular.first)

        #expect(outcome == .linked)
        #expect(apiClient.exchangedTokens == ["public-good"])
    }

    @Test func canceledLinkDoesNotExchangeToken() async throws {
        let apiClient = TrackingAPIClient()
        let presenter = MockPlaidLinkPresenter(result: .cancelled)
        let coordinator = PlaidLinkCoordinator(apiClient: apiClient, presenter: presenter)

        let outcome = try await coordinator.linkAccount(institution: nil)

        #expect(outcome == .cancelled)
        #expect(apiClient.exchangedTokens.isEmpty)
    }
}

private final class TrackingAPIClient: SiftAPIClient, @unchecked Sendable {
    var exchangedTokens: [String] = []

    func bootstrap() async throws -> AuthBootstrapResponse {
        AuthBootstrapResponse(token: "jwt")
    }

    func createLinkToken() async throws -> LinkTokenResponse {
        LinkTokenResponse(linkToken: "link-token")
    }

    func exchange(publicToken: String) async throws -> ExchangePublicTokenResponse {
        exchangedTokens.append(publicToken)
        return ExchangePublicTokenResponse(ok: true)
    }

    func syncTransactions() async throws -> TransactionSyncResponse {
        TransactionSyncResponse(added: 0, modified: 0, removed: 0, hasMore: false)
    }

    func listTransactions(limit _: Int, offset _: Int) async throws -> [RemoteTransaction] {
        []
    }

    func createCancellation(
        subscriptionRef: String,
        merchantName: String,
        method: CancellationMethod
    ) async throws -> RemoteCancellationRequest {
        RemoteCancellationRequest(
            id: "cancel-test",
            userId: SeedData.defaultUserID,
            subscriptionRef: subscriptionRef,
            merchantName: merchantName,
            method: method,
            status: .requested,
            note: nil,
            createdAt: SeedData.referenceDate,
            updatedAt: SeedData.referenceDate
        )
    }

    func listCancellations() async throws -> [RemoteCancellationRequest] {
        []
    }

    func updateCancellation(
        id: String,
        status: CancellationStatus,
        note: String?
    ) async throws -> RemoteCancellationRequest {
        RemoteCancellationRequest(
            id: id,
            userId: SeedData.defaultUserID,
            subscriptionRef: SeedData.ID.streamline,
            merchantName: "Streamline+",
            method: .guided,
            status: status,
            note: note,
            createdAt: SeedData.referenceDate,
            updatedAt: SeedData.referenceDate
        )
    }
}
