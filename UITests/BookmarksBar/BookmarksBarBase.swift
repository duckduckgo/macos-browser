//
//  BookmarksBarBase.swift
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

class BookmarksBarTestsBase: XCTestCase {
    static var classSetupDidRunOnce = Set<String>()

    var app: XCUIApplication!
    var pageTitle: String!
    var urlForBookmarksBar: URL!
    lazy var defaultBookmarkDialogButton = app.buttons["BookmarkDialogButtonsView.defaultButton"]
    lazy var showBookmarksBarPreferenceToggle = app.checkBoxes["Preferences.AppearanceView.showBookmarksBarPreferenceToggle"]
    lazy var resetBookMarksMenuItem = app.menuItems["MainMenu.resetBookmarks"]
    lazy var importBookMarksMenuItem = app.menuItems["MainMenu.importBookmarks"]
    lazy var showBookmarksBarPopup = app.popUpButtons["Preferences.AppearanceView.showBookmarksBarPopUp"]
    lazy var showBookmarksBarAlways = app.menuItems["Preferences.AppearanceView.showBookmarksBarAlways"]
    lazy var showBookmarksBarNewTabOnly = app.menuItems["Preferences.AppearanceView.showBookmarksBarNewTabOnly"]
    lazy var bookmarksBarCollectionView = app.collectionViews["BookmarksBarViewController.bookmarksBarCollectionView"]
    lazy var clippedItemsIndicator = app.collectionViews["BookmarksBarViewController.clippedItemsIndicator"]
    lazy var addressBarTextField = app.windows.textFields["AddressBarViewController.addressBarTextField"]
    let titleStringLength = 12

    override class func setUp() {
        UITests.firstRun()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "1"
        pageTitle = UITests.randomPageTitle(length: titleStringLength)
        urlForBookmarksBar = UITests.simpleServedPage(titled: pageTitle)
        app.launch()
        app.enforceSingleWindow()
        runSetupOnceIfNeeded()
    }

    @discardableResult
    func runSetupOnceIfNeeded() -> Bool {
        guard !Self.classSetupDidRunOnce.contains(self.className) else { return false }
        Self.classSetupDidRunOnce.insert(self.className)

        return true
    }

}

extension BookmarksBarTestsBase {

    func openSettings(andSetShowBookmarksBarTo checkedState: Bool) {
        app.typeKey(",", modifierFlags: [.command])

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
        if showBookmarksBarIsChecked != checkedState {
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

    func resetBookmarks() {
        XCTAssertTrue(
            resetBookMarksMenuItem.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Reset bookmarks menu item didn't become available in a reasonable timeframe."
        )

        resetBookMarksMenuItem.click()
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The Address Bar text field did not exist when it was expected."
        )
    }

    func addOneBookmark() {
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

    func importBookmarks(andShowBookmarksBar showBookmarksBar: Bool) {
        // Get test bookmarks html file path
        let bookmarksFile = Bundle(for: BookmarksBarMenuTests.self).path(forResource: "test_import_bookmarks", ofType: "html")!
        let originalPasteboardItems = NSPasteboard.general.pasteboardData() // Save original pasteboard contents
        NSPasteboard.general.copy(bookmarksFile)

        // Import data
        importBookMarksMenuItem.click()
        let window = app.windows.firstMatch
        let importSheet = window.sheets.firstMatch
        importSheet.popUpButtons.firstMatch.click()

        // Choose HTML Bookmarks File source
        importSheet.menuItems["HTML Bookmarks File (for other browsers)"].click()
        // Show OpenPanel
        importSheet.buttons["Select Bookmarks HTML File…"].click()
        let openPanel = app.dialogs["open-panel"]
        XCTAssertTrue(
            openPanel.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Could not get Open Panel"
        )

        openPanel.typeKey("g", modifierFlags: [.command, .shift]) // Go To Folder hotkey
        openPanel.typeKey("v", modifierFlags: [.command]) // Paste file path
        NSPasteboard.general.restore(from: originalPasteboardItems) // Restore original pasteboard contents
        openPanel.typeKey(.return, modifierFlags: []) // Open

        app.typeKey(.return, modifierFlags: []) // Import

        let nextButton = importSheet.buttons["Next"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: UITests.Timeouts.elementExistence), "no Next button")
        nextButton.click()

        let showBookmarksBarSwitch = importSheet.groups.children(matching: .switch).element(boundBy: 0)
        if (showBookmarksBarSwitch.value as! Bool) != showBookmarksBar {
            // switch Show Bookmarks Bar to On
            showBookmarksBarSwitch.click()
        }

        importSheet.buttons["Done"].click()
    }

}
