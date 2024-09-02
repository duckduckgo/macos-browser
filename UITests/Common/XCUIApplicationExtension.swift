//
//  XCUIApplicationExtension.swift
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

extension XCUIApplication {

    private enum AccessibilityIdentifiers {
        static let bookmarksPanelShortcutButton = "NavigationBarViewController.bookmarkListButton"
        static let manageBookmarksMenuItem = "MainMenu.manageBookmarksMenuItem"
    }

    func enforceSingleWindow() {
        typeKey("w", modifierFlags: [.command, .option, .shift])
        typeKey("n", modifierFlags: .command)
    }

    func openNewTab() {
        typeKey("t", modifierFlags: .command)
    }

    // MARK: - Bookmarks

    /// Shows the bookmarks panel shortcut and taps it. If the bookmarks shortcut is visible, it only taps it.
    func openBookmarksPanel() {
        let bookmarksPanelShortcutButton = buttons[AccessibilityIdentifiers.bookmarksPanelShortcutButton]
        if !bookmarksPanelShortcutButton.exists {
            typeKey("K", modifierFlags: [.command, .shift])
        }

        bookmarksPanelShortcutButton.tap()
    }

    /// Opens the bookmarks manager via the menu
    func openBookmarksManager() {
        let manageBookmarksMenuItem = menuItems[AccessibilityIdentifiers.manageBookmarksMenuItem]
        XCTAssertTrue(
            manageBookmarksMenuItem.waitForExistence(timeout: UITests.Timeouts.elementExistence),
            "Manage bookmarks menu item didn't become available in a reasonable timeframe."
        )
        manageBookmarksMenuItem.click()
    }
}
