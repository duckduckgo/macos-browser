//
//  BookmarkSearchTests.swift
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

class BookmarkSearchTests: XCTestCase {
    private var app: XCUIApplication!

    private enum AccessibilityIdentifiers {
        static let bookmarkButton = "AddressBarButtonsViewController.bookmarkButton"
        static let addressBarTextField = "AddressBarViewController.addressBarTextField"
        static let bookmarksMenu = "MainMenu.bookmarks"
        static let optionsButton = "NavigationBarViewController.optionsButton"
        static let resetBookmarksMenuItem = "MainMenu.resetBookmarks"
        static let searchBookmarksButton = "BookmarkListViewController.searchBookmarksButton"
        static let bookmarksPanelSearchBar = "BookmarkListViewController.searchBar"
        static let bookmarksManagerSearchBar = "BookmarkManagementDetailViewController.searchBar"
        static let emptyStateTitle = "BookmarksEmptyStateContent.emptyStateTitle"
        static let emptyStateMessage = "BookmarksEmptyStateContent.emptyStateMessage"
        static let emptyStateImageView = "BookmarksEmptyStateContent.emptyStateImageView"
        static let newFolderButton = "BookmarkListViewController.newFolderButton"
    }

    override class func setUp() {
        UITests.firstRun()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"
        app.launch()
        BookmarkUtilities.resetBookmarks(app: app, resetMenuItem: app.menuItems[AccessibilityIdentifiers.resetBookmarksMenuItem])
        app.enforceSingleWindow()
    }

    // MARK: - Tests

    func testEmptyStateWhenSearchingInPanel() {
        addBookmarkAndOpenBookmarksPanel(bookmarkPageTitle: "Bookmark #1")
        verifyEmptyState(in: app.popovers.firstMatch, with: AccessibilityIdentifiers.bookmarksPanelSearchBar, mode: .panel)
    }

    func testEmptyStateWhenSearchingInManager() {
        addBookmarkAndOpenBookmarksManager(bookmarkPageTitle: "Bookmark #1")
        verifyEmptyState(in: app, with: AccessibilityIdentifiers.bookmarksManagerSearchBar, mode: .manager)
    }

    func testFilteredResultsInPanel() {
        addThreeBookmarks()
        closeShowBookmarksBarAlert()
        app.openBookmarksPanel()
        searchInBookmarksPanel(for: "Bookmark #2")
        assertOnlyBookmarkExists(on: app.outlines.firstMatch, bookmarkTitle: "Bookmark #2")
    }

    func testFilteredResultsInManager() {
        addThreeBookmarks()
        app.openBookmarksManager()
        searchInBookmarksManager(for: "Bookmark #2")
        assertOnlyBookmarkExists(on: app.tables.firstMatch, bookmarkTitle: "Bookmark #2")
    }

    func testShowInFolderFunctionalityOnBookmarksPanel() {
        testShowInFolderFunctionality(in: .panel)
    }

    func testShoInFolderFunctionalityOnBookmarksManager() {
        testShowInFolderFunctionality(in: .manager)
    }

    func testDragAndDropToReorderIsNotPossibleWhenInSearchOnBookmarksPanel() {
        testDragAndDropToReorder(in: .panel)
    }

    func testDragAndDropToReorderIsNotPossibleWhenInSearchOnBookmarksManager() {
        testDragAndDropToReorder(in: .manager)
    }

    func testSearchActionIsHiddenOnBookmarksPanelWhenUserHasNoBookmarks() {
        app.openBookmarksPanel()
        let bookmarksPanelPopover = app.popovers.firstMatch
        XCTAssertFalse(bookmarksPanelPopover.buttons[AccessibilityIdentifiers.searchBookmarksButton].exists)
    }

    // MARK: - Utilities

    private func addBookmarkAndOpenBookmarksPanel(bookmarkPageTitle: String, in folder: String? = nil) {
        addBookmark(pageTitle: bookmarkPageTitle, in: folder)
        closeShowBookmarksBarAlert()
        app.openBookmarksPanel()
    }

    private func addBookmarkAndOpenBookmarksManager(bookmarkPageTitle: String, in folder: String? = nil) {
        addBookmark(pageTitle: bookmarkPageTitle, in: folder)
        app.openBookmarksManager()
    }

