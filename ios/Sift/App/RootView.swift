import SwiftUI
import Symbols
import UIKit

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.apiClient) private var apiClient
    @Environment(\.detectionService) private var detectionService
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
    @State private var showNotificationPermissionBanner = false
    @State private var dismissedNotificationPermissionBanner = false

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
                    notificationScheduler: notificationScheduler
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
                    notificationScheduler: notificationScheduler
                )
                    .withInsightsDestinations()
            }
        } label: {
            tabLabel(for: .insights, selectedTab: selectedTab)
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
