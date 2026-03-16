import XCTest

final class AuthFlowTests: ReefUITestCase {

    func testAuthScreenShowsHeading() {
        waitForText("WELCOME TO REEF", timeout: 15)
    }

    func testAuthScreenShowsSubtitle() {
        waitForText("Dive in. Stay afloat. Ace finals.", timeout: 15)
    }

    func testAuthScreenShowsGoogleButton() {
        waitForText("Google", timeout: 15)
    }

    func testAuthScreenShowsAppleButton() {
        waitForText("Apple", timeout: 15)
    }

    func testAuthScreenShowsContinueButton() {
        waitForText("Continue with Email", timeout: 15)
    }

    func testAuthScreenShowsDevLoginButton() {
        waitForText("Dev Login", timeout: 15)
    }

    func testDevLoginTransitionsToDashboard() {
        devLogin()
        // After dev login, "Documents" tab label should appear
        waitForText("Documents", timeout: 5)
    }

    func testEmailFieldAcceptsInput() {
        waitForText("WELCOME TO REEF", timeout: 15)
        let emailField = app.textFields.firstMatch
        waitForElement(emailField, timeout: 5)
        emailField.tap()
        emailField.typeText("test@example.com")
        XCTAssertEqual(emailField.value as? String, "test@example.com")
    }
}
