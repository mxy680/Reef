import XCTest

final class NotificationDropdownTests: ReefUITestCase {

    override func setUp() {
        super.setUp()
        devLogin()
        waitForText("Documents", timeout: 5)
    }

    func testTapBellShowsNoNotifications() {
        let bell = app.buttons["Notifications"]
        waitForElement(bell, timeout: 3)
        bell.tap()
        waitForText("No new notifications", timeout: 3)
    }

    func testProfileDropdownStillWorks() {
        let profile = app.buttons["Profile menu"]
        waitForElement(profile, timeout: 3)
        profile.tap()
        waitForText("Log Out", timeout: 3)
    }
}
