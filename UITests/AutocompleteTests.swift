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

import XCTest

class AutocompleteTests: UITestCase {
    private var app: XCUIApplication!
    private var addBookmarkButton: XCUIElement!
    private var resetBookMarksMenuItem: XCUIElement!
    private var historyMenuBarItem: XCUIElement!
    private var clearAllHistoryMenuItem: XCUIElement!
    private var addressBarTextField: XCUIElement!
    private var suggestionsTableView: XCUIElement!
    private var clearAllHistoryAlertClearButton: XCUIElement!
    private var fakeFireButton: XCUIElement!
    private var siteTitleForBookmarkedSite: String!
    private var siteTitleForHistorySite: String!

    override class func setUp() {
        super.setUp()
        UITests.firstRun()
        UITests.setAutocompleteToggleBeforeTestcaseRuns(true) // These tests require autocomplete to be on
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"
        addBookmarkButton = app.buttons["BookmarkDialogButtonsView.defaultButton"]
        resetBookMarksMenuItem = app.menuItems["MainMenu.resetBookmarks"]
        historyMenuBarItem = app.menuBarItems["History"]
        clearAllHistoryMenuItem = app.menuItems["HistoryMenu.clearAllHistory"]
        addressBarTextField = app.windows.textFields["AddressBarViewController.addressBarTextField"]
        suggestionsTableView = app.tables["SuggestionViewController.tableView"]
        clearAllHistoryAlertClearButton = app.buttons["ClearAllHistoryAndDataAlert.clearButton"]
        fakeFireButton = app.buttons["FireViewController.fakeFireButton"]
        let siteTitleLength = 12
        siteTitleForBookmarkedSite = UITests.randomPageTitle(length: siteTitleLength)
        siteTitleForHistorySite = UITests.randomPageTitle(length: siteTitleLength)
        app.launch()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Enforce a single window
        app.typeKey("n", modifierFlags: .command)
        try resetAndArrangeBookmarksAndHistory() // Manually reset to a clean state
    }

    func test_suggestions_showsTypedTitleOfBookmarkedPageAsBookmark() throws {
        app.typeText(siteTitleForBookmarkedSite)
        XCTAssertTrue(
            suggestionsTableView.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Suggestions tableView didn't become available in a reasonable timeframe."
        )

        let suggestionCellWithBookmarkedSite = suggestionsTableView.tableRows.cells.staticTexts[siteTitleForBookmarkedSite].firstMatch
        XCTAssertTrue( // It should match something in suggestions
            suggestionCellWithBookmarkedSite.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The expected table view cell with the suggestion for the bookmarked site didn't become available in a reasonable timeframe."
        )
        let containerCellForBookmarkedSuggestion = app.tables.cells.containing(.any, identifier: suggestionCellWithBookmarkedSite.identifier)
            .firstMatch

        XCTAssertTrue(
            containerCellForBookmarkedSuggestion.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The enclosing cell for the suggestion cell for the bookmarked site didn't become available in a reasonable timeframe. If this is unexpected, it could be due to a significant change in the layout of this interface."
        )
        // And that should be a bookmark suggestion
        XCTAssertEqual(
            containerCellForBookmarkedSuggestion.images.firstMatch.label,
            "BookmarkSuggestion",
            "Although the suggestion was found, it didn't have the \"BookmarkSuggestion\" image next to it in suggestions."
        )
    }

    func test_suggestions_showsTypedTitleOfHistoryPageAsHistory() throws {
        app.typeText(siteTitleForHistorySite)
        XCTAssertTrue(
            suggestionsTableView.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Suggestions tableView didn't become available in a reasonable timeframe."
        )

        let suggestionCellWithHistorySite = suggestionsTableView.tableRows.cells.staticTexts[siteTitleForHistorySite].firstMatch
        XCTAssertTrue( // It should match something in suggestions
            suggestionCellWithHistorySite.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The expected table view cell with the suggestion for the history site didn't become available in a reasonable timeframe."
        )
        let containerCellForHistorySuggestion = app.tables.cells.containing(.any, identifier: suggestionCellWithHistorySite.identifier)
            .firstMatch

        XCTAssertTrue(
            containerCellForHistorySuggestion.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The enclosing cell for the suggestion cell for the history site didn't become available in a reasonable timeframe. If this is unexpected, it could be due to a significant change in the layout of this interface."
        )
        // And that should be a history suggestion
        XCTAssertEqual(
            containerCellForHistorySuggestion.images.firstMatch.label,
            "HistorySuggestion",
            "Although the suggestion was found, it didn't have the \"HistorySuggestion\" image next to it in suggestions."
        )
    }

