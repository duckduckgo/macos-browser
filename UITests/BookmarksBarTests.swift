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

import XCTest

class BookmarksBarTests: UITestCase {
    private var app: XCUIApplication!
    private var pageTitle: String!
    private var urlForBookmarksBar: URL!
    private var settingsWindow: XCUIElement!
    private var siteWindow: XCUIElement!
    private var defaultBookmarkDialogButton: XCUIElement!
    private var resetBookMarksMenuItem: XCUIElement!
    private var showBookmarksBarPreferenceToggle: XCUIElement!
    private var showBookmarksBarPopup: XCUIElement!
    private var showBookmarksBarAlways: XCUIElement!
    private var showBookmarksBarNewTabOnly: XCUIElement!
    private var bookmarksBarCollectionView: XCUIElement!
    private var addressBarTextField: XCUIElement!
    private let titleStringLength = 12

    override class func setUp() {
        super.setUp()
        UITests.firstRun()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"
        defaultBookmarkDialogButton = app.buttons["BookmarkDialogButtonsView.defaultButton"]
        showBookmarksBarPreferenceToggle = app.checkBoxes["Preferences.AppearanceView.showBookmarksBarPreferenceToggle"]
        resetBookMarksMenuItem = app.menuItems["MainMenu.resetBookmarks"]
        showBookmarksBarPopup = app.popUpButtons["Preferences.AppearanceView.showBookmarksBarPopUp"]
        showBookmarksBarAlways = app.menuItems["Preferences.AppearanceView.showBookmarksBarAlways"]
        showBookmarksBarNewTabOnly = app.menuItems["Preferences.AppearanceView.showBookmarksBarNewTabOnly"]
        bookmarksBarCollectionView = app.collectionViews["BookmarksBarViewController.bookmarksBarCollectionView"]
        addressBarTextField = app.windows.textFields["AddressBarViewController.addressBarTextField"]
        pageTitle = UITests.randomPageTitle(length: titleStringLength)
        urlForBookmarksBar = UITests.simpleServedPage(titled: pageTitle)
        app.launch()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Close windows
        app.typeKey("n", modifierFlags: [.command]) // Guarantee a single window
        resetBookmarksAndAddOneBookmark()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Close windows
        app.typeKey("n", modifierFlags: [.command])
        openSettingsAndSetShowBookmarksBarToUnchecked()
        openSecondWindowAndVisitSite()
        siteWindow = app.windows.containing(.webView, identifier: pageTitle).firstMatch
    }

    func test_bookmarksBar_whenShowBookmarksBarAlwaysIsSelected_alwaysDynamicallyAppearsOnWindow() throws {
        app.typeKey("w", modifierFlags: [.command])
        XCTAssertTrue(
            showBookmarksBarPreferenceToggle.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The toggle for showing the bookmarks bar didn't become available in a reasonable timeframe."
        )

        let showBookmarksBarIsChecked = try? XCTUnwrap(
            showBookmarksBarPreferenceToggle.value as? Bool,
            "It wasn't possible to get the \"Show bookmarks bar\" value as a Bool"
        )
        if showBookmarksBarIsChecked == false {
            showBookmarksBarPreferenceToggle.click()
        }
        XCTAssertTrue(
            showBookmarksBarPopup.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Show Bookmarks Bar\" popup button didn't become available in a reasonable timeframe."
        )
        showBookmarksBarPopup.click()
        XCTAssertTrue(
            showBookmarksBarAlways.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Show Bookmarks Bar Always\" button didn't become available in a reasonable timeframe."
        )
        showBookmarksBarAlways.click()

        XCTAssertTrue(
            bookmarksBarCollectionView.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The bookmarksBarCollectionView should exist on a website window when we have selected \"Always Show Bookmarks Bar\" in the settings"
        )
    }

