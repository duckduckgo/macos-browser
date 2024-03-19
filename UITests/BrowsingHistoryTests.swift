//
//  BrowsingHistoryTests.swift
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

import Common
import XCTest

class BrowsingHistoryTests: XCTestCase {
    let app = XCUIApplication()
    let timeout = 0.3
    let historyMenuBarItem = XCUIApplication().menuBarItems["History"]
    let clearAllHistory = XCUIApplication().menuItems["HistoryMenu.clearAllHistory"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Let's enforce a single window
        app.typeKey("n", modifierFlags: .command)

        XCTAssertTrue(
            historyMenuBarItem.waitForExistence(timeout: timeout),
            "History menu bar item didn't appear in a reasonable timeframe."
        )
        historyMenuBarItem.click()

        XCTAssertTrue(
            clearAllHistory.waitForExistence(timeout: timeout),
            "Clear all history item didn't appear in a reasonable timeframe."
        )
        clearAllHistory.click()

        XCTAssertTrue(
            app.buttons["ClearAllHistoryAndDataAlert.clearButton"].waitForExistence(timeout: timeout),
            "Clear all history item didn't appear in a reasonable timeframe."
        )
        app.buttons["ClearAllHistoryAndDataAlert.clearButton"].click() // And remove the history

        // DuckDuckGo/macos-browser/DuckDuckGo/Menus/MainMenuActions.swift:279: Fatal error: Could not get currently active Tab
    }

    func test_visitedSiteIsAddedToRecentlyVisited() throws {

        let historyPageTitleExpectedToBeFirstInRecentlyVisited = "First History Entry"
        let url = URL.testsServer
            .appendingTestParameters(data: """
            <html>
            <head>
            <title>\(historyPageTitleExpectedToBeFirstInRecentlyVisited)</title>
            </head>
            <body>
            <p>Text</p>
            </body>
            </html>
            """.utf8data)

        let addressBarTextField = app.windows.textFields["AddressBarViewController.addressBarTextField"]
        let firstSiteInRecentlyVisitedSection = app.menuItems["HistoryMenu.recentlyVisitedMenuItem.0"]

        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: timeout),
            "The address bar text field didn't become available in a reasonable timeframe."
        )

        addressBarTextField.typeText("\(url.absoluteString)\r")
        XCTAssertTrue(
            app.windows.webViews["\(historyPageTitleExpectedToBeFirstInRecentlyVisited)"].waitForExistence(timeout: timeout),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )
        XCTAssertTrue(
            historyMenuBarItem.waitForExistence(timeout: timeout),
            "History menu bar item didn't appear in a reasonable timeframe."
        )
        historyMenuBarItem.click() // The visited sites identifiers will not be available until after the History menu has been accessed.

        XCTAssertTrue(
            firstSiteInRecentlyVisitedSection.waitForExistence(timeout: timeout),
            "The first site in the recently visited section didn't appear in a reasonable timeframe."
        )

        XCTAssertEqual(historyPageTitleExpectedToBeFirstInRecentlyVisited, firstSiteInRecentlyVisitedSection.title)
    }
}
