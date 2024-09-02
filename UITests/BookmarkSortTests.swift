//
//  BookmarkSortTests.swift
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

class BookmarkSortTests: XCTestCase {
    private var app: XCUIApplication!

    private enum AccessibilityIdentifiers {
        static let addressBarTextField = "AddressBarViewController.addressBarTextField"
        static let resetBookmarksMenuItem = "MainMenu.resetBookmarks"
        static let sortBookmarksButtonPanel = "BookmarkListViewController.sortBookmarksButton"
        static let sortBookmarksButtonManager = "BookmarkManagementDetailViewController.sortItemsButton"
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

    func testWhenChangingSortingInThePanelIsReflectedInTheManager() {
        app.openBookmarksPanel()
        selectSortByName(mode: .panel)
        app.openBookmarksManager()

        app.buttons[AccessibilityIdentifiers.sortBookmarksButtonManager].tap()

        /// If the ascending and descending sort options are enabled, means that the sort in the panel was reflected here.
        XCTAssertTrue(app.menuItems["Ascending"].isEnabled)
        XCTAssertTrue(app.menuItems["Descending"].isEnabled)
    }

    func testWhenChangingSortingInTheManagerIsReflectedInThePanel() {
        app.openBookmarksManager()
        selectSortByName(mode: .manager)
        app.openBookmarksPanel()

        let bookmarksPanelPopover = app.popovers.firstMatch
        bookmarksPanelPopover.buttons[AccessibilityIdentifiers.sortBookmarksButtonPanel].tap()

        XCTAssertTrue(bookmarksPanelPopover.menuItems["Ascending"].isEnabled)
        XCTAssertTrue(bookmarksPanelPopover.menuItems["Descending"].isEnabled)
    }

    func testManualSortWorksAsExpectedOnBookmarksPanel() {
        ["Bookmark #2", "Bookmark #3", "Bookmark #1"].forEach {
            addBookmark(pageTitle: $0)
            app.openNewTab()
        }

        closeShowBookmarksBarAlert()
        app.openBookmarksPanel()
        BookmarkUtilities.verifyBookmarkOrder(app: app, expectedOrder: ["Bookmark #2", "Bookmark #3", "Bookmark #1"], mode: .panel)
    }

    func testManualSortWorksAsExpectedOnBookmarksManager() {
        ["Bookmark #2", "Bookmark #3", "Bookmark #1"].forEach {
            addBookmark(pageTitle: $0)
            app.openNewTab()
        }

        closeShowBookmarksBarAlert()
        app.openBookmarksManager()
        BookmarkUtilities.verifyBookmarkOrder(app: app, expectedOrder: ["Bookmark #2", "Bookmark #3", "Bookmark #1"], mode: .manager)
    }

    func testNameAscendingSortWorksAsExpectedOnBookmarksPanel() {
        ["Bookmark #2", "Bookmark #3", "Bookmark #1"].forEach {
            addBookmark(pageTitle: $0)
            app.openNewTab()
        }

        closeShowBookmarksBarAlert()
        app.openBookmarksPanel()
        selectSortByName(mode: .panel)
        BookmarkUtilities.verifyBookmarkOrder(app: app, expectedOrder: ["Bookmark #1", "Bookmark #2", "Bookmark #3"], mode: .panel)
    }

    func testNameAscendingSortWorksAsExpectedOnBookmarksManager() {
        ["Bookmark #2", "Bookmark #3", "Bookmark #1"].forEach {
            addBookmark(pageTitle: $0)
            app.openNewTab()
        }

        closeShowBookmarksBarAlert()
        app.openBookmarksManager()
        selectSortByName(mode: .manager)
        BookmarkUtilities.verifyBookmarkOrder(app: app, expectedOrder: ["Bookmark #1", "Bookmark #2", "Bookmark #3"], mode: .manager)
    }

    func testNameDescendingSortWorksAsExpectedOnBookmarksPanel() {
        ["Bookmark #2", "Bookmark #3", "Bookmark #1"].forEach {
            addBookmark(pageTitle: $0)
            app.openNewTab()
        }

        closeShowBookmarksBarAlert()
        app.openBookmarksPanel()
        selectSortByName(mode: .panel, descending: true)
        BookmarkUtilities.verifyBookmarkOrder(app: app, expectedOrder: ["Bookmark #3", "Bookmark #2", "Bookmark #1"], mode: .panel)
    }

    func testNameDescendingSortWorksAsExpectedOnBookmarksManager() {
        ["Bookmark #2", "Bookmark #3", "Bookmark #1"].forEach {
            addBookmark(pageTitle: $0)
            app.openNewTab()
        }

        closeShowBookmarksBarAlert()
        app.openBookmarksManager()
        selectSortByName(mode: .manager, descending: true)
        BookmarkUtilities.verifyBookmarkOrder(app: app, expectedOrder: ["Bookmark #3", "Bookmark #2", "Bookmark #1"], mode: .manager)
    }

    func testThatSortIsPersistedThroughBrowserRestarts() {
        app.openBookmarksPanel()
        selectSortByName(mode: .panel)

        app.terminate()
        let newApp = XCUIApplication()
        newApp.launch()

        app.openBookmarksPanel()

        let sortBookmarksPanelButton = newApp.buttons[AccessibilityIdentifiers.sortBookmarksButtonPanel]
        sortBookmarksPanelButton.tap()

        let sortByNameManual = newApp.menuItems["Manual"]
        let sortByNameMenuItem = newApp.menuItems["Name"]
        let sortByNameAscendingMenuItem = newApp.menuItems["Ascending"]
        let sortByNameDescendingMenuItem = newApp.menuItems["Descending"]

        XCTAssertTrue(sortByNameManual.isEnabled)
        XCTAssertTrue(sortByNameMenuItem.isEnabled)
        XCTAssertTrue(sortByNameAscendingMenuItem.isEnabled)
        XCTAssertTrue(sortByNameDescendingMenuItem.isEnabled)
    }

    // MARK: - Utilities

    private func tapPanelSortButton() {
        let bookmarksPanelPopover = app.popovers.firstMatch
        let sortBookmarksButton = bookmarksPanelPopover.buttons[AccessibilityIdentifiers.sortBookmarksButtonPanel]
        sortBookmarksButton.tap()
    }

    private func selectSortByName(mode: BookmarkMode, descending: Bool = false) {
        if mode == .panel {
            let bookmarksPanelPopover = app.popovers.firstMatch
            let sortBookmarksButton = bookmarksPanelPopover.buttons[AccessibilityIdentifiers.sortBookmarksButtonPanel]
            sortBookmarksButton.tap()
            bookmarksPanelPopover.menuItems["Name"].tap()

            if descending {
                sortBookmarksButton.tap()
                bookmarksPanelPopover.menuItems["Descending"].tap()
            }
        } else {
            let sortBookmarksButton = app.buttons[AccessibilityIdentifiers.sortBookmarksButtonManager]
            sortBookmarksButton.tap()
            app.menuItems["Name"].tap()

            if descending {
                sortBookmarksButton.tap()
                app.menuItems["Descending"].tap()
                /// Here we hover over the sort button, because if we stay where the 'Descending' was selected
                /// the label of the bookmark being hovered is different because it shows the URL.
                sortBookmarksButton.hover()
            }
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

    private func closeShowBookmarksBarAlert() {
        BookmarkUtilities.dismissPopover(app: app, buttonIdentifier: "Hide")
    }
}
