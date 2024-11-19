//
//  PinnedTabsTests.swift
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

class PinnedTabsTests: UITestCase {
    private static let failureObserver = TestFailureObserver()
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"
        app.launch()

        app.typeKey("n", modifierFlags: .command)
    }

    override class func setUp() {
        super.setUp()
        UITests.firstRun()
    }

    func testPinnedTabsFunctionality() {
        openThreeSitesOnSameWindow()
        openNewWindowAndLoadSite()
        moveBackToPreviousWindows()

        waitForSite(pageTitle: "Page #3")
        pinsPageOne()
        pinsPageTwo()
        assertsPageTwoIsPinned()
        assertsPageOneIsPinned()
        dragsPageTwoPinnedTabToTheFirstPosition()
        assertsCommandWFunctionality()
        assertWindowTwoHasTheTwoPinnedTabFromWindowsOne()
        app.terminate()
        assertPinnedTabsRestoredState()
    }

    // MARK: - Utilities

    private func openThreeSitesOnSameWindow() {
        openSite(pageTitle: "Page #1")
        app.openNewTab()
        openSite(pageTitle: "Page #2")
        app.openNewTab()
        openSite(pageTitle: "Page #3")
    }

    private func openNewWindowAndLoadSite() {
        app.typeKey("n", modifierFlags: .command)
        openSite(pageTitle: "Page #4")
    }

    private func moveBackToPreviousWindows() {
        let menuItem = app.menuItems["Page #3"].firstMatch
        XCTAssertTrue(
            menuItem.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Reset bookmarks menu item didn't become available in a reasonable timeframe."
        )
        menuItem.hover()
        app.typeKey(XCUIKeyboardKey.return, modifierFlags: [])
    }

    private func openSite(pageTitle: String) {
        let url = UITests.simpleServedPage(titled: pageTitle)
        let addressBarTextField = app.windows.firstMatch.textFields["AddressBarViewController.addressBarTextField"]
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The address bar text field didn't become available in a reasonable timeframe."
        )
        addressBarTextField.typeURL(url)
        XCTAssertTrue(
            app.windows.firstMatch.webViews[pageTitle].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )
    }

    private func pinsPageOne() {
        app.typeKey("[", modifierFlags: [.command, .shift])
        app.typeKey("[", modifierFlags: [.command, .shift])
        app.menuItems["Pin Tab"].tap()
    }

    private func pinsPageTwo() {
        app.typeKey("]", modifierFlags: [.command, .shift])
        app.menuItems["Pin Tab"].tap()
    }

    private func assertsPageTwoIsPinned() {
        XCTAssertTrue(app.menuItems["Unpin Tab"].firstMatch.waitForExistence(timeout: UITests.Timeouts.elementExistence))
        XCTAssertTrue(app.menuItems["Unpin Tab"].firstMatch.exists)
        XCTAssertFalse(app.menuItems["Pin Tab"].firstMatch.exists)
    }

    private func assertsPageOneIsPinned() {
        app.typeKey("[", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.menuItems["Unpin Tab"].firstMatch.exists)
        XCTAssertFalse(app.menuItems["Pin Tab"].firstMatch.exists)
    }

    private func dragsPageTwoPinnedTabToTheFirstPosition() {
        app.typeKey("]", modifierFlags: [.command, .shift])
        let toolbar = app.toolbars.firstMatch
        let toolbarCoordinate = toolbar.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let startPoint = toolbarCoordinate.withOffset(CGVector(dx: 120, dy: 15))
        let endPoint = toolbarCoordinate.withOffset(CGVector(dx: 0, dy: 0))
        startPoint.press(forDuration: 0, thenDragTo: endPoint)

        sleep(1)

        /// Asserts the re-order worked by moving to the next tab and checking is Page #1
        app.typeKey("]", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.staticTexts["Sample text for Page #1"].exists)
    }

    private func assertsCommandWFunctionality() {
        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["Sample text for Page #3"].exists)
    }

    private func assertWindowTwoHasTheTwoPinnedTabFromWindowsOne() {
        let items = app.menuItems.matching(identifier: "Page #4")
        let pageFourMenuItem = items.element(boundBy: 1)
        XCTAssertTrue(
            pageFourMenuItem.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Reset bookmarks menu item didn't become available in a reasonable timeframe."
        )
        pageFourMenuItem.hover()
        app.typeKey(XCUIKeyboardKey.return, modifierFlags: [])

        sleep(2)

        /// Goes to Page #2 to check the state
        app.typeKey("[", modifierFlags: [.command, .shift])
        app.typeKey("[", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.staticTexts["Sample text for Page #2"].exists)
        /// Goes to Page #1 to check the state
        app.typeKey("]", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.staticTexts["Sample text for Page #1"].exists)
    }

    private func assertPinnedTabsRestoredState() {
        let newApp = XCUIApplication()
        newApp.launch()
        newApp.typeKey("n", modifierFlags: .command)
        sleep(10) // This was increased from two to ten, because slower VMs needed more time to re-launch the app.

        /// Goes to Page #2 to check the state
        newApp.typeKey("[", modifierFlags: [.command, .shift])
        newApp.typeKey("[", modifierFlags: [.command, .shift])
        XCTAssertTrue(newApp.staticTexts["Sample text for Page #2"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
        /// Goes to Page #1 to check the state
        newApp.typeKey("]", modifierFlags: [.command, .shift])
        XCTAssertTrue(newApp.staticTexts["Sample text for Page #1"].waitForExistence(timeout: UITests.Timeouts.elementExistence))
    }

    private func waitForSite(pageTitle: String) {
        XCTAssertTrue(app.windows.webViews[pageTitle].waitForExistence(timeout: UITests.Timeouts.elementExistence))
    }
}