    private func addThreeBookmarks() {
        ["Bookmark #1", "Bookmark #2", "Bookmark #3"].forEach {
            addBookmark(pageTitle: $0)
            app.openNewTab()
        }
    }

    private func addBookmark(pageTitle: String, in folder: String? = nil) {
        let urlForBookmarksBar = UITests.simpleServedPage(titled: pageTitle)
        BookmarkUtilities.openSiteToBookmark(app: app,
                                             url: urlForBookmarksBar,
                                             pageTitle: pageTitle,
                                             bookmarkingViaDialog: true,
                                             escapingDialog: true,
                                             addressBarTextField: app.windows.textFields[AccessibilityIdentifiers.addressBarTextField],
                                             folderName: folder)
    }

    private func searchInBookmarksPanel(for title: String) {
        bringFocusToBookmarksPanelSearchBar()
        app.popovers.firstMatch.searchFields[AccessibilityIdentifiers.bookmarksPanelSearchBar].typeText(title)
    }

    private func searchInBookmarksManager(for title: String) {
        let searchField = app.searchFields[AccessibilityIdentifiers.bookmarksManagerSearchBar]
        searchField.tap()
        searchField.typeText(title)
    }

    private func assertOnlyBookmarkExists(on element: XCUIElement, bookmarkTitle: String) {
        XCTAssertTrue(element.staticTexts[bookmarkTitle].exists)
        // Assert that other bookmarks do not exist
        ["Bookmark #1", "Bookmark #2", "Bookmark #3"].filter { $0 != bookmarkTitle }.forEach {
            XCTAssertFalse(element.staticTexts[$0].exists)
        }
    }

    private func verifyEmptyState(in element: XCUIElement, with accessibilityIdentifier: String, mode: BookmarkMode) {
        if mode == .panel {
            searchInBookmarksPanel(for: "No results")
        } else {
            searchInBookmarksManager(for: "No results")
        }
        assertEmptyState(in: element)
    }

    private func assertEmptyState(in element: XCUIElement) {
        let emptyStateTitle = element.staticTexts[AccessibilityIdentifiers.emptyStateTitle]
        let emptyStateDescription = element.staticTexts[AccessibilityIdentifiers.emptyStateMessage]
        let emptyStateImage = element.images[AccessibilityIdentifiers.emptyStateImageView]

        XCTAssertTrue(emptyStateImage.exists, "The empty state image does not exist.")
        XCTAssertTrue(emptyStateTitle.exists, "The empty state title does not exist.")
        XCTAssertTrue(emptyStateDescription.exists, "The empty state description does not exist.")

        XCTAssertEqual(emptyStateTitle.value as? String, "No bookmarks found")
        XCTAssertEqual(emptyStateDescription.value as? String, "Try different search terms.")
    }

    private func bringFocusToBookmarksPanelSearchBar() {
        let popover = app.popovers.firstMatch
        popover.buttons[AccessibilityIdentifiers.searchBookmarksButton].tap()
    }

    private func testShowInFolderFunctionality(in mode: BookmarkMode) {
        createFolderWithSubFolder()
        app.openNewTab()
        addBookmark(pageTitle: "Bookmark #1", in: "Folder #2")
        closeShowBookmarksBarAlert()

        if mode == .panel {
            app.openBookmarksPanel()
            searchInBookmarksPanel(for: "Bookmark #1")
        } else {
            app.openBookmarksManager()
            searchInBookmarksManager(for: "Bookmark #1")
        }

        let result = app.staticTexts["Bookmark #1"]
        result.rightClick()
        let showInFolderMenuItem = app.menuItems["Show in Folder"]
        XCTAssertTrue(showInFolderMenuItem.exists)
        showInFolderMenuItem.tap()

        assertSearchBarVisibilityAfterShowInFolder(mode: mode)
        assertFolderStructure(mode: mode)
    }

    private func assertSearchBarVisibilityAfterShowInFolder(mode: BookmarkMode) {
        if mode == .panel {
            XCTAssertFalse(app.popovers.firstMatch.searchFields[AccessibilityIdentifiers.bookmarksPanelSearchBar].exists)
        } else {
            XCTAssertEqual(app.searchFields[AccessibilityIdentifiers.bookmarksManagerSearchBar].value as? String, "")
        }
    }

