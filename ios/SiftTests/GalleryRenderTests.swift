import SwiftUI
import Testing
import UIKit
@testable import Sift

struct GalleryRenderTests {
    @Test @MainActor func componentGalleryBuildsWithoutRuntimeErrors() {
        let controller = UIHostingController(rootView: ComponentGalleryView())
        controller.loadViewIfNeeded()

        #expect(controller.view != nil)
        #expect(controller.view.intrinsicContentSize != .zero)
    }
}
