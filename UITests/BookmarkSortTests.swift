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

class BookmarkSortTests: UITestCase {
    private var app: XCUIApplication!

    private enum AccessibilityIdentifiers {
        static let addressBarTextField = "AddressBarViewController.addressBarTextField"
        static let resetBookmarksMenuItem = "MainMenu.resetBookmarks"
        static let sortBookmarksButtonPanel = "BookmarkListViewController.sortBookmarksButton"
        static let sortBookmarksButtonManager = "BookmarkManagementDetailViewController.sortItemsButton"
    }

    override class func setUp() {
        super.setUp()
        UITests.firstRun()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"
        app.launch()
        app.resetBookmarks()
        app.enforceSingleWindow()
    }

    func testWhenNoBookmarksThenSortIsDisabledOnThePanel() {
        app.openBookmarksPanel()

        let bookmarksPanelPopover = app.popovers.firstMatch
        let sortBookmarksButton = bookmarksPanelPopover.buttons[AccessibilityIdentifiers.sortBookmarksButtonPanel]
        XCTAssertFalse(sortBookmarksButton.isEnabled)
    }

    func testWhenNoBookmarksThenSortIsDisabledOnTheManager() {
        app.openBookmarksManager()

        let sortBookmarksButton = app.buttons[AccessibilityIdentifiers.sortBookmarksButtonManager]
        XCTAssertFalse(sortBookmarksButton.isEnabled)
    }

    func testWhenChangingSortingInThePanelIsReflectedInTheManager() {
        addBookmark(pageTitle: "Bookmark #1")
        app.dismissPopover(buttonIdentifier: "Hide")
        app.openBookmarksPanel()
        selectSortByName(mode: .panel)
        app.openBookmarksPanel() // Here we do not open the panel, we close it by tapping the shortcut button again.
        app.openBookmarksManager()

        app.buttons[AccessibilityIdentifiers.sortBookmarksButtonManager].tap()

        /// If the ascending and descending sort options are enabled, means that the sort in the panel was reflected here.
        XCTAssertTrue(app.menuItems["Ascending"].isEnabled)
        XCTAssertTrue(app.menuItems["Descending"].isEnabled)
    }

    func testWhenChangingSortingInTheManagerIsReflectedInThePanel() {
        addBookmark(pageTitle: "Bookmark #1")
        app.dismissPopover(buttonIdentifier: "Hide")
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
        app.verifyBookmarkOrder(expectedOrder: ["Bookmark #2", "Bookmark #3", "Bookmark #1"], mode: .panel)
    }

    func testManualSortWorksAsExpectedOnBookmarksManager() {
        ["Bookmark #2", "Bookmark #3", "Bookmark #1"].forEach {
            addBookmark(pageTitle: $0)
            app.openNewTab()
        }

        closeShowBookmarksBarAlert()
        app.openBookmarksManager()
        app.verifyBookmarkOrder(expectedOrder: ["Bookmark #2", "Bookmark #3", "Bookmark #1"], mode: .manager)
    }

    func testNameAscendingSortWorksAsExpectedOnBookmarksPanel() {
        ["Bookmark #2", "Bookmark #3", "Bookmark #1"].forEach {
            addBookmark(pageTitle: $0)
            app.openNewTab()
        }

        closeShowBookmarksBarAlert()
        app.openBookmarksPanel()
        selectSortByName(mode: .panel)
        app.verifyBookmarkOrder(expectedOrder: ["Bookmark #1", "Bookmark #2", "Bookmark #3"], mode: .panel)
    }

    func testNameAscendingSortWorksAsExpectedOnBookmarksManager() {
        ["Bookmark #2", "Bookmark #3", "Bookmark #1"].forEach {
            addBookmark(pageTitle: $0)
            app.openNewTab()
        }

        closeShowBookmarksBarAlert()
        app.openBookmarksManager()
        selectSortByName(mode: .manager)
        app.verifyBookmarkOrder(expectedOrder: ["Bookmark #1", "Bookmark #2", "Bookmark #3"], mode: .manager)
    }

    func testNameDescendingSortWorksAsExpectedOnBookmarksPanel() {
        ["Bookmark #2", "Bookmark #3", "Bookmark #1"].forEach {
            addBookmark(pageTitle: $0)
            app.openNewTab()
        }

        closeShowBookmarksBarAlert()
        app.openBookmarksPanel()
        selectSortByName(mode: .panel, descending: true)
        app.verifyBookmarkOrder(expectedOrder: ["Bookmark #3", "Bookmark #2", "Bookmark #1"], mode: .panel)
    }

    func testNameDescendingSortWorksAsExpectedOnBookmarksManager() {
        ["Bookmark #2", "Bookmark #3", "Bookmark #1"].forEach {
            addBookmark(pageTitle: $0)
            app.openNewTab()
        }

        closeShowBookmarksBarAlert()
        app.openBookmarksManager()
        selectSortByName(mode: .manager, descending: true)
        app.verifyBookmarkOrder(expectedOrder: ["Bookmark #3", "Bookmark #2", "Bookmark #1"], mode: .manager)
    }

    func testThatSortIsPersistedThroughBrowserRestarts() {
        addBookmark(pageTitle: "Bookmark #1")
        app.openBookmarksPanel()
        selectSortByName(mode: .panel)

        app.terminate()
        let newApp = XCUIApplication()
        newApp.launchEnvironment["UITEST_MODE"] = "1"
        newApp.launch()
        newApp.enforceSingleWindow()

        // Wait for new application to start
        XCTAssertTrue(newApp.waitForExistence(timeout: UITests.Timeouts.elementExistence))

        newApp.openBookmarksPanel()

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
        app.openSiteToBookmark(url: urlForBookmarksBar,
                               pageTitle: pageTitle,
                               bookmarkingViaDialog: true,
                               escapingDialog: true,
                               folderName: folder)
    }

    private func closeShowBookmarksBarAlert() {
        app.dismissPopover(buttonIdentifier: "Hide")
    }
}
