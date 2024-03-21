//
//  AutocompleteTests.swift
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

class AutocompleteTests: XCTestCase {
    var app: XCUIApplication!
    var addBookmarkButton: XCUIElement!
    var resetBookMarksDataMenuItem: XCUIElement!
    var historyMenuBarItem: XCUIElement!
    var clearAllHistory: XCUIElement!
    var addressBarTextField: XCUIElement!
    var tableView: XCUIElement!
    let timeout = 0.3
    let siteTitleForBookmarkedSite = String(UUID().uuidString.prefix(16))
    let siteTitleForHistorySite = String(UUID().uuidString.prefix(16))

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        addBookmarkButton = app.buttons["BookmarkDialogButtonsView.defaultButton"]
        resetBookMarksDataMenuItem = app.menuItems["MainMenu.resetBookmarks"]
        historyMenuBarItem = app.menuBarItems["History"]
        clearAllHistory = app.menuItems["HistoryMenu.clearAllHistory"]
        addressBarTextField = app.windows.textFields["AddressBarViewController.addressBarTextField"]
        tableView = app.tables["SuggestionViewController.tableView"]
        app.launch()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Enforce a single window
        app.typeKey("n", modifierFlags: .command)
        resetAndArrangeBookmarksAndHistory() // Manually reset to a clean state
    }

    func test_typingTitleOfBookmarkedPageShowsItInSuggestionsAsBookmark() throws {
        app.typeText(siteTitleForBookmarkedSite)
        XCTAssertTrue(
            tableView.waitForExistence(timeout: timeout),
            "Suggestions tableView didn't become available in a reasonable timeframe."
        )
        
        let suggestionCellWithBookmarkedSite = tableView.tableRows.cells.staticTexts["\(siteTitleForBookmarkedSite)"].firstMatch
        XCTAssertTrue( // It should match something in suggestions
            suggestionCellWithBookmarkedSite.waitForExistence(timeout: timeout),
            "The expected table view cell with the suggestion for the bookmarked site didn't become available in a reasonable timeframe."
        )
        let containerCellForBookmarkedSuggestion = app.tables.cells.containing(.any, identifier: suggestionCellWithBookmarkedSite.identifier)
            .firstMatch

        XCTAssertTrue(
            containerCellForBookmarkedSuggestion.waitForExistence(timeout: timeout),
            "The enclosing cell for the suggestion cell for the bookmarked site didn't become available in a reasonable timeframe."
        )
        // And that should be a bookmark suggestion
        XCTAssertEqual(containerCellForBookmarkedSuggestion.images.firstMatch.label, "BookmarkSuggestion")
    }

    func test_typingTitleOfHistoryPageShowsItInSuggestionsAsHistory() throws {
        app.typeText(siteTitleForHistorySite)
        XCTAssertTrue(
            tableView.waitForExistence(timeout: timeout),
            "Suggestions tableView didn't become available in a reasonable timeframe."
        )

        let suggestionCellWithHistorySite = tableView.tableRows.cells.staticTexts["\(siteTitleForHistorySite)"].firstMatch
        XCTAssertTrue( // It should match something in suggestions
            suggestionCellWithHistorySite.waitForExistence(timeout: timeout),
            "The expected table view cell with the suggestion for the history site didn't become available in a reasonable timeframe."
        )
        let containerCellForHistorySuggestion = app.tables.cells.containing(.any, identifier: suggestionCellWithHistorySite.identifier)
            .firstMatch

        XCTAssertTrue(
            containerCellForHistorySuggestion.waitForExistence(timeout: timeout),
            "The enclosing cell for the suggestion cell for the history site didn't become available in a reasonable timeframe."
        )
        // And that should be a history suggestion
        XCTAssertEqual(containerCellForHistorySuggestion.images.firstMatch.label, "HistorySuggestion")
    }

    func test_typingURLOfWebsiteNotInBookmarksOrHistoryShowsItInSuggestionsAsWebsite() throws {
        let websiteURLString = "https://www.duckduckgo.com"
        app.typeText(websiteURLString)
        XCTAssertTrue(
            tableView.waitForExistence(timeout: timeout),
            "Suggestions tableView didn't become available in a reasonable timeframe."
        )

        let suggestionCellWithWebsite = tableView.tableRows.cells.staticTexts["\(websiteURLString)"].firstMatch
        XCTAssertTrue( // It should match something in suggestions
            suggestionCellWithWebsite.waitForExistence(timeout: timeout),
            "The expected table view cell with the suggestion for the website didn't become available in a reasonable timeframe."
        )
        let containerCellForWebsiteSuggestion = app.tables.cells.containing(.any, identifier: suggestionCellWithWebsite.identifier)
            .firstMatch

        XCTAssertTrue(
            containerCellForWebsiteSuggestion.waitForExistence(timeout: timeout),
            "The enclosing cell for the suggestion cell for the website didn't become available in a reasonable timeframe."
        )

        // And that should be a website suggestion
        XCTAssertEqual(containerCellForWebsiteSuggestion.images.firstMatch.label, "Web")
    }
}

private extension AutocompleteTests {
    /// Make sure there is exactly one site in the history, and exactly one site in the bookmarks, and they aren't the same site.
    func resetAndArrangeBookmarksAndHistory() {
        XCTAssertTrue(
            resetBookMarksDataMenuItem.waitForExistence(timeout: timeout),
            "Reset bookmarks menu item didn't become available in a reasonable timeframe."
        )

        resetBookMarksDataMenuItem.click()

        let urlForBookmarks = locallyServedURL(pageTitle: siteTitleForBookmarkedSite)

        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: timeout),
            "The address bar text field didn't become available in a reasonable timeframe."
        )

        addressBarTextField.typeText("\(urlForBookmarks.absoluteString)\r")
        XCTAssertTrue(
            app.windows.webViews["\(siteTitleForBookmarkedSite)"].waitForExistence(timeout: timeout),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )

        app.typeKey("d", modifierFlags: [.command]) // Bookmark the page
        XCTAssertTrue(
            addBookmarkButton.waitForExistence(timeout: timeout),
            "Bookmark button didn't appear with the expected title in a reasonable timeframe."
        )
        addBookmarkButton.click()

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

        let urlForHistory = locallyServedURL(pageTitle: siteTitleForHistorySite)

        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: timeout),
            "The address bar text field didn't become available in a reasonable timeframe."
        )

        addressBarTextField.typeText("\(urlForHistory.absoluteString)\r")
        XCTAssertTrue(
            app.windows.webViews["\(siteTitleForHistorySite)"].waitForExistence(timeout: timeout),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )
        app.typeKey("w", modifierFlags: [.command, .option, .shift])
        app.typeKey("n", modifierFlags: .command)
    }

    func locallyServedURL(pageTitle: String) -> URL {
        return URL.testsServer
            .appendingTestParameters(data: """
            <html>
            <head>
            <title>\(pageTitle)</title>
            </head>
            <body>
            Text
            </body>
            </html>
            """.utf8data)
    }
}
