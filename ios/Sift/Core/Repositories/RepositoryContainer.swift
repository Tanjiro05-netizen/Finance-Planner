import SwiftData
import SwiftUI

struct RepositoryContainer {
    let subscriptions: any SubscriptionRepository
    let accounts: any AccountRepository
    let transactions: any TransactionRepository
    let cancellations: any CancellationRepository
    let categories: any CategoryRepository
    let priceChanges: any PriceChangeRepository
    let settings: any SettingsRepository
    let recurringIncome: any RecurringIncomeRepository
    let bills: any BillRepository

    static func live(modelContext: ModelContext, userID: String = SeedData.defaultUserID) -> RepositoryContainer {
        RepositoryContainer(
            subscriptions: LiveSubscriptionRepository(modelContext: modelContext, userID: userID),
            accounts: LiveAccountRepository(modelContext: modelContext, userID: userID),
            transactions: LiveTransactionRepository(modelContext: modelContext, userID: userID),
            cancellations: LiveCancellationRepository(modelContext: modelContext, userID: userID),
            categories: LiveCategoryRepository(modelContext: modelContext, userID: userID),
            priceChanges: LivePriceChangeRepository(modelContext: modelContext, userID: userID),
            settings: LiveSettingsRepository(modelContext: modelContext, userID: userID),
            recurringIncome: LiveRecurringIncomeRepository(modelContext: modelContext, userID: userID),
            bills: LiveBillRepository(modelContext: modelContext, userID: userID)
        )
    }

    static func mock(userID: String = SeedData.defaultUserID) -> RepositoryContainer {
        let snapshot = SeedData.snapshot(userID: userID)
        return RepositoryContainer(
            subscriptions: MockSubscriptionRepository(snapshot: snapshot, userID: userID),
            accounts: MockAccountRepository(snapshot: snapshot, userID: userID),
            transactions: MockTransactionRepository(snapshot: snapshot, userID: userID),
            cancellations: MockCancellationRepository(snapshot: snapshot, userID: userID),
            categories: MockCategoryRepository(snapshot: snapshot, userID: userID),
            priceChanges: MockPriceChangeRepository(snapshot: snapshot, userID: userID),
            settings: MockSettingsRepository(snapshot: snapshot),
            recurringIncome: MockRecurringIncomeRepository(snapshot: snapshot, userID: userID),
            bills: MockBillRepository(snapshot: snapshot, userID: userID)
        )
    }

    static func emptyMock(userID: String = SeedData.defaultUserID) -> RepositoryContainer {
        let snapshot = SeedData.Snapshot(
            accounts: [],
            transactions: [],
            subscriptions: [],
            cancellationRequests: [],
            categories: [],
            priceChanges: [],
            alertSettings: AlertSettings(
                id: SeedData.ID.alertSettings,
                userID: userID,
                renewalReminders: true,
                priceChanges: true,
                trialEndings: true,
                unusedNudges: true,
                weeklySummary: false
            ),
            recurringIncome: [],
            bills: []
        )

        return RepositoryContainer(
            subscriptions: MockSubscriptionRepository(snapshot: snapshot, userID: userID),
            accounts: MockAccountRepository(snapshot: snapshot, userID: userID),
            transactions: MockTransactionRepository(snapshot: snapshot, userID: userID),
            cancellations: MockCancellationRepository(snapshot: snapshot, userID: userID),
            categories: MockCategoryRepository(snapshot: snapshot, userID: userID),
            priceChanges: MockPriceChangeRepository(snapshot: snapshot, userID: userID),
            settings: MockSettingsRepository(snapshot: snapshot),
            recurringIncome: MockRecurringIncomeRepository(snapshot: snapshot, userID: userID),
            bills: MockBillRepository(snapshot: snapshot, userID: userID)
        )
    }

    @MainActor
    func removeLocalPlaidItem(id: String) throws {
        try accounts.deletePlaidItem(id: id)
    }

    @MainActor
    func wipeLocalData() throws {
        try priceChanges.deleteAll()
        try cancellations.deleteAll()
        try transactions.deleteAll()
        try subscriptions.deleteAll()
        try accounts.deleteAll()
        try categories.deleteAll()
        try settings.deleteAll()
        try recurringIncome.deleteAll()
        try bills.deleteAll()
    }
}

extension EnvironmentValues {
    @Entry var repositories: RepositoryContainer = .mock()
}

extension EnvironmentValues {
    @Entry var apiClient: any SiftAPIClient = MockSiftAPIClient()

    @Entry var plaidLinkPresenter: any PlaidLinkPresenting = MockPlaidLinkPresenter(result: .cancelled)

    @Entry var detectionService: any DetectionServing = MockDetectionService()

    @Entry var incomeDetectionService: any IncomeDetectionServing = MockIncomeDetectionService()

    @Entry var notificationAuthorizer: any NotificationAuthorizing = MockNotificationAuthorizer()

    @Entry var notificationScheduler: any NotificationScheduling = NoopNotificationScheduler()

    @Entry var notificationRouter: NotificationRouter = .init()

    @Entry var onboardingStateStore: any OnboardingStateStoring = InMemoryOnboardingStateStore()

    @Entry var tokenStore: any TokenStoring = KeychainTokenStore()

    @Entry var featureFlags: SiftFeatureFlags = .launchDefault

    @Entry var analyticsRecorder: any AnalyticsRecording = NoopAnalyticsRecorder()
}
