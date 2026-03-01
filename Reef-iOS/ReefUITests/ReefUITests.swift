//
//  ReefUITests.swift
//  ReefUITests
//

import XCTest

final class ReefUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
    }
}
