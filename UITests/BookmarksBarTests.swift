//
//  BookmarksBarTests.swift
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

class BookmarksBarTests: XCTestCase {
    private var app: XCUIApplication!
    private let elementExistenceTimeout = 0.3
    private let pageTitle = String(UUID().uuidString.prefix(16))
    private var urlForBookmarksBar: URL!
    private var settingsWindow: XCUIElement!
    private var siteWindow: XCUIElement!
    private var addBookmarkButton: XCUIElement!
    private var resetBookMarksMenuItem: XCUIElement!
    private var showBookmarksBarPreferenceToggle: XCUIElement!
    private var showBookmarksBarPopup: XCUIElement!
    private var showBookmarksBarAlways: XCUIElement!
    private var showBookmarksBarNewTabOnly: XCUIElement!
    private var bookmarksBarCollectionView: XCUIElement!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        addBookmarkButton = app.buttons["BookmarkDialogButtonsView.defaultButton"]

        showBookmarksBarPreferenceToggle = app.checkBoxes["Preferences.AppearanceView.showBookmarksBarPreferenceToggle"]
        resetBookMarksMenuItem = app.menuItems["MainMenu.resetBookmarks"]
        urlForBookmarksBar = locallyServedURL(pageTitle: pageTitle)
        app.launch()
        resetBookmarksAndAddOneBookmark()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Close windows
        openSettingsAndSetShowBookmarksBarToUnchecked()
        settingsWindow = app.windows.containing(.checkBox, identifier: "Preferences.AppearanceView.showBookmarksBarPreferenceToggle").firstMatch
        openSecondWindowAndVisitSite()
        siteWindow = app.windows.containing(.webView, identifier: pageTitle).firstMatch
        showBookmarksBarPopup = app.popUpButtons["Preferences.AppearanceView.showBookmarksBarPopUp"]
        showBookmarksBarAlways = app.menuItems["Preferences.AppearanceView.showBookmarksBarAlways"]
        showBookmarksBarNewTabOnly = app.collectionViews["Preferences.AppearanceView.showBookmarksBarNewTabOnly"]
        bookmarksBarCollectionView = app.collectionViews["BookmarksBarViewController.bookmarksBarCollectionView"]
    }

    func test_clickingShowBookmarksBarAlwaysShowCausesBookmarksBarToDynamicallyAppearOnWindow() throws {
        settingsWindow.click()
        let showBookmarksBarIsChecked = showBookmarksBarPreferenceToggle.value as? Bool
        if showBookmarksBarIsChecked == false {
            showBookmarksBarPreferenceToggle.click()
        }

        XCTAssertTrue(
            showBookmarksBarPopup.waitForExistence(timeout: elementExistenceTimeout),
            "The \"show bookmarks bar\" popup button didn't become available in a reasonable timeframe."
        )
        showBookmarksBarPopup.click()

        XCTAssertTrue(
            showBookmarksBarAlways.waitForExistence(timeout: elementExistenceTimeout),
            "The \"show bookmarks bar always\" button didn't become available in a reasonable timeframe."
        )
        showBookmarksBarAlways.click()
        siteWindow.click()

        XCTAssertTrue(
            bookmarksBarCollectionView.waitForExistence(timeout: elementExistenceTimeout),
            "The bookmarksBarCollectionView should exist on a website window when we have selected always show bookmarks bar in the settings"
        )
    }
}

private extension BookmarksBarTests {
    func openSettingsAndSetShowBookmarksBarToUnchecked() {
        app.typeKey(",", modifierFlags: [.command])

        let settingsAppearanceButton = app.buttons["PreferencesSidebar.appearanceButton"]
        XCTAssertTrue(
            settingsAppearanceButton.waitForExistence(timeout: elementExistenceTimeout),
            "The user settings appearance section button didn't become available in a reasonable timeframe."
        )
        // TODO: this should just be a click() but there are states for this test where the first few clicks don't register here.
        settingsAppearanceButton.click(forDuration: elementExistenceTimeout, thenDragTo: settingsAppearanceButton)

        XCTAssertTrue(
            showBookmarksBarPreferenceToggle.waitForExistence(timeout: elementExistenceTimeout),
            "The toggle for showing the bookmarks bar didn't become available in a reasonable timeframe."
        )

        let showBookmarksBarIsChecked = showBookmarksBarPreferenceToggle.value as? Bool
        if showBookmarksBarIsChecked == true {
            showBookmarksBarPreferenceToggle.click()
        }
    }

    func openSecondWindowAndVisitSite() {
        app.typeKey("n", modifierFlags: [.command])
        app.typeText("\(locallyServedURL(pageTitle: pageTitle).absoluteString)\r")
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

    func resetBookmarksAndAddOneBookmark() {
        XCTAssertTrue(
            resetBookMarksMenuItem.waitForExistence(timeout: elementExistenceTimeout),
            "Reset bookmarks menu item didn't become available in a reasonable timeframe."
        )

        resetBookMarksMenuItem.click()

        let urlForBookmarks = locallyServedURL(pageTitle: pageTitle)

        app.typeText("\(urlForBookmarks.absoluteString)\r")
        XCTAssertTrue(
            app.windows.webViews["\(pageTitle)"].waitForExistence(timeout: elementExistenceTimeout),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )

        app.typeKey("d", modifierFlags: [.command]) // Bookmark the page

        XCTAssertTrue(
            addBookmarkButton.waitForExistence(timeout: 1.0),
            "Bookmark button didn't appear with the expected title in a reasonable timeframe."
        )

        addBookmarkButton.click()
    }
}
