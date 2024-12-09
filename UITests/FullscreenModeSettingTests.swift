//
//  FullscreenModeSettingTests.swift
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

class FullscreenModeSettingTests: XCTestCase {
    private var app: XCUIApplication!
    private var settingsGeneralButton: XCUIElement!

    override class func setUp() {
        UITests.firstRun()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"

        app.launch()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Let's enforce a single window
        app.typeKey("n", modifierFlags: [.command])
    }

    func testBookmarksBarAndTabsAreVisibleWhenSettingIsDisabled() {
        openSettings()
        let settingsAppearanceButton = app.buttons["PreferencesSidebar.appearanceButton"]
        XCTAssertTrue(
            settingsAppearanceButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The user settings appearance section button didn't become available in a reasonable timeframe."
        )
        settingsAppearanceButton.click(forDuration: UITests.Timeouts.elementExistence, thenDragTo: settingsAppearanceButton)
        let hideToolbarsOnFullScreenButton = app.checkBoxes["Preferences.AppearanceView.hideToolbarsOnFullScreen"]
        XCTAssertTrue(
            hideToolbarsOnFullScreenButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The toggle for showing the hide toolbars setting didn't become available in a reasonable timeframe."
        )

        let hideToolbarsOnFullScreenIsChecked = hideToolbarsOnFullScreenButton.value as? Bool
        if hideToolbarsOnFullScreenIsChecked == true {
            hideToolbarsOnFullScreenButton.click()
        }

        app.openNewTab()
        openSite(pageTitle: "Page #1")
        enterFullScreenMode()
    }

    func testBookmarksBarAndTabsAreNotVisibleWhenSettingIsEnabled() {

    }

    // MARK: - Utilities

    private func enterFullScreenMode() {
        app.typeKey("f", modifierFlags: [.command, .control])
    }

    private func openSettings() {
        let addressBar = app.windows.textFields["AddressBarViewController.addressBarTextField"]
        addressBar.typeURL(URL(string: "duck://settings")!)
    }

    private func openSite(pageTitle: String) {
        let url = UITests.simpleServedPage(titled: pageTitle)
        let addressBarTextField = app.windows.firstMatch.textFields["AddressBarViewController.addressBarTextField"].firstMatch
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
}
