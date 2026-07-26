import SwiftData
import SwiftUI

@main
struct SiftApp: App {
    @State private var appModel: AppModel

    private let modelContainer: ModelContainer
    private let repositories: RepositoryContainer
    private let apiClient: any SiftAPIClient
    private let plaidLinkPresenter: any PlaidLinkPresenting
    private let detectionService: any DetectionServing
    private let incomeDetectionService: any IncomeDetectionServing
    private let notificationAuthorizer: any NotificationAuthorizing
    private let notificationScheduler: any NotificationScheduling
    private let notificationRouter: NotificationRouter
    private let onboardingStateStore: any OnboardingStateStoring
    private let tokenStore: any TokenStoring
    private let featureFlags: SiftFeatureFlags
    private let analyticsRecorder: any AnalyticsRecording
    private let biometricAuthenticator: any BiometricAuthenticating
    private let appLockEnabled: Bool
    private let backgroundRefreshController: BackgroundRefreshController?

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

        let container: ModelContainer
        do {
            container = try SiftModelContainerFactory.makeContainer(inMemory: launchOptions.useMockServices)
        } catch {
            fatalError("Failed to create the SwiftData model container: \(error)")
        }
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
            incomeDetectionService = MockIncomeDetectionService()
            notificationAuthorizer = MockNotificationAuthorizer()
            biometricAuthenticator = MockBiometricAuthenticator(available: false)
            appLockEnabled = false
        } else {
            configuredRepositories = RepositoryContainer.live(modelContext: container.mainContext)
            let financeStore: any FinancialDataStore = FinanceKitStore()
            apiClient = FinanceKitAPIClient(store: financeStore)
            plaidLinkPresenter = FinanceKitLinkPresenter(store: financeStore)
            detectionService = LiveDetectionService(modelContainer: container)
            incomeDetectionService = LiveIncomeDetectionService(modelContainer: container)
            notificationAuthorizer = UserNotificationAuthorizer()
            biometricAuthenticator = LocalAuthenticationGate()
            appLockEnabled = AppLockPreference().isEnabled
        }

        repositories = configuredRepositories
        notificationScheduler = NotificationScheduler(repositories: configuredRepositories)
        notificationRouter = NotificationRouter(center: .current())

        if launchOptions.useMockServices {
            backgroundRefreshController = nil
        } else {
            let refreshService = DefaultSubscriptionRefreshService(
                apiClient: apiClient,
                detectionService: detectionService,
                repositories: configuredRepositories,
                incomeDetectionService: incomeDetectionService,
                notificationScheduler: notificationScheduler
            )
            let controller = BackgroundRefreshController { [refreshService] in
                _ = try? await refreshService.refresh()
            }
            controller.register()
            backgroundRefreshController = controller
        }

        _appModel = State(initialValue: AppModel(isOnboardingComplete: stateStore.isComplete()))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .environment(\.repositories, repositories)
                .environment(\.apiClient, apiClient)
                .environment(\.detectionService, detectionService)
                .environment(\.incomeDetectionService, incomeDetectionService)
                .environment(\.notificationAuthorizer, notificationAuthorizer)
                .environment(\.notificationScheduler, notificationScheduler)
                .environment(\.notificationRouter, notificationRouter)
                .environment(\.onboardingStateStore, onboardingStateStore)
                .environment(\.tokenStore, tokenStore)
                .environment(\.plaidLinkPresenter, plaidLinkPresenter)
                .environment(\.featureFlags, featureFlags)
                .environment(\.analyticsRecorder, analyticsRecorder)
                .environment(\.biometricAuthenticator, biometricAuthenticator)
                .environment(\.appLockEnabled, appLockEnabled)
                .modelContainer(modelContainer)
                .task { backgroundRefreshController?.schedule() }
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
