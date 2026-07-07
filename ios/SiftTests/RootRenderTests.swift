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
}
