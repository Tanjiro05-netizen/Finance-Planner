import SwiftUI
import Testing
import UIKit
@testable import Sift

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
}
