import SwiftUI

enum RouteDestination {
    @MainActor
    @ViewBuilder
    static func home(_ route: HomeRoute) -> some View {
        switch route {
        case .settings:
            SettingsView()
        case .cashFlowForecast:
            CashFlowForecastRouteView()
        }
    }

    @MainActor
    @ViewBuilder
    static func subscriptions(_ route: SubscriptionsRoute) -> some View {
        switch route {
        case let .detail(id):
            SubscriptionDetailRouteView(subscriptionID: id)
        }
    }

    @MainActor
    @ViewBuilder
    static func insights(_ route: InsightsRoute) -> some View {
        switch route {
        case .savingsBreakdown:
            SavingsBreakdownView()
        case .budgets:
            BudgetsRouteView()
        }
    }

    @MainActor
    @ViewBuilder
    static func sheet(
        _ sheet: AppSheet,
        repositories: RepositoryContainer,
        apiClient: any SiftAPIClient,
        detectionService: any DetectionServing,
        notificationScheduler: any NotificationScheduling = NoopNotificationScheduler(),
        featureFlags: SiftFeatureFlags = .launchDefault,
        analyticsRecorder: any AnalyticsRecording = NoopAnalyticsRecorder()
    ) -> some View {
        switch sheet {
        case let .subscriptionDetail(id):
            DetailSheetView(
                subscriptionID: id,
                repositories: repositories,
                apiClient: apiClient,
                detectionService: detectionService,
                notificationScheduler: notificationScheduler
            )
        case let .cancellation(subscriptionID):
            CancelFlowSheetView(
                subscriptionID: subscriptionID,
                repositories: repositories,
                apiClient: apiClient,
                notificationScheduler: notificationScheduler,
                featureFlags: featureFlags,
                analyticsRecorder: analyticsRecorder
            )
        case .cancellationRequests:
            CancellationRequestsSheetView(
                repositories: repositories,
                apiClient: apiClient,
                notificationScheduler: notificationScheduler
            )
        case .manualTransactionEntry:
            ManualTransactionEntrySheetView(repositories: repositories)
        case let .transactionDetail(id):
            TransactionDetailSheetView(transactionID: id)
        case let .budgetEditor(budgetID):
            BudgetEditorSheetView(budgetID: budgetID, repositories: repositories)
        case .affordabilityCheck:
            AffordabilityCheckSheetView(repositories: repositories)
        }
    }
}

extension View {
    func withHomeDestinations() -> some View {
        navigationDestination(for: HomeRoute.self) { route in
            RouteDestination.home(route)
        }
    }

    func withSubscriptionsDestinations() -> some View {
        navigationDestination(for: SubscriptionsRoute.self) { route in
            RouteDestination.subscriptions(route)
        }
    }

    func withInsightsDestinations() -> some View {
        navigationDestination(for: InsightsRoute.self) { route in
            RouteDestination.insights(route)
        }
    }
}
