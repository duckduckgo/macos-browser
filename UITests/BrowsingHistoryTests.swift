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
    private var app: XCUIApplication!
    private var historyMenuBarItem: XCUIElement!
    private var clearAllHistoryMenuItem: XCUIElement!
    private let lengthForRandomPageTitle = 8
    private let elementExistenceTimeout = 0.3

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        historyMenuBarItem = app.menuBarItems["History"]
        clearAllHistoryMenuItem = app.menuItems["HistoryMenu.clearAllHistory"]
        app.launch()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Let's enforce a single window
        app.typeKey("n", modifierFlags: .command)

        XCTAssertTrue(
            historyMenuBarItem.waitForExistence(timeout: elementExistenceTimeout),
            "History menu bar item didn't appear in a reasonable timeframe."
        )
        historyMenuBarItem.click()

        XCTAssertTrue(
            clearAllHistoryMenuItem.waitForExistence(timeout: elementExistenceTimeout),
            "Clear all history item didn't appear in a reasonable timeframe."
        )
        clearAllHistoryMenuItem.click()

        XCTAssertTrue(
            app.buttons["ClearAllHistoryAndDataAlert.clearButton"].waitForExistence(timeout: elementExistenceTimeout),
            "Clear all history item didn't appear in a reasonable timeframe."
        )
        app.buttons["ClearAllHistoryAndDataAlert.clearButton"].click() // And manually remove the history
    }

    func test_visitedSiteIsAddedToRecentlyVisited() throws {
        let historyPageTitleExpectedToBeFirstInRecentlyVisited = String(UUID().uuidString.prefix(lengthForRandomPageTitle))
        let url = URL.simpleServedPage(titled: historyPageTitleExpectedToBeFirstInRecentlyVisited)
        let addressBarTextField = app.windows.textFields["AddressBarViewController.addressBarTextField"]
        let firstSiteInRecentlyVisitedSection = app.menuItems["HistoryMenu.recentlyVisitedMenuItem.0"]
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: elementExistenceTimeout),
            "The address bar text field didn't become available in a reasonable timeframe."
        )

        addressBarTextField.typeText("\(url.absoluteString)\r")
        XCTAssertTrue(
            app.windows.webViews["\(historyPageTitleExpectedToBeFirstInRecentlyVisited)"].waitForExistence(timeout: elementExistenceTimeout),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )
        XCTAssertTrue(
            historyMenuBarItem.waitForExistence(timeout: elementExistenceTimeout),
            "History menu bar item didn't appear in a reasonable timeframe."
        )
        historyMenuBarItem.click() // The visited sites identifiers will not be available until after the History menu has been accessed.
        XCTAssertTrue(
            firstSiteInRecentlyVisitedSection.waitForExistence(timeout: elementExistenceTimeout),
            "The first site in the recently visited section didn't appear in a reasonable timeframe."
        )

        XCTAssertEqual(historyPageTitleExpectedToBeFirstInRecentlyVisited, firstSiteInRecentlyVisitedSection.title)
    }

    func test_visitedSiteIsInHistoryAfterClosingAndReopeningWindow() throws {
        let historyPageTitleExpectedToBeFirstInTodayHistory = String(UUID().uuidString.prefix(lengthForRandomPageTitle))
        let url = URL.simpleServedPage(titled: historyPageTitleExpectedToBeFirstInTodayHistory)
        let addressBarTextField = app.windows.textFields["AddressBarViewController.addressBarTextField"]
        let firstSiteInHistory = app.menuItems["HistoryMenu.historyMenuItem.Today.0"]
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: elementExistenceTimeout),
            "The address bar text field didn't become available in a reasonable timeframe."
        )

        addressBarTextField.typeText("\(url.absoluteString)\r")
        XCTAssertTrue(
            app.windows.webViews["\(historyPageTitleExpectedToBeFirstInTodayHistory)"].waitForExistence(timeout: elementExistenceTimeout),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Close all windows
        app.typeKey("n", modifierFlags: .command) // New window
        XCTAssertTrue(
            historyMenuBarItem.waitForExistence(timeout: elementExistenceTimeout),
            "History menu bar item didn't appear in a reasonable timeframe."
        )
        historyMenuBarItem.click() // The visited sites identifiers will not be available until after the History menu has been accessed.
        XCTAssertTrue(
            firstSiteInHistory.waitForExistence(timeout: elementExistenceTimeout),
            "The first site in the recently visited section didn't appear in a reasonable timeframe."
        )

        XCTAssertEqual(historyPageTitleExpectedToBeFirstInTodayHistory, firstSiteInHistory.title)
    }

    func test_lastClosedWindowsTabsCanBeReopenedViaHistory() throws {
        let titleOfFirstTabWhichShouldRestore = String(UUID().uuidString.prefix(lengthForRandomPageTitle))
        let titleOfSecondTabWhichShouldRestore = String(UUID().uuidString.prefix(lengthForRandomPageTitle))
        let urlForFirstTab = URL.simpleServedPage(titled: titleOfFirstTabWhichShouldRestore)
        let urlForSecondTab = URL.simpleServedPage(titled: titleOfSecondTabWhichShouldRestore)
        let addressBarTextField = app.windows.textFields["AddressBarViewController.addressBarTextField"]
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: elementExistenceTimeout),
            "The address bar text field didn't become available in a reasonable timeframe."
        )
        addressBarTextField.typeText("\(urlForFirstTab.absoluteString)\r")
        XCTAssertTrue(
            app.windows.webViews["\(titleOfFirstTabWhichShouldRestore)"].waitForExistence(timeout: elementExistenceTimeout),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )
        app.typeKey("t", modifierFlags: .command)

        addressBarTextField.typeText("\(urlForSecondTab.absoluteString)\r")
        XCTAssertTrue(
            app.windows.webViews["\(titleOfSecondTabWhichShouldRestore)"].waitForExistence(timeout: elementExistenceTimeout),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )
        let reopenLastClosedWindowMenuItem = app.menuItems["HistoryMenu.reopenLastClosedWindow"]
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Close all windows
        app.typeKey("n", modifierFlags: .command) // New window
        XCTAssertTrue(
            historyMenuBarItem.waitForExistence(timeout: elementExistenceTimeout),
            "History menu bar item didn't appear in a reasonable timeframe."
        )
        historyMenuBarItem.click() // The visited sites identifiers will not be available until after the History menu has been accessed.
        XCTAssertTrue(
            reopenLastClosedWindowMenuItem.waitForExistence(timeout: elementExistenceTimeout),
            "The \"Reopen Last Closed Window\" menu item didn't appear in a reasonable timeframe."
        )
        reopenLastClosedWindowMenuItem.click()

        XCTAssertTrue(
            app.windows.webViews["\(titleOfFirstTabWhichShouldRestore)"].waitForExistence(timeout: elementExistenceTimeout),
            "Restored visited tab 1 wasn't available with the expected title in a reasonable timeframe."
        )
        app.typeKey("w", modifierFlags: [.command])
        XCTAssertTrue(
            app.windows.webViews["\(titleOfSecondTabWhichShouldRestore)"].waitForExistence(timeout: elementExistenceTimeout),
            "Restored visited tab 2 wasn't available with the expected title in a reasonable timeframe."
        )
    }
}
