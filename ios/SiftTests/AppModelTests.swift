import SwiftUI
import Testing
@testable import Sift

@MainActor
struct AppModelTests {
    @Test func selectTabUpdatesState() {
        let model = AppModel()

        model.select(tab: .subscriptions)

        #expect(model.selectedTab == .subscriptions)
    }

    @Test func presentAndDismissToggleSheetState() {
        let model = AppModel()

        model.present(.subscriptionDetail(id: SampleRouteID.subscription))
        #expect(model.sheet == .subscriptionDetail(id: SampleRouteID.subscription))

        model.dismissSheet()
        #expect(model.sheet == nil)
    }

    @Test func pushAppendsToTheCorrectPath() {
        let model = AppModel()

        model.push(.settings, in: .home)
        model.push(.detail(id: SampleRouteID.subscription), in: .subscriptions)
        model.push(.savingsBreakdown, in: .insights)

        #expect(model.pathCount(for: .home) == 1)
        #expect(model.pathCount(for: .subscriptions) == 1)
        #expect(model.pathCount(for: .insights) == 1)
    }

    @Test func deepLinkCanSelectAndRoute() {
        let model = AppModel()

        model.handle(.settings)
        #expect(model.selectedTab == .home)
        #expect(model.pathCount(for: .home) == 1)

        model.handle(.subscriptionDetail(id: SampleRouteID.subscription))
        #expect(model.selectedTab == .subscriptions)
        #expect(model.sheet == .subscriptionDetail(id: SampleRouteID.subscription))
    }

    @Test func returnToOnboardingClearsNavigationState() {
        let model = AppModel(isOnboardingComplete: true)
        model.select(tab: .subscriptions)
        model.push(.settings, in: .home)
        model.present(.cancellationRequests)

        model.returnToOnboarding()

        #expect(!model.isOnboardingComplete)
        #expect(model.selectedTab == .home)
        #expect(model.pathCount(for: .home) == 0)
        #expect(model.sheet == nil)
    }
}

@MainActor
struct AlertSettingsViewModelTests {
    @Test func defaultsLoadFromRepository() {
        let repositories = RepositoryContainer.emptyMock()
        let viewModel = AlertSettingsViewModel(repository: repositories.settings)

        viewModel.load()

        #expect(viewModel.renewalReminders)
        #expect(viewModel.priceChanges)
        #expect(viewModel.trialEndings)
        #expect(viewModel.unusedNudges)
        #expect(!viewModel.weeklySummary)
    }

    @Test func togglingPersistsAndCanBeReadAgain() throws {
        let repositories = RepositoryContainer.emptyMock()
        let viewModel = AlertSettingsViewModel(repository: repositories.settings)

        viewModel.load()
        viewModel.setWeeklySummary(true)
        viewModel.setRenewalReminders(false)

        let settings = try repositories.settings.settings()
        #expect(settings.weeklySummary)
        #expect(!settings.renewalReminders)

        let reloaded = AlertSettingsViewModel(repository: repositories.settings)
        reloaded.load()
        #expect(reloaded.weeklySummary)
        #expect(!reloaded.renewalReminders)
    }
}

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
}

@MainActor
struct LinkedAccountsViewModelTests {
    @Test func removeAccountDeletesRemoteItemCleansLocalRowsAndRefreshes() async throws {
        let repositories = RepositoryContainer.mock()
        let apiClient = Phase9TrackingAPIClient()
        let refresher = TrackingRefreshService()
        let viewModel = LinkedAccountsViewModel(
            repositories: repositories,
            apiClient: apiClient,
            linkCoordinator: PlaidLinkCoordinator(apiClient: apiClient, presenter: MockPlaidLinkPresenter()),
            refresher: refresher,
            referenceDateProvider: { SeedData.referenceDate }
        )

        await viewModel.load()
        await viewModel.removePlaidItem(id: "item-northstar")

        #expect(apiClient.deletedPlaidItemIDs == ["item-northstar"])
        #expect(refresher.refreshCount == 1)
        #expect(try repositories.accounts.all().allSatisfy { $0.plaidItemID != "item-northstar" })
        #expect(viewModel.rows.allSatisfy { $0.id != "item-northstar" })
    }
}

@MainActor
struct PrivacyDeleteTests {
    @Test func deleteClearsTokenStoreLocalDataAndOnboardingState() async throws {
        let repositories = RepositoryContainer.mock()
        let apiClient = Phase9TrackingAPIClient()
        let tokenStore = InMemoryTokenStore(token: "jwt-phase-9")
        let stateStore = InMemoryOnboardingStateStore(isComplete: true)
        let appModel = AppModel(isOnboardingComplete: true)
        let viewModel = PrivacyDataViewModel(
            repositories: repositories,
            apiClient: apiClient,
            tokenStore: tokenStore,
            stateStore: stateStore
        )

        let didDelete = await viewModel.disconnectAndDelete()
        appModel.returnToOnboarding()

        #expect(didDelete)
        #expect(apiClient.deleteUserDataCallCount == 1)
        #expect(try tokenStore.readToken() == nil)
        #expect(try repositories.accounts.all().isEmpty)
        #expect(try repositories.subscriptions.all().isEmpty)
        #expect(!stateStore.isComplete())
        #expect(!appModel.isOnboardingComplete)
    }
}

@MainActor
private final class TrackingRefreshService: SubscriptionRefreshing, @unchecked Sendable {
    var refreshCount = 0

    func refresh(referenceDate _: Date) async throws -> SubscriptionRefreshResult {
        refreshCount += 1
        return SubscriptionRefreshResult(
            synced: TransactionSyncResponse(added: 0, modified: 0, removed: 0, hasMore: false),
            importedTransactionCount: 0,
            detectionResult: .empty
        )
    }
}

private final class Phase9TrackingAPIClient: SiftAPIClient, @unchecked Sendable {
    var remoteAccounts = SeedData.snapshot().accounts.map(RemoteAccount.init(account:))
    var deletedPlaidItemIDs: [String] = []
    var deleteUserDataCallCount = 0

    func bootstrap() async throws -> AuthBootstrapResponse {
        AuthBootstrapResponse(token: "jwt")
    }

    func createLinkToken() async throws -> LinkTokenResponse {
        LinkTokenResponse(linkToken: "link-token")
    }

    func exchange(publicToken _: String) async throws -> ExchangePublicTokenResponse {
        ExchangePublicTokenResponse(ok: true)
    }

    func listAccounts() async throws -> [RemoteAccount] {
        remoteAccounts.filter { !deletedPlaidItemIDs.contains($0.plaidItemId) }
    }

    func deletePlaidItem(id: String) async throws -> APIOKResponse {
        deletedPlaidItemIDs.append(id)
        return APIOKResponse(ok: true)
    }

    func deleteUserData() async throws -> APIOKResponse {
        deleteUserDataCallCount += 1
        remoteAccounts = []
        return APIOKResponse(ok: true)
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
            id: "cancel-phase-9",
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
