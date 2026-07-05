import SwiftUI
import SwiftData

@main
struct SiftApp: App {
    @State private var appModel: AppModel

    private let modelContainer: ModelContainer
    private let repositories: RepositoryContainer
    private let apiClient: any SiftAPIClient
    private let plaidLinkPresenter: any PlaidLinkPresenting
    private let detectionService: any DetectionServing
    private let notificationAuthorizer: any NotificationAuthorizing
    private let notificationScheduler: any NotificationScheduling
    private let notificationRouter: NotificationRouter
    private let onboardingStateStore: any OnboardingStateStoring
    private let tokenStore: any TokenStoring
    private let featureFlags: SiftFeatureFlags
    private let analyticsRecorder: any AnalyticsRecording

    init() {
        let launchOptions = SiftLaunchOptions.current
        let flags = SiftFeatureFlags.current()
        let stateStore = UserDefaultsOnboardingStateStore()
        let authTokenStore: any TokenStoring
        let configuredRepositories: RepositoryContainer

        if launchOptions.useMockServices {
            authTokenStore = InMemoryTokenStore(token: "mock-jwt")
        } else {
            authTokenStore = KeychainTokenStore()
        }

        if launchOptions.resetOnboarding {
            stateStore.setComplete(false)
        }

        if launchOptions.forceOnboardingComplete {
            stateStore.setComplete(true)
        }

        let container = try! SiftModelContainerFactory.makeContainer(inMemory: launchOptions.useMockServices)
        modelContainer = container
        onboardingStateStore = stateStore
        tokenStore = authTokenStore
        featureFlags = flags
        analyticsRecorder = NoopAnalyticsRecorder()

        if launchOptions.useMockServices {
            configuredRepositories = launchOptions.useEmptyStore ? .emptyMock() : .mock()
            var mockAPIClient = MockSiftAPIClient()
            if launchOptions.confirmCancellationOnRefresh {
                mockAPIClient.cancellationRequests = [
                    RemoteCancellationRequest(
                        id: "cancel-mock-\(SeedData.ID.streamline)-concierge",
                        userId: SeedData.defaultUserID,
                        subscriptionRef: SeedData.ID.streamline,
                        merchantName: "Streamline+",
                        method: .concierge,
                        status: .confirmed,
                        note: "Confirmed by mock API.",
                        createdAt: SeedData.referenceDate,
                        updatedAt: SeedData.referenceDate
                    ),
                ]
            }
            if launchOptions.includeSandboxAccount {
                mockAPIClient.accounts.append(RemoteAccount(
                    id: "acct-sandbox-checking",
                    plaidItemId: "item-sandbox-bank",
                    institutionName: "Sandbox Bank",
                    mask: "0000",
                    name: "Plaid Checking",
                    type: "depository",
                    status: "active"
                ))
            }
            apiClient = mockAPIClient
            plaidLinkPresenter = MockPlaidLinkPresenter()
            detectionService = MockDetectionService()
            notificationAuthorizer = MockNotificationAuthorizer()
        } else {
            configuredRepositories = RepositoryContainer.live(modelContext: container.mainContext)
            apiClient = DefaultSiftAPIClient(
                tokenStore: authTokenStore,
                analyticsRecorder: analyticsRecorder
            )
            plaidLinkPresenter = LinkKitPlaidLinkPresenter()
            detectionService = LiveDetectionService(modelContainer: container)
            notificationAuthorizer = UserNotificationAuthorizer()
        }

        repositories = configuredRepositories
        notificationScheduler = NotificationScheduler(repositories: configuredRepositories)
        notificationRouter = NotificationRouter(center: .current())
        _appModel = State(initialValue: AppModel(isOnboardingComplete: stateStore.isComplete()))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .environment(\.repositories, repositories)
                .environment(\.apiClient, apiClient)
                .environment(\.detectionService, detectionService)
                .environment(\.notificationAuthorizer, notificationAuthorizer)
                .environment(\.notificationScheduler, notificationScheduler)
                .environment(\.notificationRouter, notificationRouter)
                .environment(\.onboardingStateStore, onboardingStateStore)
                .environment(\.tokenStore, tokenStore)
                .environment(\.plaidLinkPresenter, plaidLinkPresenter)
                .environment(\.featureFlags, featureFlags)
                .environment(\.analyticsRecorder, analyticsRecorder)
                .modelContainer(modelContainer)
        }
    }
}

private struct SiftLaunchOptions {
    let useMockServices: Bool
    let useEmptyStore: Bool
    let resetOnboarding: Bool
    let forceOnboardingComplete: Bool
    let confirmCancellationOnRefresh: Bool
    let includeSandboxAccount: Bool

    static var current: SiftLaunchOptions {
        let arguments = ProcessInfo.processInfo.arguments
        return SiftLaunchOptions(
            useMockServices: arguments.contains("-siftUseMockServices"),
            useEmptyStore: arguments.contains("-siftUseEmptyStore"),
            resetOnboarding: arguments.contains("-siftResetOnboarding"),
            forceOnboardingComplete: arguments.contains("-siftOnboardingComplete"),
            confirmCancellationOnRefresh: arguments.contains("-siftMockConfirmCancellationOnRefresh"),
            includeSandboxAccount: arguments.contains("-siftMockSandboxAccount")
        )
    }
}
