//
//  BookmarksSortModeTests.swift
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

class BookmarksSortModeTests: XCTestCase {

    func testTitle() {
        XCTAssertEqual(BookmarksSortMode.manual.title, UserText.bookmarksSortManual)
        XCTAssertEqual(BookmarksSortMode.nameAscending.title, UserText.bookmarksSortByNameAscending)
        XCTAssertEqual(BookmarksSortMode.nameDescending.title, UserText.bookmarksSortByNameDescending)
    }

    func testAction() {
        XCTAssertEqual(BookmarksSortMode.manual.action, #selector(BookmarkSortMenuItemSelectors.manualSort(_:)))
        XCTAssertEqual(BookmarksSortMode.nameAscending.action, #selector(BookmarkSortMenuItemSelectors.sortByNameAscending(_:)))
        XCTAssertEqual(BookmarksSortMode.nameDescending.action, #selector(BookmarkSortMenuItemSelectors.sortByNameDescending(_:)))
    }

    func testShouldHighlightButton() {
        XCTAssertFalse(BookmarksSortMode.manual.shouldHighlightButton)
        XCTAssertTrue(BookmarksSortMode.nameAscending.shouldHighlightButton)
        XCTAssertTrue(BookmarksSortMode.nameDescending.shouldHighlightButton)
    }

    func testMenuForManual() {
        let manualMenu = BookmarksSortMode.manual.menu(target: self)

        XCTAssertEqual(manualMenu.items.count, 5)

        XCTAssertEqual(manualMenu.items[0].title, UserText.bookmarksSortManual)
        XCTAssertEqual(manualMenu.items[0].state, .on)

        XCTAssertEqual(manualMenu.items[1].title, UserText.bookmarksSortByName)
        XCTAssertEqual(manualMenu.items[1].state, .off)

        XCTAssert(manualMenu.items[2].isSeparatorItem)

        XCTAssertEqual(manualMenu.items[3].title, UserText.bookmarksSortByNameAscending)
        XCTAssertEqual(manualMenu.items[3].state, .off)
        XCTAssertNil(manualMenu.items[3].action)

        XCTAssertEqual(manualMenu.items[4].title, UserText.bookmarksSortByNameDescending)
        XCTAssertEqual(manualMenu.items[4].state, .off)
        XCTAssertNil(manualMenu.items[4].action)
    }

    func testMenuForNameAscending() {
        let ascendingMenu = BookmarksSortMode.nameAscending.menu(target: self)

        XCTAssertEqual(ascendingMenu.items.count, 5)

        XCTAssertEqual(ascendingMenu.items[0].title, UserText.bookmarksSortManual)
        XCTAssertEqual(ascendingMenu.items[0].state, .off)

        XCTAssertEqual(ascendingMenu.items[1].title, UserText.bookmarksSortByName)
        XCTAssertEqual(ascendingMenu.items[1].state, .on)

        XCTAssert(ascendingMenu.items[2].isSeparatorItem)

        XCTAssertEqual(ascendingMenu.items[3].title, UserText.bookmarksSortByNameAscending)
        XCTAssertEqual(ascendingMenu.items[3].state, .on)

        XCTAssertEqual(ascendingMenu.items[4].title, UserText.bookmarksSortByNameDescending)
        XCTAssertEqual(ascendingMenu.items[4].state, .off)
    }

    func testMenuForNameDescending() {
        let descendingMenu = BookmarksSortMode.nameDescending.menu(target: self)

        XCTAssertEqual(descendingMenu.items.count, 5)

        XCTAssertEqual(descendingMenu.items[0].title, UserText.bookmarksSortManual)
        XCTAssertEqual(descendingMenu.items[0].state, .off)

        XCTAssertEqual(descendingMenu.items[1].title, UserText.bookmarksSortByName)
        XCTAssertEqual(descendingMenu.items[1].state, .on)

        XCTAssert(descendingMenu.items[2].isSeparatorItem)

        XCTAssertEqual(descendingMenu.items[3].title, UserText.bookmarksSortByNameAscending)
        XCTAssertEqual(descendingMenu.items[3].state, .off)

        XCTAssertEqual(descendingMenu.items[4].title, UserText.bookmarksSortByNameDescending)
        XCTAssertEqual(descendingMenu.items[4].state, .on)
    }

    func testReorderingValueIsCorrect() {
        XCTAssertTrue(BookmarksSortMode.manual.isReorderingEnabled)
        XCTAssertFalse(BookmarksSortMode.nameAscending.isReorderingEnabled)
        XCTAssertFalse(BookmarksSortMode.nameDescending.isReorderingEnabled)
    }
}
