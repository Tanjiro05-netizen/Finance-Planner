@testable import Sift
import SwiftUI
import Testing
import UIKit

@MainActor
struct RoutingTests {
    @Test func routesAreHashable() {
        #expect(Set(HomeRoute.allCases).contains(.settings))
        #expect(Set(SubscriptionsRoute.samples).contains(.detail(id: SampleRouteID.subscription)))
        #expect(Set(InsightsRoute.allCases).contains(.savingsBreakdown))
    }

    @Test func sheetsAreIdentifiable() {
        let sheets = AppSheet.samples
        let ids = Set(sheets.map(\.id))

        #expect(ids.count == sheets.count)
        #expect(ids.contains("subscription-detail-\(SampleRouteID.subscription)"))
        #expect(ids.contains("cancellation-\(SampleRouteID.subscription)"))
    }

    @Test func routeDestinationsBuild() {
        let model = AppModel()

        for route in HomeRoute.allCases {
            assertBuilds(RouteDestination.home(route).environment(model))
        }

        for route in SubscriptionsRoute.samples {
            assertBuilds(RouteDestination.subscriptions(route).environment(model))
        }

        for route in InsightsRoute.allCases {
            assertBuilds(RouteDestination.insights(route).environment(model))
        }
    }

    @Test func sheetDestinationsBuild() {
        let model = AppModel()

        for sheet in AppSheet.samples {
            assertBuilds(RouteDestination.sheet(
                sheet,
                repositories: .mock(),
                apiClient: MockSiftAPIClient(),
                detectionService: MockDetectionService()
            ).environment(model))
        }
    }

    private func assertBuilds(_ view: some View) {
        let controller = UIHostingController(rootView: view)
        controller.loadViewIfNeeded()

        #expect(controller.view != nil)
    }
}
