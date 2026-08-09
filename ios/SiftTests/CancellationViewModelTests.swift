import Foundation
@testable import Sift
import Testing

@MainActor
struct CancellationViewModelTests {
    @Test func choosingConciergeCreatesRequestAndShowsTimeline() async throws {
        let repositories = RepositoryContainer.mock()
        let apiClient = CancellationAPIClientSpy()
        let viewModel = CancellationViewModel(
            subscriptionID: SeedData.ID.streamline,
            repositories: repositories,
            apiClient: apiClient,
            featureFlags: SiftFeatureFlags(conciergeEnabled: true, ledgerEnabled: false),
            now: { SeedData.referenceDate }
        )

        viewModel.load()
        await viewModel.chooseConcierge()

        #expect(apiClient.createdMethods == [.concierge])
        #expect(viewModel.stage == .concierge)
        #expect(viewModel.request?.status == .requested)
        #expect(viewModel.conciergeTimelineItems.map(\.title) == [
            "Request received",
            "Contacting provider",
            "Confirmed",
        ])
        #expect(viewModel.conciergeTimelineItems.map(\.id) == [
            "request-received",
            "provider-contact",
            "confirmed",
        ])
        #expect(try repositories.cancellations.requests(for: SeedData.ID.streamline).count == 1)
    }

    @Test func confirmedConciergeRequestMarksSubscriptionCancelledAndDropsTotals() async throws {
        let repositories = RepositoryContainer.mock()
        let apiClient = CancellationAPIClientSpy()
        let viewModel = CancellationViewModel(
            subscriptionID: SeedData.ID.streamline,
            repositories: repositories,
            apiClient: apiClient,
            featureFlags: SiftFeatureFlags(conciergeEnabled: true, ledgerEnabled: false),
            now: { SeedData.referenceDate }
        )

        viewModel.load()
        await viewModel.chooseConcierge()
        let request = try #require(viewModel.request)
        apiClient.listResponse = [
            apiClient.remoteRequest(
                id: request.id,
                subscriptionRef: SeedData.ID.streamline,
                merchantName: "Streamline+",
                method: .concierge,
                status: .confirmed
            ),
        ]

        await viewModel.refreshCurrentRequest()

        #expect(viewModel.stage == .confirmed)
        #expect(viewModel.request?.status == .confirmed)
        #expect(try repositories.subscriptions.subscription(id: SeedData.ID.streamline)?.status == .cancelled)
        #expect(try repositories.subscriptions.monthlyTotal() == Money.usd(23234))
    }

    @Test func guidedUserConfirmationSetsCancelledByUser() async throws {
        let repositories = RepositoryContainer.mock()
        let apiClient = CancellationAPIClientSpy()
        let viewModel = CancellationViewModel(
            subscriptionID: SeedData.ID.tonebox,
            repositories: repositories,
            apiClient: apiClient,
            now: { SeedData.referenceDate }
        )

        viewModel.load()
        await viewModel.chooseGuided()
        await viewModel.confirmGuidedCancellation()

        #expect(apiClient.updatedStatuses == [.cancelledByUser])
        #expect(viewModel.stage == .confirmed)
        #expect(viewModel.request?.status == .cancelledByUser)
        #expect(try repositories.subscriptions.subscription(id: SeedData.ID.tonebox)?.status == .cancelled)
    }

    @Test func guidedOnlyLaunchBlocksConciergeWithoutCreatingRequest() async throws {
        let repositories = RepositoryContainer.mock()
        let apiClient = CancellationAPIClientSpy()
        let analytics = CancellationAnalyticsSpy()
        let viewModel = CancellationViewModel(
            subscriptionID: SeedData.ID.streamline,
            repositories: repositories,
            apiClient: apiClient,
            analyticsRecorder: analytics,
            now: { SeedData.referenceDate }
        )

        viewModel.load()
        await viewModel.chooseConcierge()

        #expect(viewModel.stage == .options)
        #expect(viewModel.errorMessage == "Concierge cancellation is coming soon. You can use guided steps and reminders today.")
        #expect(apiClient.createdMethods.isEmpty)
        #expect(try repositories.cancellations.requests(for: SeedData.ID.streamline).isEmpty)
        #expect(analytics.events == [.featureUnavailable(name: "concierge")])
    }

    @Test func conciergeStaysOfferedOnlyWhenTheBackendCanServiceIt() {
        let apiClient = CancellationAPIClientSpy()
        apiClient.conciergeSupported = false

        let viewModel = CancellationViewModel(
            subscriptionID: SeedData.ID.streamline,
            repositories: .mock(),
            apiClient: apiClient,
            featureFlags: SiftFeatureFlags(conciergeEnabled: true),
            now: { SeedData.referenceDate }
        )
        viewModel.load()

        // Flag on, backend can't do it: the option must not present itself as live.
        #expect(viewModel.isConciergeEnabled == false)

        apiClient.conciergeSupported = true
        #expect(viewModel.isConciergeEnabled)
    }
}

