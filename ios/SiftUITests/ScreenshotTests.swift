import Foundation
import XCTest

/// Walks the app and attaches a screenshot of every screen worth looking at.
///
/// This exists because nobody can run Sift by hand yet: there is no signing team, no
/// FinanceKit entitlement, and no device build. A macOS CI runner with a simulator is the
/// only machine that renders the app, so the way to *see* a design change is to have the
/// runner photograph it. `screenshots.yml` runs this class and uploads the images.
///
/// Kept in its own class rather than folded into `SiftUITests` so `xcodebuild` can address
/// it with `-only-testing:` and `-skip-testing:`. The walk is slow and asserts almost
/// nothing, so the PR gate skips it and the screenshot workflow runs only it.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        // The assertion suites stop at the first failure on purpose. This one should not:
        // a screen that fails to appear ought to cost one image, not the rest of the walk.
        // A partial set is still worth looking at, and the failure is still reported.
        continueAfterFailure = true
    }

    /// Every flag on, so nothing is hidden behind a gate that ships off.
    ///
    /// Concierge stays off deliberately — "coming soon" is the state that actually ships,
    /// so it is the one worth photographing.
    private static let fullLaunchArguments = [
        "-siftUseMockServices",
        "-siftOnboardingComplete",
        "-siftLedgerEnabled",
        "-siftBudgetsEnabled",
        "-siftGoalsEnabled",
        "-siftInsightNarrationEnabled",
        "-siftAssistantEnabled",
    ]

    @MainActor
    func testCaptureMainScreens() {
        let app = XCUIApplication()
        app.launchArguments = Self.fullLaunchArguments
        app.launch()

        guard capture("01-home", whenReady: anchor(app, "home-title"), timeout: .launch) else {
            return
        }

        // Safe-to-spend is the entry point to the forecast, so this is a tap on the card
        // rather than a route the screenshots know how to reach on their own.
        if app.buttons["safe-to-spend-card"].waitForExistence(timeout: .screen) {
            app.buttons["safe-to-spend-card"].tap()
            capture("02-cash-flow", whenReady: anchor(app, "cash-flow-title"))
            goBack(in: app)
        }

        app.swipeUp()
        capture("03-home-scrolled")

        app.tabBars.buttons["Subscriptions"].tap()
        if capture("04-subscriptions", whenReady: anchor(app, "subscriptions-title")) {
            let row = app.buttons["sample-subscription-row"]
            if row.waitForExistence(timeout: .screen) {
                row.tap()
                capture("05-subscription-detail", whenReady: anchor(app, "detail-sheet-title"))
                app.buttons["Done"].tap()
                _ = anchor(app, "detail-sheet-title").waitToDisappear(timeout: .screen)
            }
        }

        app.tabBars.buttons["Insights"].tap()
        // Insights is the heaviest screen in the app — a six-month ledger read plus three
        // charts — so it gets the launch budget rather than the screen one.
        if capture("06-insights", whenReady: anchor(app, "insights-title"), timeout: .launch) {
            app.swipeUp()
            capture("07-insights-reports")

            captureRoute(in: app, tapping: "insights-budgets-button", named: "08-budgets", waitingFor: "budgets-title")
            captureRoute(in: app, tapping: "insights-goals-button", named: "09-goals", waitingFor: "goals-title")
        }

        app.tabBars.buttons["Transactions"].tap()
        if capture("10-transactions", whenReady: anchor(app, "transactions-title")) {
            let add = app.buttons["transactions-add-button"]
            if add.waitForExistence(timeout: .screen) {
                add.tap()
                if capture("11-manual-entry", whenReady: app.buttons["manual-entry-save"]) {
                    app.buttons["Cancel"].tap()
                    _ = app.buttons["manual-entry-save"].waitToDisappear(timeout: .screen)
                }
            }
        }

        app.tabBars.buttons["Ask"].tap()
        capture("12-ask", whenReady: anchor(app, "assistant-title"))

        // Tapping the already-selected tab a second time pops that tab's stack to root,
        // which is the standard iOS behaviour. Relying on it here guards against a stray
        // pushed screen from an earlier step (forecast, subscription detail) leaving
        // `home-profile-button` off-screen or absent, which is what silently dropped this
        // screen and the one after it before: the old guard had no `else`, so a missed
        // anchor here cost two screenshots and the run still reported success.
        app.tabBars.buttons["Home"].tap()
        app.tabBars.buttons["Home"].tap()

        let settingsEntry = app.buttons["home-profile-button"]
        guard settingsEntry.waitForExistence(timeout: .launch) else {
            XCTFail("Screenshot 13-settings: 'home-profile-button' never appeared.")
            return
        }
        settingsEntry.tap()

        if capture("13-settings", whenReady: anchor(app, "settings-title")) {
            captureRoute(
                in: app,
                tapping: "settings-bills-income",
                named: "14-bills-and-income",
                waitingFor: "bills-income-title"
            )
        }
    }

    /// Onboarding needs its own launch: it only renders on a reset, empty store, which is
    /// the opposite of what every other screen here wants. The sequence mirrors
    /// `SiftUITests.testMockOnboardingHappyPathReachesDashboard`.
    @MainActor
    func testCaptureOnboarding() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-siftUseMockServices",
            "-siftUseEmptyStore",
            "-siftResetOnboarding",
        ]
        app.launch()

        guard capture("20-onboarding-welcome", whenReady: app.buttons["onboarding-get-started"], timeout: .launch) else {
            return
        }

        app.buttons["onboarding-get-started"].tap()
        guard capture("21-onboarding-connect", whenReady: app.buttons["onboarding-connect-account"]) else {
            return
        }

        app.buttons["onboarding-connect-account"].tap()
        app.buttons["onboarding-continue-plaid"].tap()
        guard capture("22-onboarding-review", whenReady: app.buttons["onboarding-confirm-subscriptions"]) else {
            return
        }

        app.buttons["onboarding-confirm-subscriptions"].tap()
        guard capture("23-onboarding-alerts", whenReady: app.buttons["onboarding-allow-notifications"]) else {
            return
        }

        app.buttons["onboarding-allow-notifications"].tap()
        capture("24-onboarding-done", whenReady: app.buttons["onboarding-go-dashboard"])
    }

    // MARK: - Capture

    @MainActor
    private func capture(_ name: String) {
        settle()
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        // Attachments from a test that *passes* are discarded unless the lifetime says
        // otherwise, which would leave the result bundle empty exactly when the walk went
        // well. This one line is what makes the whole job produce anything.
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Waits for `element`, photographs the screen, and reports whether it arrived, so the
    /// caller can skip a branch of the walk whose entry point never showed up.
    @discardableResult
    @MainActor
    private func capture(
        _ name: String,
        whenReady element: XCUIElement,
        timeout: TimeInterval = .screen
    ) -> Bool {
        guard element.waitForExistence(timeout: timeout) else {
            XCTFail("Screenshot \(name): its anchor element never appeared.")
            return false
        }

        capture(name)
        return true
    }

    /// Pushes a route, photographs it, and pops back.
    @MainActor
    private func captureRoute(
        in app: XCUIApplication,
        tapping identifier: String,
        named name: String,
        waitingFor anchorID: String
    ) {
        let entry = app.buttons[identifier]
        guard entry.waitForExistence(timeout: .screen) else {
            XCTFail("Screenshot \(name): no entry point '\(identifier)'.")
            return
        }

        entry.tap()
        if capture(name, whenReady: anchor(app, anchorID)) {
            goBack(in: app)
        }
    }

    /// Screen titles come from `ScreenHeader`, which XCUITest classifies inconsistently —
    /// a static text on some screens, a container on others. Querying any descendant by
    /// identifier sidesteps the question entirely.
    @MainActor
    private func anchor(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// The back button carries the previous screen's title, which varies, so it is taken
    /// positionally: the leading item of a pushed screen's navigation bar is always it.
    @MainActor
    private func goBack(in app: XCUIApplication) {
        let back = app.navigationBars.buttons.firstMatch
        if back.waitForExistence(timeout: .screen) {
            back.tap()
        }
    }

    /// A screenshot taken the instant an element exists catches the push or sheet
    /// transition still running, and a half-slid screen is not worth downloading.
    private func settle() {
        Thread.sleep(forTimeInterval: 0.6)
    }
}
