import XCTest

final class DashboardNavigationTests: ReefUITestCase {

    override func setUp() {
        super.setUp()
        devLogin()
        waitForText("Documents", timeout: 5)
    }

    // MARK: - Tab Navigation

    func testDocumentsTabVisibleByDefault() {
        waitForText("Coming soon")
    }

    func testCanSwitchToAnalyticsTab() {
        waitForText("Analytics").tap()
        sleep(1)
        waitForText("Coming soon")
    }

    func testCanSwitchToTutorsTab() {
        waitForText("Tutors").tap()
        sleep(1)
        waitForText("Coming soon")
    }

    func testCanNavigateBackToDocuments() {
        waitForText("Analytics").tap()
        sleep(1)
        waitForText("Documents").tap()
        sleep(1)
        waitForText("Coming soon")
    }

    // MARK: - Header & Chrome

    func testHeaderShowsDashboardBreadcrumb() {
        waitForText("Dashboard")
    }

    func testDarkModeToggleExists() {
        let lightToggle = app.buttons["Switch to dark mode"]
        let darkToggle = app.buttons["Switch to light mode"]
        XCTAssertTrue(lightToggle.exists || darkToggle.exists)
    }

    func testFooterShowsUpgrade() {
        waitForText("Upgrade")
    }

    func testSidebarShowsReefBranding() {
        waitForText("REEF")
    }

    func testSidebarToggleExists() {
        let toggle = app.buttons["Toggle sidebar"]
        XCTAssertTrue(toggle.exists)
    }
}
