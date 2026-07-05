import XCTest

final class SiftUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTabsAndDetailSheet() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-siftUseMockServices",
            "-siftOnboardingComplete",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["home-title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["dashboard-monthly-total"].waitForExistence(timeout: 2))
        app.swipeDown()
        XCTAssertTrue(app.descendants(matching: .any)["dashboard-monthly-total"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Subscriptions"].tap()
        XCTAssertTrue(app.staticTexts["subscriptions-title"].waitForExistence(timeout: 2))

        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.staticTexts["insights-title"].waitForExistence(timeout: 2))

        app.tabBars.buttons["Subscriptions"].tap()
        XCTAssertTrue(app.buttons["sample-subscription-row"].waitForExistence(timeout: 2))
        app.buttons["sample-subscription-row"].tap()

        XCTAssertTrue(app.staticTexts["detail-sheet-title"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Streamline+"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["detail-cancel-button"].waitForExistence(timeout: 2))

        app.buttons["Done"].tap()
        XCTAssertFalse(app.staticTexts["detail-sheet-title"].waitForExistence(timeout: 1))
    }

    @MainActor
    func testConciergeCancellationFlowConfirmsAndRemovesSubscription() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-siftUseMockServices",
            "-siftOnboardingComplete",
            "-siftMockConfirmCancellationOnRefresh",
            "-siftConciergeEnabled",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["home-title"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Subscriptions"].tap()
        XCTAssertTrue(app.buttons["sample-subscription-row"].waitForExistence(timeout: 2))
        app.buttons["sample-subscription-row"].tap()

        XCTAssertTrue(app.buttons["detail-cancel-button"].waitForExistence(timeout: 2))
        app.buttons["detail-cancel-button"].tap()

        XCTAssertTrue(app.buttons["cancel-concierge-option"].waitForExistence(timeout: 2))
        app.buttons["cancel-concierge-option"].tap()

        XCTAssertTrue(app.staticTexts["concierge-status-title"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["concierge-refresh-status"].waitForExistence(timeout: 2))
        app.buttons["concierge-refresh-status"].tap()

        XCTAssertTrue(app.staticTexts["cancel-confirmed-title"].waitForExistence(timeout: 2))
        app.buttons["cancel-confirmed-done"].tap()

        XCTAssertFalse(app.buttons["sample-subscription-row"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testGuidedOnlyLaunchShowsConciergeComingSoon() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-siftUseMockServices",
            "-siftOnboardingComplete",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["home-title"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Subscriptions"].tap()
        XCTAssertTrue(app.buttons["sample-subscription-row"].waitForExistence(timeout: 2))
        app.buttons["sample-subscription-row"].tap()

        XCTAssertTrue(app.buttons["detail-cancel-button"].waitForExistence(timeout: 2))
        app.buttons["detail-cancel-button"].tap()

        XCTAssertTrue(app.buttons["cancel-guided-option"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Concierge coming soon"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testMockOnboardingHappyPathReachesDashboard() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-siftUseMockServices",
            "-siftUseEmptyStore",
            "-siftResetOnboarding",
        ]
        app.launch()

        XCTAssertTrue(app.buttons["onboarding-get-started"].waitForExistence(timeout: 5))

        app.buttons["onboarding-get-started"].tap()
        app.buttons["onboarding-connect-account"].tap()
        app.buttons["bank-ins_56"].tap()
        app.buttons["onboarding-continue-plaid"].tap()

        XCTAssertTrue(app.buttons["onboarding-confirm-subscriptions"].waitForExistence(timeout: 5))
        app.buttons["onboarding-confirm-subscriptions"].tap()

        XCTAssertTrue(app.buttons["onboarding-allow-notifications"].waitForExistence(timeout: 2))
        app.buttons["onboarding-allow-notifications"].tap()

        XCTAssertTrue(app.buttons["onboarding-go-dashboard"].waitForExistence(timeout: 2))
        app.buttons["onboarding-go-dashboard"].tap()

        XCTAssertTrue(app.staticTexts["home-title"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testAlertTogglePersistsAcrossRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-siftOnboardingComplete",
        ]
        app.launch()

        openNotifications(in: app)
        let toggle = app.descendants(matching: .any)["alert-weekly-summary-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 2))
        if toggle.value as? String == "On" {
            toggle.tap()
        }
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "On")

        app.terminate()
        app.launch()

        openNotifications(in: app)
        let relaunchedToggle = app.descendants(matching: .any)["alert-weekly-summary-toggle"]
        XCTAssertTrue(relaunchedToggle.waitForExistence(timeout: 2))
        XCTAssertEqual(relaunchedToggle.value as? String, "On")
    }

    @MainActor
    func testAddSandboxAccountFromSettings() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-siftUseMockServices",
            "-siftUseEmptyStore",
            "-siftOnboardingComplete",
            "-siftMockSandboxAccount",
        ]
        app.launch()

        XCTAssertTrue(app.buttons["home-profile-button"].waitForExistence(timeout: 5))
        app.buttons["home-profile-button"].tap()
        XCTAssertTrue(app.buttons["settings-linked-accounts"].waitForExistence(timeout: 2))
        app.buttons["settings-linked-accounts"].tap()

        XCTAssertTrue(app.staticTexts["linked-accounts-title"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["linked-accounts-add"].waitForExistence(timeout: 2))
        app.buttons["linked-accounts-add"].tap()

        XCTAssertTrue(app.staticTexts["Sandbox Bank"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testSettingsShowsSupportAbout() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-siftUseMockServices",
            "-siftOnboardingComplete",
        ]
        app.launch()

        XCTAssertTrue(app.buttons["home-profile-button"].waitForExistence(timeout: 5))
        app.buttons["home-profile-button"].tap()

        let feedbackButton = app.buttons["settings-support-feedback"]
        for _ in 0..<4 where !feedbackButton.exists {
            app.swipeUp()
        }

        XCTAssertTrue(feedbackButton.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["settings-support-version"].waitForExistence(timeout: 2))
    }

    private func openNotifications(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["home-profile-button"].waitForExistence(timeout: 5))
        app.buttons["home-profile-button"].tap()
        XCTAssertTrue(app.buttons["settings-notifications"].waitForExistence(timeout: 2))
        app.buttons["settings-notifications"].tap()
    }
}
