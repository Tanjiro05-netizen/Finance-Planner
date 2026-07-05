import Testing
@testable import Sift

@MainActor
struct NotificationRouterTests {
    @Test func renewalPayloadRoutesToSubscriptionDetail() {
        let model = AppModel()
        let router = NotificationRouter()
        router.setRouteHandler { deepLink in
            model.handle(deepLink)
        }

        let didRoute = router.route(userInfo: SiftNotificationPayload.userInfo(
            kind: .renewal,
            subscriptionID: SampleRouteID.subscription
        ))

        #expect(didRoute)
        #expect(model.selectedTab == .subscriptions)
        #expect(model.sheet == .subscriptionDetail(id: SampleRouteID.subscription))
    }

    @Test func trialPayloadRoutesToSubscriptionDetail() {
        let model = AppModel()
        let router = NotificationRouter()
        router.setRouteHandler { deepLink in
            model.handle(deepLink)
        }

        let didRoute = router.route(userInfo: SiftNotificationPayload.userInfo(
            kind: .trialEnding,
            subscriptionID: "trial-subscription"
        ))

        #expect(didRoute)
        #expect(model.selectedTab == .subscriptions)
        #expect(model.sheet == .subscriptionDetail(id: "trial-subscription"))
    }

    @Test func priceChangePayloadRoutesToInsights() {
        let model = AppModel()
        let router = NotificationRouter()
        router.setRouteHandler { deepLink in
            model.handle(deepLink)
        }

        let didRoute = router.route(userInfo: SiftNotificationPayload.userInfo(kind: .priceChange))

        #expect(didRoute)
        #expect(model.selectedTab == .insights)
    }

    @Test func weeklySummaryPayloadRoutesToDashboard() {
        let model = AppModel()
        model.select(tab: .subscriptions)
        let router = NotificationRouter()
        router.setRouteHandler { deepLink in
            model.handle(deepLink)
        }

        let didRoute = router.route(userInfo: SiftNotificationPayload.userInfo(kind: .weeklySummary))

        #expect(didRoute)
        #expect(model.selectedTab == .home)
    }
}
