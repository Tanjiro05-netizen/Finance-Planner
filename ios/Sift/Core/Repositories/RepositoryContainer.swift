import SwiftData
import SwiftUI

struct RepositoryContainer: Sendable {
    let subscriptions: any SubscriptionRepository
    let accounts: any AccountRepository
    let transactions: any TransactionRepository
    let cancellations: any CancellationRepository
    let categories: any CategoryRepository
    let priceChanges: any PriceChangeRepository
    let settings: any SettingsRepository

    static func live(modelContext: ModelContext, userID: String = SeedData.defaultUserID) -> RepositoryContainer {
        RepositoryContainer(
            subscriptions: LiveSubscriptionRepository(modelContext: modelContext, userID: userID),
            accounts: LiveAccountRepository(modelContext: modelContext, userID: userID),
            transactions: LiveTransactionRepository(modelContext: modelContext, userID: userID),
            cancellations: LiveCancellationRepository(modelContext: modelContext, userID: userID),
            categories: LiveCategoryRepository(modelContext: modelContext, userID: userID),
            priceChanges: LivePriceChangeRepository(modelContext: modelContext, userID: userID),
            settings: LiveSettingsRepository(modelContext: modelContext, userID: userID)
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
            settings: MockSettingsRepository(snapshot: snapshot)
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
            )
        )

        return RepositoryContainer(
            subscriptions: MockSubscriptionRepository(snapshot: snapshot, userID: userID),
            accounts: MockAccountRepository(snapshot: snapshot, userID: userID),
            transactions: MockTransactionRepository(snapshot: snapshot, userID: userID),
            cancellations: MockCancellationRepository(snapshot: snapshot, userID: userID),
            categories: MockCategoryRepository(snapshot: snapshot, userID: userID),
            priceChanges: MockPriceChangeRepository(snapshot: snapshot, userID: userID),
            settings: MockSettingsRepository(snapshot: snapshot)
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
    }
}

private struct RepositoryContainerKey: EnvironmentKey {
    static let defaultValue = RepositoryContainer.mock()
}

extension EnvironmentValues {
    var repositories: RepositoryContainer {
        get { self[RepositoryContainerKey.self] }
        set { self[RepositoryContainerKey.self] = newValue }
    }
}

private struct APIClientKey: EnvironmentKey {
    static let defaultValue: any SiftAPIClient = MockSiftAPIClient()
}

private struct PlaidLinkPresenterKey: EnvironmentKey {
    static let defaultValue: any PlaidLinkPresenting = MockPlaidLinkPresenter(result: .cancelled)
}

private struct DetectionServiceKey: EnvironmentKey {
    static let defaultValue: any DetectionServing = MockDetectionService()
}

private struct NotificationAuthorizerKey: EnvironmentKey {
    static let defaultValue: any NotificationAuthorizing = MockNotificationAuthorizer()
}

private struct NotificationSchedulerKey: EnvironmentKey {
    static let defaultValue: any NotificationScheduling = NoopNotificationScheduler()
}

private struct NotificationRouterKey: EnvironmentKey {
    static let defaultValue = NotificationRouter()
}

private struct OnboardingStateStoreKey: EnvironmentKey {
    static let defaultValue: any OnboardingStateStoring = InMemoryOnboardingStateStore()
}

private struct TokenStoreKey: EnvironmentKey {
    static let defaultValue: any TokenStoring = KeychainTokenStore()
}

private struct FeatureFlagsKey: EnvironmentKey {
    static let defaultValue = SiftFeatureFlags.launchDefault
}

private struct AnalyticsRecorderKey: EnvironmentKey {
    static let defaultValue: any AnalyticsRecording = NoopAnalyticsRecorder()
}

extension EnvironmentValues {
    var apiClient: any SiftAPIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }

    var plaidLinkPresenter: any PlaidLinkPresenting {
        get { self[PlaidLinkPresenterKey.self] }
        set { self[PlaidLinkPresenterKey.self] = newValue }
    }

    var detectionService: any DetectionServing {
        get { self[DetectionServiceKey.self] }
        set { self[DetectionServiceKey.self] = newValue }
    }

    var notificationAuthorizer: any NotificationAuthorizing {
        get { self[NotificationAuthorizerKey.self] }
        set { self[NotificationAuthorizerKey.self] = newValue }
    }

    var notificationScheduler: any NotificationScheduling {
        get { self[NotificationSchedulerKey.self] }
        set { self[NotificationSchedulerKey.self] = newValue }
    }

    var notificationRouter: NotificationRouter {
        get { self[NotificationRouterKey.self] }
        set { self[NotificationRouterKey.self] = newValue }
    }

    var onboardingStateStore: any OnboardingStateStoring {
        get { self[OnboardingStateStoreKey.self] }
        set { self[OnboardingStateStoreKey.self] = newValue }
    }

    var tokenStore: any TokenStoring {
        get { self[TokenStoreKey.self] }
        set { self[TokenStoreKey.self] = newValue }
    }

    var featureFlags: SiftFeatureFlags {
        get { self[FeatureFlagsKey.self] }
        set { self[FeatureFlagsKey.self] = newValue }
    }

    var analyticsRecorder: any AnalyticsRecording {
        get { self[AnalyticsRecorderKey.self] }
        set { self[AnalyticsRecorderKey.self] = newValue }
    }
}