private final class CancellationAPIClientSpy: SiftAPIClient, @unchecked Sendable {
    var conciergeSupported = true
    var createdMethods: [CancellationMethod] = []
    var updatedStatuses: [CancellationStatus] = []
    var listResponse: [RemoteCancellationRequest] = []

    private var currentRequest: RemoteCancellationRequest?

    var supportsConcierge: Bool {
        conciergeSupported
    }

    func bootstrap() async throws -> AuthBootstrapResponse {
        AuthBootstrapResponse(token: "jwt-test")
    }

    func createLinkToken() async throws -> LinkTokenResponse {
        LinkTokenResponse(linkToken: "link-test")
    }

    func exchange(publicToken _: String) async throws -> ExchangePublicTokenResponse {
        ExchangePublicTokenResponse(ok: true)
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
        createdMethods.append(method)
        let request = remoteRequest(
            id: "server-\(method.rawValue)-\(subscriptionRef)",
            subscriptionRef: subscriptionRef,
            merchantName: merchantName,
            method: method,
            status: .requested
        )
        currentRequest = request
        return request
    }

    func listCancellations() async throws -> [RemoteCancellationRequest] {
        listResponse
    }

    func updateCancellation(
        id: String,
        status: CancellationStatus,
        note: String?
    ) async throws -> RemoteCancellationRequest {
        updatedStatuses.append(status)
        let base = currentRequest ?? remoteRequest(
            id: id,
            subscriptionRef: SeedData.ID.streamline,
            merchantName: "Subscription",
            method: .guided,
            status: .requested
        )
        let request = RemoteCancellationRequest(
            id: id,
            userId: base.userId,
            subscriptionRef: base.subscriptionRef,
            merchantName: base.merchantName,
            method: base.method,
            status: status,
            note: note,
            createdAt: base.createdAt,
            updatedAt: SeedData.referenceDate
        )
        currentRequest = request
        return request
    }

    func remoteRequest(
        id: String,
        subscriptionRef: String,
        merchantName: String,
        method: CancellationMethod,
        status: CancellationStatus
    ) -> RemoteCancellationRequest {
        RemoteCancellationRequest(
            id: id,
            userId: SeedData.defaultUserID,
            subscriptionRef: subscriptionRef,
            merchantName: merchantName,
            method: method,
            status: status,
            note: nil,
            createdAt: SeedData.referenceDate,
            updatedAt: SeedData.referenceDate
        )
    }
}

private final class CancellationAnalyticsSpy: AnalyticsRecording, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var events: [AnalyticsEvent] = []

    func record(_ event: AnalyticsEvent) {
        lock.withLock {
            events.append(event)
        }
    }
}

private extension NSLock {
    func withLock<Value>(_ body: () throws -> Value) rethrows -> Value {
        lock()
        defer { unlock() }
        return try body()
    }
}
