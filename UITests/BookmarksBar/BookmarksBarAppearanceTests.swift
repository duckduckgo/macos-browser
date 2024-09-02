//
//  BookmarksBarAppearanceTests.swift
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

class BookmarksBarAppearanceTests: BookmarksBarTestsBase {

    override func runSetupOnceIfNeeded() -> Bool {
        guard super.runSetupOnceIfNeeded() else { return false }

        resetBookmarks()
        addOneBookmark()
        openSettings(andSetShowBookmarksBarTo: false)
        app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Close windows

        return true
    }

    func test_bookmarksBar_whenShowBookmarksBarAlwaysIsSelected_alwaysDynamicallyAppearsOnWindow() throws {
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

        app.enforceSingleWindow()
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
