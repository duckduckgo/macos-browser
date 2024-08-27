//
//  BookmarksUtilites.swift
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

// Enum to represent bookmark modes
enum BookmarkMode {
    case panel
    case manager
}

class BookmarkUtilities {

    /// Reset the bookmarks so we can rely on a single bookmark's existence
    static func resetBookmarks(app: XCUIApplication, resetMenuItem: XCUIElement) {
        app.typeKey("n", modifierFlags: [.command]) // Can't use debug menu without a window
        XCTAssertTrue(
            resetMenuItem.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Reset bookmarks menu item didn't become available in a reasonable timeframe."
        )
        resetMenuItem.click()
    }

    /// Open the initial site to be bookmarked, bookmarking it and/or escaping out of the dialog only if needed
    /// - Parameter url: The URL we will use to load the bookmark
    /// - Parameter pageTitle: The page title that would become the bookmark name
    /// - Parameter bookmarkingViaDialog: open bookmark dialog, adding bookmark
    /// - Parameter escapingDialog: `esc` key to leave dialog
    /// - Parameter folderName: The name of the folder where you want to save the bookmark. If the folder does not exist, it fails.
    static func openSiteToBookmark(app: XCUIApplication,
                                   url: URL,
                                   pageTitle: String,
                                   bookmarkingViaDialog: Bool,
                                   escapingDialog: Bool,
                                   addressBarTextField: XCUIElement,
                                   folderName: String? = nil) {
        XCTAssertTrue(
            addressBarTextField.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "The address bar text field didn't become available in a reasonable timeframe."
        )
        addressBarTextField.typeURL(url)
        XCTAssertTrue(
            app.windows.webViews[pageTitle].waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Visited site didn't load with the expected title in a reasonable timeframe."
        )
        if bookmarkingViaDialog {
            app.typeKey("d", modifierFlags: [.command]) // Add bookmark

            if let folderName = folderName {
                let folderLocationButton = app.popUpButtons["bookmark.add.folder.dropdown"]
                folderLocationButton.tap()
                let folderOneLocation = folderLocationButton.menuItems[folderName]
                folderOneLocation.tap()
            }

            if escapingDialog {
                app.typeKey(.escape, modifierFlags: []) // Exit dialog
            }
        }
    }

    /// Dismiss popover with the passed button identifier
    /// - Parameter buttonIdentifier: The button identifier we want to tap from the popover
    static func dismissPopover(app: XCUIApplication, buttonIdentifier: String) {
        let popover = app.popovers.firstMatch
        let button = popover.buttons[buttonIdentifier]
        button.tap()
    }

    static func verifyBookmarkOrder(app: XCUIApplication, expectedOrder: [String], mode: BookmarkMode) {
        let rowCount = (mode == .panel ? app.popovers.firstMatch.outlines.firstMatch : app.tables.firstMatch).cells.count
        XCTAssertEqual(rowCount, expectedOrder.count, "Row count does not match expected count.")

        for index in 0..<rowCount {
            let cell = (mode == .panel ? app.popovers.firstMatch.outlines.firstMatch : app.tables.firstMatch).cells.element(boundBy: index)
            XCTAssertTrue(cell.exists, "Cell at index \(index) does not exist.")

            let cellLabel = cell.staticTexts[expectedOrder[index]]
            XCTAssertTrue(cellLabel.exists, "Cell at index \(index) has unexpected label.")
        }
    }
}
