import XCTest

/// Base class for all Reef UI tests.
/// Launches the app with --uitesting flag (disables auto dev-login).
class ReefUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDown() {
        app = nil
    }

    // MARK: - Helpers

    @discardableResult
    func waitForElement(
        _ element: XCUIElement,
        timeout: TimeInterval = 5
    ) -> XCUIElement {
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, "Expected element to exist within \(timeout)s")
        return element
    }

    /// Wait for any element containing the given text.
    @discardableResult
    func waitForText(_ text: String, timeout: TimeInterval = 5) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        let element = app.descendants(matching: .any).matching(predicate).firstMatch
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, "Expected text '\(text)' to exist within \(timeout)s")
        return element
    }

    /// Tap "Dev Login" to bypass auth (only works in DEBUG builds with --uitesting).
    func devLogin() {
        let devLogin = waitForText("Dev Login", timeout: 15)
        devLogin.tap()
    }
}
