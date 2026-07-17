@testable import Sift
import SwiftUI
import Testing
import UIKit

@MainActor
struct RootRenderTests {
    @Test func rootViewBuildsWithoutRuntimeErrors() {
        let controller = UIHostingController(
            rootView: RootView()
                .environment(AppModel())
        )

        controller.loadViewIfNeeded()

        #expect(controller.view != nil)
    }

    @Test func rootViewBuildsWithLedgerTabEnabled() {
        let controller = UIHostingController(
            rootView: RootView()
                .environment(AppModel(isOnboardingComplete: true))
                .environment(\.featureFlags, SiftFeatureFlags(conciergeEnabled: false, ledgerEnabled: true))
        )

        controller.loadViewIfNeeded()

        #expect(controller.view != nil)
    }
}
