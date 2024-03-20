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
    var app: XCUIApplication!
    var historyMenuBarItem: XCUIElement!
    var clearAllHistory: XCUIElement!
    let lengthForRandomPageTitle = 8
    let timeout = 0.3

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        historyMenuBarItem = app.menuBarItems["History"]
        clearAllHistory = app.menuItems["HistoryMenu.clearAllHistory"]
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
        app.buttons["ClearAllHistoryAndDataAlert.clearButton"].click() // And manually remove the history
    }

    func test_visitedSiteIsAddedToRecentlyVisited() throws {
        let historyPageTitleExpectedToBeFirstInRecentlyVisited = randomPageTitle(length: lengthForRandomPageTitle)
        let url = locallyServedURL(pageTitle: historyPageTitleExpectedToBeFirstInRecentlyVisited)
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

    func test_visitedSiteIsInHistoryAfterClosingAndReopeningWindow() throws {
        let historyPageTitleExpectedToBeFirstInTodayHistory = randomPageTitle(length: lengthForRandomPageTitle)
        let url = locallyServedURL(pageTitle: historyPageTitleExpectedToBeFirstInTodayHistory)
        let addressBarTextField = app.windows.textFields["AddressBarViewController.addressBarTextField"]
        let firstSiteInHistory = app.menuItems["HistoryMenu.historyMenuItem.Today.0"]
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: timeout),
            "The address bar text field didn't become available in a reasonable timeframe."
        )

        addressBarTextField.typeText("\(url.absoluteString)\r")
        XCTAssertTrue(
            app.windows.webViews["\(historyPageTitleExpectedToBeFirstInTodayHistory)"].waitForExistence(timeout: timeout),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Close all windows
        app.typeKey("n", modifierFlags: .command) // New window
        XCTAssertTrue(
            historyMenuBarItem.waitForExistence(timeout: timeout),
            "History menu bar item didn't appear in a reasonable timeframe."
        )
        historyMenuBarItem.click() // The visited sites identifiers will not be available until after the History menu has been accessed.
        XCTAssertTrue(
            firstSiteInHistory.waitForExistence(timeout: timeout),
            "The first site in the recently visited section didn't appear in a reasonable timeframe."
        )

        XCTAssertEqual(historyPageTitleExpectedToBeFirstInTodayHistory, firstSiteInHistory.title)
    }

    func test_lastClosedWindowsTabsCanBeReopenedViaHistory() throws {
        let titleOfFirstTabWhichShouldRestore = randomPageTitle(length: lengthForRandomPageTitle)
        let titleOfSecondTabWhichShouldRestore = randomPageTitle(length: lengthForRandomPageTitle)
        let urlForFirstTab = locallyServedURL(pageTitle: titleOfFirstTabWhichShouldRestore)
        let urlForSecondTab = locallyServedURL(pageTitle: titleOfSecondTabWhichShouldRestore)
        let addressBarTextField = app.windows.textFields["AddressBarViewController.addressBarTextField"]
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: timeout),
            "The address bar text field didn't become available in a reasonable timeframe."
        )
        addressBarTextField.typeText("\(urlForFirstTab.absoluteString)\r")
        XCTAssertTrue(
            app.windows.webViews["\(titleOfFirstTabWhichShouldRestore)"].waitForExistence(timeout: timeout),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )
        app.typeKey("t", modifierFlags: .command)

        addressBarTextField.typeText("\(urlForSecondTab.absoluteString)\r")
        XCTAssertTrue(
            app.windows.webViews["\(titleOfSecondTabWhichShouldRestore)"].waitForExistence(timeout: timeout),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )
        let reopenLastClosedWindowMenuItem = app.menuItems["HistoryMenu.reopenLastClosedWindow"]
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Close all windows
        app.typeKey("n", modifierFlags: .command) // New window
        XCTAssertTrue(
            historyMenuBarItem.waitForExistence(timeout: timeout),
            "History menu bar item didn't appear in a reasonable timeframe."
        )
        historyMenuBarItem.click() // The visited sites identifiers will not be available until after the History menu has been accessed.
        XCTAssertTrue(
            reopenLastClosedWindowMenuItem.waitForExistence(timeout: timeout),
            "The \"Reopen Last Closed Window\" menu item didn't appear in a reasonable timeframe."
        )
        reopenLastClosedWindowMenuItem.click()

        XCTAssertTrue(
            app.windows.webViews["\(titleOfFirstTabWhichShouldRestore)"].waitForExistence(timeout: timeout),
            "Restored visited tab 1 wasn't available with the expected title in a reasonable timeframe."
        )
        app.typeKey("w", modifierFlags: [.command])
        XCTAssertTrue(
            app.windows.webViews["\(titleOfSecondTabWhichShouldRestore)"].waitForExistence(timeout: timeout),
            "Restored visited tab 2 wasn't available with the expected title in a reasonable timeframe."
        )
    }
}

private extension BrowsingHistoryTests {

    func randomPageTitle(length: Int) -> String {
        return String(UUID().uuidString.prefix(length))
    }

    func locallyServedURL(pageTitle: String) -> URL {
        return URL.testsServer
            .appendingTestParameters(data: """
            <html>
            <head>
            <title>\(pageTitle)</title>
            </head>
            <body>
            <p>Sample text</p>
            </body>
            </html>
            """.utf8data)
    }
}
