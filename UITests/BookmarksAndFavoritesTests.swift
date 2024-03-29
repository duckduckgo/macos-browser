//
//  BookmarksAndFavoritesTests.swift
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

class BookmarksAndFavoritesTests: XCTestCase {
    private var app: XCUIApplication!
    private var resetBookMarksMenuItem: XCUIElement!
    private var pageTitle: String!
    private var urlForBookmarksBar: URL!
    private let titleStringLength = 12
    private var defaultBookmarkDialogButton: XCUIElement!
    private var addressBarTextField: XCUIElement!
    private var bookmarkPageContextMenuItem: XCUIElement!
    private var bookmarksMenu: XCUIElement!
    private var addressBarBookmarkButton: XCUIElement!
    private var optionsButton: XCUIElement!
    private var bookmarkDialogBookmarkFolderDropdown: XCUIElement!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"
        resetBookMarksMenuItem = app.menuItems["MainMenu.resetBookmarks"]
        pageTitle = UITests.randomPageTitle(length: titleStringLength)
        urlForBookmarksBar = UITests.simpleServedPage(titled: pageTitle)
        defaultBookmarkDialogButton = app.buttons["BookmarkDialogButtonsView.defaultButton"]
        addressBarTextField = app.windows.textFields["AddressBarViewController.addressBarTextField"]
        bookmarkPageContextMenuItem = app.menuItems["ContextMenuManager.bookmarkPageMenuItem"]
        bookmarksMenu = app.menuBarItems["Bookmarks"]
        addressBarBookmarkButton = app.buttons["AddressBarButtonsViewController.bookmarkButton"]
        optionsButton = app.buttons["NavigationBarViewController.optionsButton"]
        bookmarkDialogBookmarkFolderDropdown = app.popUpButtons["bookmark.add.folder.dropdown"]
        app.launch()
    }

    func resetBookmarks() {
        app.typeKey("n", modifierFlags: [.command]) // Can't use debug menu without a window
        XCTAssertTrue(
            resetBookMarksMenuItem.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Reset bookmarks menu item didn't become available in a reasonable timeframe."
        )
        resetBookMarksMenuItem.click()
    }

    func test_bookmarks_canBeAddedTo_withContextClickBookmarkThisPage() {
        resetBookmarks()
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The address bar text field didn't become available in a reasonable timeframe."
        )
        addressBarTextField.typeText("\(urlForBookmarksBar.absoluteString)\r")
        XCTAssertTrue(
            app.windows.webViews[pageTitle].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )
        app.windows.webViews[pageTitle].rightClick()
        XCTAssertTrue( // Bookmark the loaded page via context menu
            bookmarkPageContextMenuItem.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "\"Add bookmark\" context menu item didn't appear in a reasonable timeframe."
        )

        bookmarkPageContextMenuItem.click()
        XCTAssertTrue( // Check Add Bookmark dialog for existence but don't click on it
            defaultBookmarkDialogButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Add bookmark\" dialog option button didn't appear with the expected title in a reasonable timeframe."
        )
        XCTAssertTrue(
            addressBarBookmarkButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The address bar bookmark button didn't appear with the expected title in a reasonable timeframe."
        )
        XCTAssertTrue(
            bookmarkDialogBookmarkFolderDropdown.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Add bookmark\" dialog's bookmark folder dropdown didn't appear with the expected title in a reasonable timeframe."
        )
        let bookmarkDialogBookmarkFolderDropdownValue = try? XCTUnwrap( // Bookmark dialog must default to "Bookmarks" folder
            bookmarkDialogBookmarkFolderDropdown.value as? String,
            "It wasn't possible to get the value of the \"Add bookmark\" dialog's bookmark folder dropdown as String"
        )
        XCTAssertEqual(
            bookmarkDialogBookmarkFolderDropdownValue,
            "Bookmarks",
            "The accessibility value of the \"Add bookmark\" dialog's bookmark folder dropdown must be \"Bookmarks\"."
        )
        let addressBarBookmarkButtonValue = try? XCTUnwrap(
            addressBarBookmarkButton.value as? String,
            "It wasn't possible to get the value of the address bar bookmark button as String"
        )

        XCTAssertEqual( // The bookmark icon is already in a filled state and it isn't necessary to click the add button
            addressBarBookmarkButtonValue,
            "Bookmarked",
            "The accessibility value of the address bar bookmark button must be \"Bookmarked\", which indicates the icon in the filled state."
        )
        XCTAssertTrue(
            bookmarksMenu.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Bookmarks\" menu bar item didn't appear with the expected title in a reasonable timeframe."
        )
        bookmarksMenu.click()
        XCTAssertTrue( // And the bookmark is found in the Bookmarks menu
            app.menuItems[pageTitle].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The bookmark in the \"Bookmarks\" menu with the title of the test page didn't appear with the expected title in a reasonable timeframe."
        )
    }

    func test_bookmarks_canBeAddedTo_withSettingsItemBookmarkThisPage() {
        let openBookmarksMenuItem = app.menuItems["MoreOptionsMenu.openBookmarks"]
        let bookmarkPageMenuItem = app.menuItems["MoreOptionsMenu.bookmarkPage"]
        resetBookmarks()
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The address bar text field didn't become available in a reasonable timeframe."
        )
        addressBarTextField.typeText("\(urlForBookmarksBar.absoluteString)\r")
        XCTAssertTrue(
            app.windows.webViews[pageTitle].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )

        XCTAssertTrue( // Bookmark the loaded page via settings menu
            optionsButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The options button didn't appear with the expected title in a reasonable timeframe."
        )
        optionsButton.click()
        XCTAssertTrue(
            openBookmarksMenuItem.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The settings \"Bookmarks\" menu item didn't appear with the expected title in a reasonable timeframe."
        )
        openBookmarksMenuItem.hover()
        XCTAssertTrue(
            bookmarkPageMenuItem.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The settings \"Bookmark page\" menu item didn't appear with the expected title in a reasonable timeframe."
        )
        bookmarkPageMenuItem.click()
        XCTAssertTrue( // Check Add Bookmark dialog for existence but don't click on it
            defaultBookmarkDialogButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Add bookmark\" dialog option button didn't appear with the expected title in a reasonable timeframe."
        )
        XCTAssertTrue(
            addressBarBookmarkButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The address bar bookmark button didn't appear with the expected title in a reasonable timeframe."
        )
        XCTAssertTrue(
            bookmarkDialogBookmarkFolderDropdown.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Add bookmark\" dialog's bookmark folder dropdown didn't appear with the expected title in a reasonable timeframe."
        )
        let bookmarkDialogBookmarkFolderDropdownValue = try? XCTUnwrap(
            bookmarkDialogBookmarkFolderDropdown.value as? String,
            "It wasn't possible to get the value of the \"Add bookmark\" dialog's bookmark folder dropdown as String"
        )
        XCTAssertEqual( // Bookmark dialog must default to "Bookmarks" folder
            bookmarkDialogBookmarkFolderDropdownValue,
            "Bookmarks",
            "The accessibility value of the \"Add bookmark\" dialog's bookmark folder dropdown must be \"Bookmarks\"."
        )
        let addressBarBookmarkButtonValue = try? XCTUnwrap(
            addressBarBookmarkButton.value as? String,
            "It wasn't possible to get the value of the address bar bookmark button as String"
        )

        XCTAssertEqual( // The bookmark icon is already in a filled state and it isn't necessary to click the add button
            addressBarBookmarkButtonValue,
            "Bookmarked",
            "The accessibility value of the address bar bookmark button must be \"Bookmarked\", which indicates the icon in the filled state."
        )
        XCTAssertTrue(
            bookmarksMenu.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Bookmarks\" menu bar item didn't appear with the expected title in a reasonable timeframe."
        )
        bookmarksMenu.click()
        XCTAssertTrue( // And the bookmark is found in the Bookmarks menu
            app.menuItems[pageTitle].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The bookmark in the \"Bookmarks\" menu with the title of the test page didn't appear with the expected title in a reasonable timeframe."
        )
    }

    func test_bookmarks_canBeAddedTo_byClickingBookmarksButtonInAddressBar() {
        resetBookmarks()
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The address bar text field didn't become available in a reasonable timeframe."
        )
        addressBarTextField.typeText("\(urlForBookmarksBar.absoluteString)\r")
        XCTAssertTrue(
            app.windows.webViews[pageTitle].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )

        // In order to directly click the bookmark button in the address bar, we need to hover over something in the bar area
        XCTAssertTrue( // We already have access to the optionsButton so it is OK to use for this hover
            optionsButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The options button didn't appear with the expected title in a reasonable timeframe."
        )
        optionsButton.hover()
        XCTAssertTrue( // Now the button will exist so we can check for it and use it
            addressBarBookmarkButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The address bar bookmark button didn't appear with the expected title in a reasonable timeframe."
        )
        addressBarBookmarkButton.click()
        XCTAssertTrue( // Check Add Bookmark dialog for existence but don't click on it
            defaultBookmarkDialogButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Add bookmark\" dialog option button didn't appear with the expected title in a reasonable timeframe."
        )
        XCTAssertTrue(
            bookmarkDialogBookmarkFolderDropdown.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Add bookmark\" dialog's bookmark folder dropdown didn't appear with the expected title in a reasonable timeframe."
        )
        let bookmarkDialogBookmarkFolderDropdownValue = try? XCTUnwrap(
            bookmarkDialogBookmarkFolderDropdown.value as? String,
            "It wasn't possible to get the value of the \"Add bookmark\" dialog's bookmark folder dropdown as String"
        )

        XCTAssertEqual( // Bookmark dialog must default to "Bookmarks" folder
            bookmarkDialogBookmarkFolderDropdownValue,
            "Bookmarks",
            "The accessibility value of the \"Add bookmark\" dialog's bookmark folder dropdown must be \"Bookmarks\"."
        )
        let addressBarBookmarkButtonValue = try? XCTUnwrap(
            addressBarBookmarkButton.value as? String,
            "It wasn't possible to get the value of the address bar bookmark button as String"
        )
        XCTAssertEqual( // The bookmark icon is already in a filled state and it isn't necessary to click the add button
            addressBarBookmarkButtonValue,
            "Bookmarked",
            "The accessibility value of the address bar bookmark button must be \"Bookmarked\", which indicates the icon in the filled state."
        )
        XCTAssertTrue(
            bookmarksMenu.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Bookmarks\" menu bar item didn't appear with the expected title in a reasonable timeframe."
        )
        bookmarksMenu.click()
        XCTAssertTrue( // And the bookmark is found in the Bookmarks menu
            app.menuItems[pageTitle].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The bookmark in the \"Bookmarks\" menu with the title of the test page didn't appear with the expected title in a reasonable timeframe."
        )
    }
}
