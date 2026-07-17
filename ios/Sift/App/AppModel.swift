import Observation
import SwiftUI

@MainActor
@Observable
final class AppModel {
    var isOnboardingComplete: Bool
    var selectedTab: AppTab = .home
    var homePath = NavigationPath()
    var subscriptionsPath = NavigationPath()
    var insightsPath = NavigationPath()
    var transactionsPath = NavigationPath()
    var sheet: AppSheet?

    init(isOnboardingComplete: Bool = false) {
        self.isOnboardingComplete = isOnboardingComplete
    }

    func completeOnboarding() {
        isOnboardingComplete = true
    }

    func returnToOnboarding() {
        isOnboardingComplete = false
        selectedTab = .home
        homePath = NavigationPath()
        subscriptionsPath = NavigationPath()
        insightsPath = NavigationPath()
        transactionsPath = NavigationPath()
        sheet = nil
    }

    func select(tab: AppTab) {
        selectedTab = tab
    }

    func present(_ sheet: AppSheet) {
        self.sheet = sheet
    }

    func dismissSheet() {
        sheet = nil
    }

    func push(_ route: HomeRoute, in tab: AppTab = .home) {
        guard tab == .home else {
            return
        }

        homePath.append(route)
    }

    func push(_ route: SubscriptionsRoute, in tab: AppTab = .subscriptions) {
        guard tab == .subscriptions else {
            return
        }

        subscriptionsPath.append(route)
    }

    func push(_ route: InsightsRoute, in tab: AppTab = .insights) {
        guard tab == .insights else {
            return
        }

        insightsPath.append(route)
    }

    func handle(_ deepLink: DeepLink) {
        switch deepLink {
        case .home:
            select(tab: .home)
        case .subscriptions:
            select(tab: .subscriptions)
        case .insights:
            select(tab: .insights)
        case .transactions:
            select(tab: .transactions)
        case .settings:
            select(tab: .home)
            push(.settings, in: .home)
        case let .subscriptionDetail(id):
            select(tab: .subscriptions)
            present(.subscriptionDetail(id: id))
        case let .cancellation(subscriptionID):
            select(tab: .subscriptions)
            present(.cancellation(subscriptionID: subscriptionID))
        }
    }

    func pathCount(for tab: AppTab) -> Int {
        switch tab {
        case .home:
            homePath.count
        case .subscriptions:
            subscriptionsPath.count
        case .insights:
            insightsPath.count
        case .transactions:
            transactionsPath.count
        }
    }
}