    private func assertFolderStructure(mode: BookmarkMode) {
        let treeBookmarks: XCUIElement = mode == .panel ? app.popovers.firstMatch.outlines.firstMatch : app.outlines.firstMatch

        XCTAssertTrue(treeBookmarks.staticTexts["Folder #1"].exists)
        if mode == .panel {
            XCTAssertTrue(treeBookmarks.staticTexts["Bookmark #1"].exists)
            XCTAssertTrue(treeBookmarks.staticTexts["Folder #2"].exists)
        } else {
            /// On the bookmarks manager the sidebar tree structure only has folders while the list has what's inside the selected folder in the tree.
            XCTAssertTrue(treeBookmarks.staticTexts["Folder #2"].exists)
            let bookmarksList = app.tables.firstMatch
            XCTAssertTrue(bookmarksList.staticTexts["Bookmark #1"].exists)
        }
    }

    private func testDragAndDropToReorder(in mode: BookmarkMode) {
        addThreeBookmarks()
        if mode == .panel {
            closeShowBookmarksBarAlert()
            app.openBookmarksPanel()
        } else {
            app.openBookmarksManager()
        }
        searchInBookmarks(mode: mode)

        let thirdBookmarkCell = getThirdBookmarkCell(mode: mode)
        dragAndDropBookmark(thirdBookmarkCell, mode: mode)

        if mode == .panel {
            bringFocusToBookmarksPanelSearchBar()
        } else {
            clearSearchInBookmarksManager()
        }

        BookmarkUtilities.verifyBookmarkOrder(app: app, expectedOrder: ["Bookmark #1", "Bookmark #2", "Bookmark #3"], mode: mode)
    }

    private func searchInBookmarks(mode: BookmarkMode) {
        if mode == .panel {
            searchInBookmarksPanel(for: "Bookmark")
        } else {
            searchInBookmarksManager(for: "Bookmark")
        }
    }

    private func getThirdBookmarkCell(mode: BookmarkMode) -> XCUIElement {
        if mode == .panel {
            let treeBookmarks = app.popovers.firstMatch.outlines.firstMatch
            return treeBookmarks.staticTexts["Bookmark #3"]
        } else {
            let bookmarksSearchResultsList = app.tables.firstMatch
            return bookmarksSearchResultsList.staticTexts["Bookmark #3"]
        }
    }

    private func dragAndDropBookmark(_ thirdBookmarkCell: XCUIElement, mode: BookmarkMode) {
        let startCoordinate = thirdBookmarkCell.coordinate(withNormalizedOffset: .zero)
        let targetCoordinate = (mode == .panel ? app.popovers.firstMatch.outlines.firstMatch : app.tables.firstMatch).coordinate(withNormalizedOffset: .zero)
        startCoordinate.press(forDuration: 0.1, thenDragTo: targetCoordinate)
    }

    private func clearSearchInBookmarksManager() {
        let searchField = app.searchFields[AccessibilityIdentifiers.bookmarksManagerSearchBar]
        searchField.doubleTap()
        app.typeKey(.delete, modifierFlags: [])
    }

    private func createFolderWithSubFolder() {
        app.openBookmarksPanel()
        let bookmarksPanel = app.popovers.firstMatch
        bookmarksPanel.buttons[AccessibilityIdentifiers.newFolderButton].tap()

        let folderTitleTextField = app.textFields["bookmark.add.name.textfield"]
        folderTitleTextField.typeText("Folder #1")
        app.buttons["Add Folder"].tap()

        bookmarksPanel.buttons[AccessibilityIdentifiers.newFolderButton].tap()
        folderTitleTextField.typeText("Folder #2")
        let folderLocationButton = app.popUpButtons["bookmark.folder.folder.dropdown"]
        folderLocationButton.tap()
        folderLocationButton.menuItems["Folder #1"].tap()
        app.buttons["Add Folder"].tap()
    }

    private func closeShowBookmarksBarAlert() {
        BookmarkUtilities.dismissPopover(app: app, buttonIdentifier: "Hide")
    }
}