    func test_suggestions_showsTypedTitleOfWebsiteNotInBookmarksOrHistoryAsWebsite() throws {
        let websiteString = "https://www.duckduckgo.com"
        let websiteURL = try XCTUnwrap(URL(string: websiteString), "Couldn't create URL from string \(websiteString)")
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The address bar text field didn't become available in a reasonable timeframe."
        )

        addressBarTextField.typeURL(websiteURL, pressingEnter: false)
        XCTAssertTrue(
            suggestionsTableView.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Suggestions tableView didn't become available in a reasonable timeframe."
        )

        let suggestionCellWithWebsite = suggestionsTableView.tableRows.cells.staticTexts[websiteURL.absoluteString].firstMatch
        XCTAssertTrue( // It should match something in suggestions
            suggestionCellWithWebsite.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The expected table view cell with the suggestion for the website didn't become available in a reasonable timeframe."
        )
        let containerCellForWebsiteSuggestion = app.tables.cells.containing(.any, identifier: suggestionCellWithWebsite.identifier)
            .firstMatch
        XCTAssertTrue(
            containerCellForWebsiteSuggestion.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The enclosing cell for the suggestion cell for the website didn't become available in a reasonable timeframe. If this is unexpected, it could be due to a significant change in the layout of this interface."
        )

        // And that should be a search suggestion (not website)
        XCTAssertEqual(
            containerCellForWebsiteSuggestion.images.firstMatch.label,
            "Search",
            "Although the suggestion was found, it didn't have the \"Search\" image next to it in suggestions."
        )
    }
}

private extension AutocompleteTests {
    /// Make sure there is exactly one site in the history, and exactly one site in the bookmarks, and they aren't the same site.
    func resetAndArrangeBookmarksAndHistory() throws {
        XCTAssertTrue(
            resetBookMarksMenuItem.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Reset bookmarks menu item didn't become available in a reasonable timeframe."
        )

        resetBookMarksMenuItem.click()
        let urlForBookmarks = UITests.simpleServedPage(titled: siteTitleForBookmarkedSite)
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The address bar text field didn't become available in a reasonable timeframe."
        )

        addressBarTextField.typeURL(urlForBookmarks)
        XCTAssertTrue(
            app.windows.webViews[siteTitleForBookmarkedSite].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )

        app.typeKey("d", modifierFlags: [.command]) // Bookmark the page
        XCTAssertTrue(
            addBookmarkButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Bookmark button didn't appear with the expected title in a reasonable timeframe."
        )
        addBookmarkButton.click()

        XCTAssertTrue(
            historyMenuBarItem.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "History menu bar item didn't appear in a reasonable timeframe."
        )
        historyMenuBarItem.click()

        XCTAssertTrue(
            clearAllHistoryMenuItem.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Clear all history item didn't appear in a reasonable timeframe."
        )
        clearAllHistoryMenuItem.click()

        XCTAssertTrue(
            clearAllHistoryAlertClearButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Clear all history item didn't appear in a reasonable timeframe."
        )
        clearAllHistoryAlertClearButton.click() // Manually remove the history
        XCTAssertTrue( // Let any ongoing fire animation or data processes complete
            fakeFireButton.waitForNonExistence(timeout: UITests.Timeouts.fireAnimation),
            "Fire animation didn't finish and cease existing in a reasonable timeframe."
        )

        let urlForHistory = UITests.simpleServedPage(titled: siteTitleForHistorySite)

        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The address bar text field didn't become available in a reasonable timeframe."
        )

        addressBarTextField.typeURL(urlForHistory)
        XCTAssertTrue(
            app.windows.webViews[siteTitleForHistorySite].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )
        app.typeKey("w", modifierFlags: [.command, .option, .shift])
        app.typeKey("n", modifierFlags: .command)
    }
}
