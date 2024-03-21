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
    private var app: XCUIApplication!
    private var addBookmarkButton: XCUIElement!
    private var resetBookMarksMenuItem: XCUIElement!
    private var historyMenuBarItem: XCUIElement!
    private var clearAllHistoryMenuItem: XCUIElement!
    private var addressBarTextField: XCUIElement!
    private var suggestionsTableView: XCUIElement!
    private let elementExistenceTimeout = 0.3
    private let siteTitleForBookmarkedSite = String(UUID().uuidString.prefix(16))
    private let siteTitleForHistorySite = String(UUID().uuidString.prefix(16))

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        addBookmarkButton = app.buttons["BookmarkDialogButtonsView.defaultButton"]
        resetBookMarksMenuItem = app.menuItems["MainMenu.resetBookmarks"]
        historyMenuBarItem = app.menuBarItems["History"]
        clearAllHistoryMenuItem = app.menuItems["HistoryMenu.clearAllHistory"]
        addressBarTextField = app.windows.textFields["AddressBarViewController.addressBarTextField"]
        suggestionsTableView = app.tables["SuggestionViewController.tableView"]
        app.launch()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Enforce a single window
        app.typeKey("n", modifierFlags: .command)
        resetAndArrangeBookmarksAndHistory() // Manually reset to a clean state
    }

    func test_typingTitleOfBookmarkedPageShowsItInSuggestionsAsBookmark() throws {
        app.typeText(siteTitleForBookmarkedSite)
        XCTAssertTrue(
            suggestionsTableView.waitForExistence(timeout: elementExistenceTimeout),
            "Suggestions tableView didn't become available in a reasonable timeframe."
        )

        let suggestionCellWithBookmarkedSite = suggestionsTableView.tableRows.cells.staticTexts["\(siteTitleForBookmarkedSite)"].firstMatch
        XCTAssertTrue( // It should match something in suggestions
            suggestionCellWithBookmarkedSite.waitForExistence(timeout: elementExistenceTimeout),
            "The expected table view cell with the suggestion for the bookmarked site didn't become available in a reasonable timeframe."
        )
        let containerCellForBookmarkedSuggestion = app.tables.cells.containing(.any, identifier: suggestionCellWithBookmarkedSite.identifier)
            .firstMatch

        XCTAssertTrue(
            containerCellForBookmarkedSuggestion.waitForExistence(timeout: elementExistenceTimeout),
            "The enclosing cell for the suggestion cell for the bookmarked site didn't become available in a reasonable timeframe. If this is unexpected, it could be due to a significant change in the layout of this interface."
        )
        // And that should be a bookmark suggestion
        XCTAssertEqual(
            containerCellForBookmarkedSuggestion.images.firstMatch.label,
            "BookmarkSuggestion",
            "Although the suggestion was found, it didn't have the \"BookmarkSuggestion\" image next to it in suggestions."
        )
    }

    func test_typingTitleOfHistoryPageShowsItInSuggestionsAsHistory() throws {
        app.typeText(siteTitleForHistorySite)
        XCTAssertTrue(
            suggestionsTableView.waitForExistence(timeout: elementExistenceTimeout),
            "Suggestions tableView didn't become available in a reasonable timeframe."
        )

        let suggestionCellWithHistorySite = suggestionsTableView.tableRows.cells.staticTexts["\(siteTitleForHistorySite)"].firstMatch
        XCTAssertTrue( // It should match something in suggestions
            suggestionCellWithHistorySite.waitForExistence(timeout: elementExistenceTimeout),
            "The expected table view cell with the suggestion for the history site didn't become available in a reasonable timeframe."
        )
        let containerCellForHistorySuggestion = app.tables.cells.containing(.any, identifier: suggestionCellWithHistorySite.identifier)
            .firstMatch

        XCTAssertTrue(
            containerCellForHistorySuggestion.waitForExistence(timeout: elementExistenceTimeout),
            "The enclosing cell for the suggestion cell for the history site didn't become available in a reasonable timeframe. If this is unexpected, it could be due to a significant change in the layout of this interface."
        )
        // And that should be a history suggestion
        XCTAssertEqual(
            containerCellForHistorySuggestion.images.firstMatch.label,
            "HistorySuggestion",
            "Although the suggestion was found, it didn't have the \"HistorySuggestion\" image next to it in suggestions."
        )
    }

    func test_typingURLOfWebsiteNotInBookmarksOrHistoryShowsItInSuggestionsAsWebsite() throws {
        let websiteURLString = "https://www.duckduckgo.com"
        app.typeText(websiteURLString)
        XCTAssertTrue(
            suggestionsTableView.waitForExistence(timeout: elementExistenceTimeout),
            "Suggestions tableView didn't become available in a reasonable timeframe."
        )

        let suggestionCellWithWebsite = suggestionsTableView.tableRows.cells.staticTexts["\(websiteURLString)"].firstMatch
        XCTAssertTrue( // It should match something in suggestions
            suggestionCellWithWebsite.waitForExistence(timeout: elementExistenceTimeout),
            "The expected table view cell with the suggestion for the website didn't become available in a reasonable timeframe."
        )
        let containerCellForWebsiteSuggestion = app.tables.cells.containing(.any, identifier: suggestionCellWithWebsite.identifier)
            .firstMatch

        XCTAssertTrue(
            containerCellForWebsiteSuggestion.waitForExistence(timeout: elementExistenceTimeout),
            "The enclosing cell for the suggestion cell for the website didn't become available in a reasonable timeframe. If this is unexpected, it could be due to a significant change in the layout of this interface."
        )

        // And that should be a website suggestion
        XCTAssertEqual(
            containerCellForWebsiteSuggestion.images.firstMatch.label,
            "Web",
            "Although the suggestion was found, it didn't have the \"Web\" image next to it in suggestions."
        )
    }
}

private extension AutocompleteTests {
    /// Make sure there is exactly one site in the history, and exactly one site in the bookmarks, and they aren't the same site.
    func resetAndArrangeBookmarksAndHistory() {
        XCTAssertTrue(
            resetBookMarksMenuItem.waitForExistence(timeout: elementExistenceTimeout),
            "Reset bookmarks menu item didn't become available in a reasonable timeframe."
        )

        resetBookMarksMenuItem.click()

        let urlForBookmarks = locallyServedURL(pageTitle: siteTitleForBookmarkedSite)

        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: elementExistenceTimeout),
            "The address bar text field didn't become available in a reasonable timeframe."
        )

        addressBarTextField.typeText("\(urlForBookmarks.absoluteString)\r")
        XCTAssertTrue(
            app.windows.webViews["\(siteTitleForBookmarkedSite)"].waitForExistence(timeout: elementExistenceTimeout),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )

        app.typeKey("d", modifierFlags: [.command]) // Bookmark the page
        XCTAssertTrue(
            addBookmarkButton.waitForExistence(timeout: elementExistenceTimeout),
            "Bookmark button didn't appear with the expected title in a reasonable timeframe."
        )
        addBookmarkButton.click()

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

        let urlForHistory = locallyServedURL(pageTitle: siteTitleForHistorySite)

        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: elementExistenceTimeout),
            "The address bar text field didn't become available in a reasonable timeframe."
        )

        addressBarTextField.typeText("\(urlForHistory.absoluteString)\r")
        XCTAssertTrue(
            app.windows.webViews["\(siteTitleForHistorySite)"].waitForExistence(timeout: elementExistenceTimeout),
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
