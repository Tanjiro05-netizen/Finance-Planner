import SwiftUI
import Symbols
import UIKit

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.apiClient) private var apiClient
    @Environment(\.detectionService) private var detectionService
    @Environment(\.incomeDetectionService) private var incomeDetectionService
    @Environment(\.notificationAuthorizer) private var notificationAuthorizer
    @Environment(\.notificationRouter) private var notificationRouter
    @Environment(\.notificationScheduler) private var notificationScheduler
    @Environment(\.onboardingStateStore) private var onboardingStateStore
    @Environment(\.openURL) private var openURL
    @Environment(\.plaidLinkPresenter) private var plaidLinkPresenter
    @Environment(\.repositories) private var repositories
    @Environment(\.featureFlags) private var featureFlags
    @Environment(\.analyticsRecorder) private var analyticsRecorder
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.biometricAuthenticator) private var biometricAuthenticator
    @Environment(\.appLockEnabled) private var appLockEnabled
    @Environment(\.scenePhase) private var scenePhase
    @State private var showNotificationPermissionBanner = false
    @State private var dismissedNotificationPermissionBanner = false
    @State private var isUnlocked = false
    @State private var isAuthenticating = false

    var body: some View {
        @Bindable var model = appModel

        Group {
            if model.isOnboardingComplete {
                tabContent(model: model)
            } else {
                OnboardingFlowView(
                    apiClient: apiClient,
                    linkPresenter: plaidLinkPresenter,
                    detectionService: detectionService,
                    notificationAuthorizer: notificationAuthorizer,
                    notificationScheduler: notificationScheduler,
                    repositories: repositories,
                    stateStore: onboardingStateStore
                ) {
                    appModel.completeOnboarding()
                }
            }
        }
        .background(Palette.bone.ignoresSafeArea())
        .overlay(alignment: .top) {
            if model.isOnboardingComplete, showNotificationPermissionBanner {
                NotificationPermissionBanner {
                    openNotificationSettings()
                } dismiss: {
                    dismissedNotificationPermissionBanner = true
                    showNotificationPermissionBanner = false
                }
                .padding(.top, Spacing.md)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Motion.reduced(Motion.gentle, reduceMotion: reduceMotion), value: showNotificationPermissionBanner)
        .task(id: model.isOnboardingComplete) {
            notificationRouter.setRouteHandler { deepLink in
                appModel.handle(deepLink)
            }
            await updateNotificationPermissionBanner(isOnboardingComplete: model.isOnboardingComplete)
        }
        .overlay {
            if lockActive, !isUnlocked {
                LockView(isAuthenticating: isAuthenticating) {
                    Task { await authenticate() }
                }
                .transition(.opacity)
            }
        }
        .animation(Motion.reduced(Motion.gentle, reduceMotion: reduceMotion), value: isUnlocked)
        .task { await authenticateIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                isUnlocked = false
            case .active:
                Task { await authenticateIfNeeded() }
            default:
                break
            }
        }
    }

    private var lockActive: Bool {
        appLockEnabled && biometricAuthenticator.canAuthenticate()
    }

    private func authenticateIfNeeded() async {
        guard lockActive, !isUnlocked, !isAuthenticating else {
            return
        }
        await authenticate()
    }

    private func authenticate() async {
        guard !isAuthenticating else {
            return
        }
        isAuthenticating = true
        let unlocked = await biometricAuthenticator.authenticate(
            reason: "Unlock Sift to see your subscriptions and balances."
        )
        isAuthenticating = false
        if unlocked {
            isUnlocked = true
        }
    }

    private func tabContent(model: AppModel) -> some View {
        @Bindable var model = model

        return ZStack {
            tabShell(model: model)

            if model.sheet != nil {
                Color.black
                    .opacity(0.34)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
        .animation(Motion.reduced(Motion.sheet, reduceMotion: reduceMotion), value: model.sheet)
        .sheet(item: $model.sheet) { sheet in
            RouteDestination.sheet(
                sheet,
                repositories: repositories,
                apiClient: apiClient,
                detectionService: detectionService,
                notificationScheduler: notificationScheduler,
                featureFlags: featureFlags,
                analyticsRecorder: analyticsRecorder
            )
            .environment(appModel)
        }
    }

    private func tabShell(model: AppModel) -> some View {
        @Bindable var model = model

        return TabView(selection: $model.selectedTab) {
            homeTab(path: $model.homePath, selectedTab: model.selectedTab)
            subscriptionsTab(path: $model.subscriptionsPath, selectedTab: model.selectedTab)
            insightsTab(path: $model.insightsPath, selectedTab: model.selectedTab)
            if featureFlags.ledgerEnabled {
                transactionsTab(path: $model.transactionsPath, selectedTab: model.selectedTab)
            }
        }
        .tabViewStyle(.automatic)
        .tint(Palette.goldDeep)
        .sensoryFeedback(.selection, trigger: model.selectedTab)
    }

    private func homeTab(path: Binding<NavigationPath>, selectedTab: AppTab) -> some TabContent<AppTab> {
        Tab(value: AppTab.home) {
            NavigationStack(path: path) {
                HomeView(
                    repositories: repositories,
                    apiClient: apiClient,
                    detectionService: detectionService,
                    incomeDetectionService: incomeDetectionService,
                    notificationScheduler: notificationScheduler,
                    featureFlags: featureFlags
                )
                .withHomeDestinations()
            }
        } label: {
            tabLabel(for: .home, selectedTab: selectedTab)
        }
    }

    private func subscriptionsTab(path: Binding<NavigationPath>, selectedTab: AppTab) -> some TabContent<AppTab> {
        Tab(value: AppTab.subscriptions) {
            NavigationStack(path: path) {
                SubscriptionsView(
                    repositories: repositories,
                    apiClient: apiClient,
                    detectionService: detectionService,
                    incomeDetectionService: incomeDetectionService,
                    notificationScheduler: notificationScheduler
                )
                .withSubscriptionsDestinations()
            }
        } label: {
            tabLabel(for: .subscriptions, selectedTab: selectedTab)
        }
    }

    private func insightsTab(path: Binding<NavigationPath>, selectedTab: AppTab) -> some TabContent<AppTab> {
        Tab(value: AppTab.insights) {
            NavigationStack(path: path) {
                InsightsView(
                    repositories: repositories,
                    apiClient: apiClient,
                    detectionService: detectionService,
                    incomeDetectionService: incomeDetectionService,
                    notificationScheduler: notificationScheduler
                )
                .withInsightsDestinations()
            }
        } label: {
            tabLabel(for: .insights, selectedTab: selectedTab)
        }
    }

    private func transactionsTab(path: Binding<NavigationPath>, selectedTab: AppTab) -> some TabContent<AppTab> {
        Tab(value: AppTab.transactions) {
            NavigationStack(path: path) {
                TransactionsView(repositories: repositories)
            }
        } label: {
            tabLabel(for: .transactions, selectedTab: selectedTab)
        }
    }

    private func tabLabel(for tab: AppTab, selectedTab: AppTab) -> some View {
        Label(tab.title, systemImage: tab.symbol(isSelected: tab == selectedTab))
            .contentTransition(.symbolEffect(.replace))
    }

    @MainActor
    private func updateNotificationPermissionBanner(isOnboardingComplete: Bool) async {
        guard isOnboardingComplete, !dismissedNotificationPermissionBanner else {
            showNotificationPermissionBanner = false
            return
        }

        showNotificationPermissionBanner = await notificationScheduler.authorizationState() == .denied
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        openURL(url)
    }
}

#Preview {
    RootView()
        .environment(AppModel())
        .environment(\.repositories, .mock())
}

/// Full-screen gate shown until the person authenticates with Face ID, Touch ID, or
/// their device passcode. Covers all content so balances aren't visible while locked.
struct LockView: View {
    let isAuthenticating: Bool
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            Palette.bone.ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Palette.bone)
                    .frame(width: 64, height: 64)
                    .background(Palette.ink, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))

                VStack(spacing: Spacing.sm) {
                    Text("Sift is locked")
                        .font(.screenTitle)
                        .foregroundStyle(Palette.ink)
                    Text("Authenticate to see your subscriptions and balances.")
                        .font(.siftBody)
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                }

                PrimaryButton(title: isAuthenticating ? "Unlocking" : "Unlock", action: onUnlock)
                    .disabled(isAuthenticating)
                    .padding(.horizontal, Spacing.xl)
            }
            .padding(Spacing.xl)
        }
        .accessibilityIdentifier("app-lock")
    }
}

extension EnvironmentValues {
    @Entry var biometricAuthenticator: any BiometricAuthenticating = MockBiometricAuthenticator(available: false)

    @Entry var appLockEnabled: Bool = false
}
