//
//  MoreOptionsMenu+BookmarksTests.swift
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
@testable import DuckDuckGo_Privacy_Browser

final class MoreOptionsMenu_BookmarksTests: XCTestCase {

    @MainActor
    func testWhenBookmarkSubmenuIsInitThenBookmarkAllTabsKeyIsCmdShiftD() throws {
        // GIVEN
        let sut = BookmarksSubMenu(targetting: self, tabCollectionViewModel: .init())

        // WHEN
        let result = try XCTUnwrap(sut.item(withTitle: UserText.bookmarkAllTabs))

        // THEN
        XCTAssertEqual(result.keyEquivalent, "d")
        XCTAssertEqual(result.keyEquivalentModifierMask, [.command, .shift])
    }

    @MainActor
    func testWhenTabCollectionCanBookmarkAllTabsThenBookmarkAllTabsMenuItemIsEnabled() throws {
        // GIVEN
        let tab1 = Tab(content: .url(.duckDuckGo, credential: nil, source: .ui))
        let tab2 = Tab(content: .url(.duckDuckGoEmail, credential: nil, source: .ui))
        let sut = BookmarksSubMenu(targetting: self, tabCollectionViewModel: .init(tabCollection: .init(tabs: [tab1, tab2])))

        // WHEN
        let result = try XCTUnwrap(sut.item(withTitle: UserText.bookmarkAllTabs))

        // THEN
        XCTAssertTrue(result.isEnabled)
    }

    @MainActor
    func testWhenTabCollectionCannotBookmarkAllTabsThenBookmarkAllTabsMenuItemIsDisabled() throws {
        // GIVEN
        let sut = BookmarksSubMenu(targetting: self, tabCollectionViewModel: .init(tabCollection: .init(tabs: [])))

        // WHEN
        let result = try XCTUnwrap(sut.item(withTitle: UserText.bookmarkAllTabs))

        // THEN
        XCTAssertFalse(result.isEnabled)
    }

}