    func test_bookmarksBar_whenShowBookmarksNewTabOnlyIsSelected_onlyAppearsOnANewTabUntilASiteIsLoaded() throws {
        app.typeKey("w", modifierFlags: [.command]) // Close site window
        XCTAssertTrue(
            showBookmarksBarPreferenceToggle.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The toggle for showing the bookmarks bar didn't become available in a reasonable timeframe."
        )

        let showBookmarksBarIsChecked = try? XCTUnwrap(
            showBookmarksBarPreferenceToggle.value as? Bool,
            "It wasn't possible to get the \"Show bookmarks bar\" value as a Bool"
        )
        if showBookmarksBarIsChecked == false {
            showBookmarksBarPreferenceToggle.click()
        }
        XCTAssertTrue(
            showBookmarksBarPopup.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Show Bookmarks Bar\" popup button didn't become available in a reasonable timeframe."
        )
        showBookmarksBarPopup.click()

        XCTAssertTrue(
            showBookmarksBarNewTabOnly.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The \"Show Bookmarks Bar Always\" button didn't become available in a reasonable timeframe."
        )
        showBookmarksBarNewTabOnly.click()
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Close windows
        app.typeKey("n", modifierFlags: [.command]) // open one new window

        XCTAssertTrue(
            bookmarksBarCollectionView.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The bookmarksBarCollectionView should exist on a new tab into which no site name or location has been typed yet."
        )
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The Address Bar text field did not exist when it was expected."
        )
        addressBarTextField.typeURL(urlForBookmarksBar)
        XCTAssertTrue(
            bookmarksBarCollectionView.waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "The bookmarksBarCollectionView should not exist on a tab that has been directed to a site, and is no longer new, when we have selected show bookmarks bar \"New Tab Only\" in the settings"
        )
    }

    func test_bookmarksBar_whenShowBookmarksBarIsUnchecked_isNeverShownInWindowsAndTabs() throws {
        // This tests begins in the state that "show bookmarks bar" is unchecked, so that isn't set within the test

        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Close windows
        app.typeKey("n", modifierFlags: [.command]) // Open new window
        XCTAssertTrue(
            bookmarksBarCollectionView.waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "The bookmarksBarCollectionView should not exist on a new window when we have unchecked \"Show Bookmarks Bar\" in the settings"
        )

        app.typeKey("t", modifierFlags: [.command]) // Open new tab
        XCTAssertTrue(
            bookmarksBarCollectionView.waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "The bookmarksBarCollectionView should not exist on a new tab when we have unchecked \"Show Bookmarks Bar\" in the settings"
        )
        app.typeKey("l", modifierFlags: [.command]) // Get address bar focus
        app.typeURL(urlForBookmarksBar)

        XCTAssertTrue(
            bookmarksBarCollectionView.waitForNonExistence(timeout: UITests.Timeouts.elementExistence),
            "The bookmarksBarCollectionView should not exist on a new tab that has been directed to a site when we have unchecked \"Show Bookmarks Bar\" in the settings"
        )
    }
}

private extension BookmarksBarTests {
    func openSettingsAndSetShowBookmarksBarToUnchecked() {
        addressBarTextField.typeURL(URL(string: "duck://settings")!)

        let settingsAppearanceButton = app.buttons["PreferencesSidebar.appearanceButton"]
        XCTAssertTrue(
            settingsAppearanceButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The user settings appearance section button didn't become available in a reasonable timeframe."
        )
        // This should just be a click(), but there are states for this test where the first few clicks don't register here.
        settingsAppearanceButton.click(forDuration: UITests.Timeouts.elementExistence, thenDragTo: settingsAppearanceButton)

        XCTAssertTrue(
            showBookmarksBarPreferenceToggle.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The toggle for showing the bookmarks bar didn't become available in a reasonable timeframe."
        )

        let showBookmarksBarIsChecked = showBookmarksBarPreferenceToggle.value as? Bool
        if showBookmarksBarIsChecked == true {
            showBookmarksBarPreferenceToggle.click()
        }
    }

    func openSecondWindowAndVisitSite() {
        app.typeKey("n", modifierFlags: [.command])
        app.typeKey("l", modifierFlags: [.command]) // Get address bar focus without addressing multiple address bars by identifier
        XCTAssertTrue( // Use home page logo as a test to know if a new window is fully ready before we type
            app.images["HomePageLogo"].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The Home Page Logo did not exist when it was expected."
        )
        app.typeURL(urlForBookmarksBar)
    }

    func resetBookmarksAndAddOneBookmark() {
        XCTAssertTrue(
            resetBookMarksMenuItem.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Reset bookmarks menu item didn't become available in a reasonable timeframe."
        )

        resetBookMarksMenuItem.click()
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The Address Bar text field did not exist when it was expected."
        )
        addressBarTextField.typeURL(urlForBookmarksBar)
        XCTAssertTrue(
            app.windows.webViews[pageTitle].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )

        app.typeKey("d", modifierFlags: [.command]) // Bookmark the page

        XCTAssertTrue(
            defaultBookmarkDialogButton.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Bookmark button didn't appear with the expected title in a reasonable timeframe."
        )

        defaultBookmarkDialogButton.click()
    }
}
