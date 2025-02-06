//
//  StateRestorationTests.swift
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

class StateRestorationTests: UITestCase {
    private var app: XCUIApplication!
    private var firstPageTitle: String!
    private var secondPageTitle: String!
    private var firstURLForBookmarksBar: URL!
    private var secondURLForBookmarksBar: URL!
    private let titleStringLength = 12
    private var addressBarTextField: XCUIElement!
    private var settingsGeneralButton: XCUIElement!
    private var openANewWindowPreference: XCUIElement!
    private var reopenAllWindowsFromLastSessionPreference: XCUIElement!

    override class func setUp() {
        super.setUp()
        UITests.firstRun()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"
        firstPageTitle = UITests.randomPageTitle(length: titleStringLength)
        secondPageTitle = UITests.randomPageTitle(length: titleStringLength)
        firstURLForBookmarksBar = UITests.simpleServedPage(titled: firstPageTitle)
        secondURLForBookmarksBar = UITests.simpleServedPage(titled: secondPageTitle)
        addressBarTextField = app.windows.textFields["AddressBarViewController.addressBarTextField"]
        settingsGeneralButton = app.buttons["PreferencesSidebar.generalButton"]
        openANewWindowPreference = app.radioButtons["PreferencesGeneralView.stateRestorePicker.openANewWindow"]
        reopenAllWindowsFromLastSessionPreference = app.radioButtons["PreferencesGeneralView.stateRestorePicker.reopenAllWindowsFromLastSession"]

        app.launch()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Let's enforce a single window
        app.typeKey("n", modifierFlags: .command)
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func test_tabStateAtRelaunch_shouldContainTwoSitesVisitedInPreviousSession_whenReopenAllWindowsFromLastSessionIsSet() {
        addressBarTextField.typeURL(URL(string: "duck://settings")!) // Open settings
        settingsGeneralButton.click(forDuration: 0.5, thenDragTo: settingsGeneralButton)
        reopenAllWindowsFromLastSessionPreference.clickAfterExistenceTestSucceeds()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Close windows
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The address bar text field didn't become available in a reasonable timeframe."
        )
        addressBarTextField.typeURL(firstURLForBookmarksBar)
        XCTAssertTrue(
            app.windows.webViews[firstPageTitle].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Site didn't load with the expected title in a reasonable timeframe."
        )
        app.typeKey("t", modifierFlags: [.command])
        app.typeURL(secondURLForBookmarksBar)
        XCTAssertTrue(
            app.windows.webViews[secondPageTitle].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Site didn't load with the expected title in a reasonable timeframe."
        )

        app.typeKey("q", modifierFlags: [.command])
        app.launch()

        XCTAssertTrue(
            app.windows.webViews[secondPageTitle].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Second visited site wasn't found in a webview with the expected title in a reasonable timeframe."
        )
        app.typeKey("w", modifierFlags: [.command])
        XCTAssertTrue(
            app.windows.webViews[firstPageTitle].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "First visited site wasn't found in a webview with the expected title in a reasonable timeframe."
        )
    }

    func test_tabStateAtRelaunch_shouldContainNoSitesVisitedInPreviousSession_whenReopenAllWindowsFromLastSessionIsUnset() {
        addressBarTextField.typeURL(URL(string: "duck://settings")!) // Open settings
        settingsGeneralButton.click(forDuration: 0.5, thenDragTo: settingsGeneralButton)
        openANewWindowPreference.clickAfterExistenceTestSucceeds()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Close windows
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The address bar text field didn't become available in a reasonable timeframe."
        )
        addressBarTextField.typeURL(firstURLForBookmarksBar)
        XCTAssertTrue(
            app.windows.webViews[firstPageTitle].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Site didn't load with the expected title in a reasonable timeframe."
        )
        app.typeKey("t", modifierFlags: [.command])
        app.typeURL(secondURLForBookmarksBar)
        XCTAssertTrue(
            app.windows.webViews[secondPageTitle].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Site didn't load with the expected title in a reasonable timeframe."
        )

        app.terminate()
        app.launch()

        XCTAssertTrue(
            app.windows.webViews[secondPageTitle].waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "Second visited site from previous session should not be in any webview."
        )
        XCTAssertTrue(
            app.windows.webViews[firstPageTitle].waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "First visited site from previous session should not be in any webview."
        )
        app.typeKey("w", modifierFlags: [.command])
        XCTAssertTrue(
            app.windows.webViews[firstPageTitle].waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "First visited site from previous session should not be in any webview."
        )
        XCTAssertTrue(
            app.windows.webViews[secondPageTitle].waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "Second visited site from previous session should not be in any webview."
        )
    }
}
