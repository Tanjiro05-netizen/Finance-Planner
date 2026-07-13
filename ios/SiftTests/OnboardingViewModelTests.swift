@testable import Sift
import Testing

@MainActor
struct OnboardingViewModelTests {
    @Test func bootstrapMovesFromSplashToWelcome() async {
        let harness = OnboardingHarness()

        await harness.viewModel.bootstrapIfNeeded()

        #expect(harness.viewModel.step == .welcome)
    }

    @Test func fullMockFlowProgressesToReview() async {
        let harness = OnboardingHarness()

        await harness.viewModel.bootstrapIfNeeded()
        harness.viewModel.showConnectIntro()
        harness.viewModel.showBankPicker()
        harness.viewModel.selectInstitution(BankInstitution.popular[0])
        await harness.viewModel.connectSelectedInstitution()

        #expect(harness.viewModel.step == .reviewFound)
        #expect(harness.viewModel.scanState.progress == 1)
        #expect(harness.viewModel.reviewItems.count == harness.detections.count)
    }

    @Test func scanImportsSyncedTransactionsBeforeDetection() async throws {
        var apiClient = MockSiftAPIClient()
        apiClient.transactionPages = [[
            RemoteTransaction(
                id: "txn-live-netflix",
                userId: SeedData.defaultUserID,
                accountId: SeedData.ID.checking,
                merchantName: "NETFLIX #4471 LOS GATOS",
                amountMinor: 1549,
                isoCurrency: "USD",
                date: SeedData.referenceDate,
                pending: false,
                category: "ENTERTAINMENT"
            ),
        ]]
        let harness = OnboardingHarness(apiClient: apiClient)

        await harness.viewModel.bootstrapIfNeeded()
        harness.viewModel.showConnectIntro()
        harness.viewModel.showBankPicker()
        harness.viewModel.selectInstitution(BankInstitution.popular[0])
        await harness.viewModel.connectSelectedInstitution()

        let transactions = try harness.repositories.transactions.all()
        #expect(transactions.count == 1)
        #expect(transactions[0].merchantRaw == "NETFLIX #4471 LOS GATOS")
        #expect(transactions[0].merchantKey == MerchantKey("Netflix"))
    }

    @Test func toggledOffReviewItemIsNotPersisted() {
        let harness = OnboardingHarness()
        harness.loadReview()
        let excluded = harness.detections[1]

        harness.viewModel.toggleReviewItem(id: excluded.id)
        harness.viewModel.confirmSubscriptions()

        let subscriptions = (try? harness.repositories.subscriptions.all()) ?? []
        #expect(harness.viewModel.step == .notifications)
        #expect(subscriptions.count == harness.detections.count - 1)
        #expect(!subscriptions.contains { $0.id == excluded.id })
    }

    @Test func completeOnboardingSetsStateFlag() {
        let harness = OnboardingHarness()

        harness.viewModel.completeOnboarding()

        #expect(harness.stateStore.isComplete())
    }

    @Test func connectAppleWalletLinkedProgressesToReviewFound() async throws {
        let harness = OnboardingHarness(presenter: MockPlaidLinkPresenter(result: .success(publicToken: "on-device")))

        harness.viewModel.showConnectIntro()
        harness.viewModel.showConnectLeadIn()
        await harness.viewModel.connectAppleWallet()

        #expect(harness.viewModel.step == .reviewFound)
        #expect(harness.viewModel.reviewItems.count == harness.detections.count)

        let accounts = try harness.repositories.accounts.all()
        #expect(!accounts.isEmpty)
    }

    @Test func connectAppleWalletDeniedShowsUnavailableAccessDenied() async {
        let harness = OnboardingHarness(presenter: MockPlaidLinkPresenter(result: .cancelled))

        harness.viewModel.showConnectIntro()
        harness.viewModel.showConnectLeadIn()
        await harness.viewModel.connectAppleWallet()

        #expect(harness.viewModel.step == .connectUnavailable)
        #expect(harness.viewModel.unavailableReason == .accessDenied)
    }

    @Test func connectAppleWalletWithNoWalletDataShowsUnavailableNoWalletData() async {
        var apiClient = MockSiftAPIClient()
        apiClient.accounts = []
        apiClient.syncResponse = TransactionSyncResponse(added: 0, modified: 0, removed: 0, hasMore: false)
        let viewModel = OnboardingViewModel(
            apiClient: apiClient,
            linkCoordinator: PlaidLinkCoordinator(
                apiClient: apiClient,
                presenter: MockPlaidLinkPresenter(result: .success(publicToken: "on-device"))
            ),
            detectionService: MockDetectionService(detections: []),
            notificationAuthorizer: MockNotificationAuthorizer(),
            repositories: .emptyMock(),
            stateStore: InMemoryOnboardingStateStore()
        )

        viewModel.showConnectIntro()
        viewModel.showConnectLeadIn()
        await viewModel.connectAppleWallet()

        #expect(viewModel.step == .connectUnavailable)
        #expect(viewModel.unavailableReason == .noWalletData)
    }

    @Test func retryConnectClearsReasonAndReturnsToSecureLeadIn() {
        let harness = OnboardingHarness()
        harness.viewModel.unavailableReason = .accessDenied
        harness.viewModel.step = .connectUnavailable

        harness.viewModel.retryConnect()

        #expect(harness.viewModel.step == .secureLeadIn)
        #expect(harness.viewModel.unavailableReason == nil)
    }

    @Test func skipConnectMovesToNotificationsWithZeroedTotals() {
        let harness = OnboardingHarness()
        harness.viewModel.unavailableReason = .noWalletData
        harness.viewModel.step = .connectUnavailable

        harness.viewModel.skipConnect()

        #expect(harness.viewModel.step == .notifications)
        #expect(harness.viewModel.unavailableReason == nil)
        #expect(harness.viewModel.confirmedCount == 0)
        #expect(harness.viewModel.confirmedMonthlyTotal == .zeroUSD)
    }
}

@MainActor
private final class OnboardingHarness {
    let repositories = RepositoryContainer.emptyMock()
    let stateStore = InMemoryOnboardingStateStore()
    let detections: [DetectedSubscription]
    let viewModel: OnboardingViewModel

    init(
        apiClient: any SiftAPIClient = MockSiftAPIClient(),
        presenter: any PlaidLinkPresenting = MockPlaidLinkPresenter()
    ) {
        detections = SeedData.snapshot().subscriptions
            .filter { $0.status != .cancelled }
            .prefix(3)
            .map(DetectedSubscription.init(subscription:))

        let coordinator = PlaidLinkCoordinator(apiClient: apiClient, presenter: presenter)
        viewModel = OnboardingViewModel(
            apiClient: apiClient,
            linkCoordinator: coordinator,
            detectionService: MockDetectionService(detections: detections),
            notificationAuthorizer: MockNotificationAuthorizer(),
            repositories: repositories,
            stateStore: stateStore
        )
    }

    func loadReview() {
        viewModel.step = .reviewFound
        viewModel.reviewItems = detections.map { ReviewSubscriptionItem(detection: $0, isSelected: true) }
    }
}
