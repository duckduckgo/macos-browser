//
//  MainMenuTests.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import Combine
import BrowserServicesKit
@testable import DuckDuckGo_Privacy_Browser

class MainMenuTests: XCTestCase {

    typealias ReopenMenuItemKeyEquivalentManager = HistoryMenu.ReopenMenuItemKeyEquivalentManager

    @Published var isInInitialState = true

    var lastSessionMenuItem: NSMenuItem!
    var lastTabMenuItem: NSMenuItem!
    var manager: ReopenMenuItemKeyEquivalentManager!

    override func setUpWithError() throws {
        isInInitialState = true
        lastSessionMenuItem = NSMenuItem()
        lastTabMenuItem = NSMenuItem()
    }

    func testWhenIsInInitialState_AndCanRestoreState_ThenLastSessionMenuItemHasShortcut() {
        manager = .init(isInInitialStatePublisher: $isInInitialState, canRestoreLastSessionState: true)
        manager.lastSessionMenuItem = lastSessionMenuItem
        manager.reopenLastClosedMenuItem = lastTabMenuItem

        isInInitialState = true

        XCTAssertEqual(manager.lastSessionMenuItem?.keyEquivalent, ReopenMenuItemKeyEquivalentManager.Const.keyEquivalent)
        XCTAssertEqual(manager.lastSessionMenuItem?.keyEquivalentModifierMask, ReopenMenuItemKeyEquivalentManager.Const.modifierMask)
        XCTAssertEqual(manager.reopenLastClosedMenuItem?.keyEquivalent, "")
        XCTAssertEqual(manager.reopenLastClosedMenuItem?.keyEquivalentModifierMask, .command)
    }

    func testWhenIsInInitialState_AndCannotRestoreState_ThenLastTabMenuItemHasShortcut() {
        manager = .init(isInInitialStatePublisher: $isInInitialState, canRestoreLastSessionState: false)
        manager.lastSessionMenuItem = lastSessionMenuItem
        manager.reopenLastClosedMenuItem = lastTabMenuItem

        isInInitialState = true

        XCTAssertEqual(manager.lastSessionMenuItem?.keyEquivalent, "")
        XCTAssertEqual(manager.lastSessionMenuItem?.keyEquivalentModifierMask, .command)
        XCTAssertEqual(manager.reopenLastClosedMenuItem?.keyEquivalent, ReopenMenuItemKeyEquivalentManager.Const.keyEquivalent)
        XCTAssertEqual(manager.reopenLastClosedMenuItem?.keyEquivalentModifierMask, ReopenMenuItemKeyEquivalentManager.Const.modifierMask)
    }

    func testWhenIsNotInInitialState_AndCanRestoreState_ThenLastTabMenuItemHasShortcut() {
        manager = .init(isInInitialStatePublisher: $isInInitialState, canRestoreLastSessionState: true)
        manager.lastSessionMenuItem = lastSessionMenuItem
        manager.reopenLastClosedMenuItem = lastTabMenuItem

        isInInitialState = false

        XCTAssertEqual(manager.lastSessionMenuItem?.keyEquivalent, "")
        XCTAssertEqual(manager.lastSessionMenuItem?.keyEquivalentModifierMask, .command)
        XCTAssertEqual(manager.reopenLastClosedMenuItem?.keyEquivalent, ReopenMenuItemKeyEquivalentManager.Const.keyEquivalent)
        XCTAssertEqual(manager.reopenLastClosedMenuItem?.keyEquivalentModifierMask, ReopenMenuItemKeyEquivalentManager.Const.modifierMask)
    }

    func testWhenIsNotInInitialState_AndCannotRestoreState_ThenLastTabMenuItemHasShortcut() {
        manager = .init(isInInitialStatePublisher: $isInInitialState, canRestoreLastSessionState: false)
        manager.lastSessionMenuItem = lastSessionMenuItem
        manager.reopenLastClosedMenuItem = lastTabMenuItem

        isInInitialState = false

        XCTAssertEqual(manager.lastSessionMenuItem?.keyEquivalent, "")
        XCTAssertEqual(manager.lastSessionMenuItem?.keyEquivalentModifierMask, .command)
        XCTAssertEqual(manager.reopenLastClosedMenuItem?.keyEquivalent, ReopenMenuItemKeyEquivalentManager.Const.keyEquivalent)
        XCTAssertEqual(manager.reopenLastClosedMenuItem?.keyEquivalentModifierMask, ReopenMenuItemKeyEquivalentManager.Const.modifierMask)
    }

    // MARK: - Bookmarks

    @MainActor
    func testWhenBookmarksMenuIsInitialized_ThenSecondItemIsBookmarkAllTabs() throws {
        // GIVEN
        let sut = MainMenu(featureFlagger: DummyFeatureFlagger(), bookmarkManager: MockBookmarkManager(), faviconManager: FaviconManagerMock(), copyHandler: CopyHandler())
        let bookmarksMenu = try XCTUnwrap(sut.item(withTitle: UserText.bookmarks))

        // WHEN
        let result = try XCTUnwrap(bookmarksMenu.submenu?.item(withTitle: UserText.bookmarkAllTabs))

        // THEN
        XCTAssertEqual(result.keyEquivalent, "d")
        XCTAssertEqual(result.keyEquivalentModifierMask, [.command, .shift])
    }
}

private class DummyFeatureFlagger: FeatureFlagger {
    func isFeatureOn<F: BrowserServicesKit.FeatureFlagSourceProviding>(forProvider: F) -> Bool {
        false
    }
}
