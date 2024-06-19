//
//  PIRCriticalPathUITests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import XCTest
import WebKit

extension XCUIElement {
    /// Timeout constants for different test requirements
    enum Timeouts {
        /// Mostly, we use timeouts to wait for element existence. This is about 3x longer than needed, for CI resilience
        static let elementExistence: Double = 5.0
    }

    @discardableResult
    func assertExists(with timeout: TimeInterval = Timeouts.elementExistence) -> XCUIElement {
        XCTAssertTrue(waitForExistence(timeout: timeout), "UI element didn't become available in a reasonable timeframe.")
        return self
    }
}

final class PIRCriticalPathUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        // Launch App
        app = XCUIApplication(bundleIdentifier: "com.duckduckgo.macos.browser.debug")
//        app.launchEnvironment["UITEST_MODE"] = "1"
        app.launch()
        if app.windows.count == 0 {
            app.menuItems["newWindow:"].click()
        }
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSaveProfileStartsScan() throws {

//        clearPIRData()

        // Open PIR
        openPIR()

        // Wait for WebView
        waitForPIR()

        enterProfileName()

        selectAge()

        enterAddress()

        beginScan()
    }

}

private extension PIRCriticalPathUITests {

    func clearPIRData() {
        let menuBarsQuery = app.menuBars

        menuBarsQuery.menuBarItems["Debug"].assertExists().click()

        menuBarsQuery.menuItems["Personal Information Removal"].assertExists().click()

        menuBarsQuery.menuItems["Reset All State and Delete All Data"].assertExists().click()

        print(app.debugDescription)
    }

    func waitForPIR() {
        let webView = app.groups["webview.dpb"]
        let exists = webView.waitForExistence(timeout: 10)
        XCTAssertTrue(exists)
    }

    func enterProfileName() {
        app.groups["webview.dpb"].buttons["Get Started"].tap()

        let exists = app.groups["webview.dpb"].textFields["First name *"].waitForExistence(timeout: 3)
        XCTAssertTrue(exists)

        app.groups["webview.dpb"].textFields["First name *"].tap()
        app.groups["webview.dpb"].textFields["First name *"].typeText("Pete")
        app.groups["webview.dpb"].textFields["Last name *"].tap()
        app.groups["webview.dpb"].textFields["Last name *"].typeText("Smith")

        app.groups["webview.dpb"].buttons["Continue"].tap()
        app.groups["webview.dpb"].buttons["Continue"].tap()
    }

    func selectAge() {
        app.groups["webview.dpb"].popUpButtons["Select"].waitForExistence(timeout: 3)
        app.groups["webview.dpb"].popUpButtons["Select"].tap()


        app.groups["webview.dpb"].staticTexts["1999"].waitForExistence(timeout: 3)
        app.groups["webview.dpb"].staticTexts["1999"].tap()

        app.groups["webview.dpb"].buttons["Continue"].tap()
    }

    func enterAddress() {
        let exists = app.groups["webview.dpb"].textFields["City"].waitForExistence(timeout: 3)
        XCTAssertTrue(exists)

        app.groups["webview.dpb"].textFields["City"].tap()
        app.groups["webview.dpb"].textFields["City"].typeText("Miami")

        print(app.debugDescription)

        app.groups["webview.dpb"].popUpButtons["Select a state..."].waitForExistence(timeout: 3)
        app.groups["webview.dpb"].popUpButtons["Select a state..."].tap()

        app.groups["webview.dpb"].staticTexts["Florida"].waitForExistence(timeout: 3)
        app.groups["webview.dpb"].staticTexts["Florida"].tap()

        app.groups["webview.dpb"].buttons["Continue"].tap()

        print(app.debugDescription)
    }

    func beginScan() {
        let exists = app.groups["webview.dpb"].buttons["Begin Scan"].waitForExistence(timeout: 3)
        XCTAssertTrue(exists)

        app.groups["webview.dpb"].buttons["Begin Scan"].tap()
    }

    func confirmScanStarted() {
        let exists = app.groups["webview.dpb"].buttons["Begin Scan"].waitForExistence(timeout: 3)

        print(app.debugDescription)

        app.groups["webview.dpb"].buttons["Begin Scan"].tap()
    }

    func openPIR() {
        app.buttons["NavigationBarViewController.optionsButton"].click()
        app.menuItems["optionsMenu.pir"].click()
    }
}
