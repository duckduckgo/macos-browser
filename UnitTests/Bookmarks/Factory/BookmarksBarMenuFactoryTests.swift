//
//  BookmarksBarMenuFactoryTests.swift
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

final class BookmarksBarMenuFactoryTests: XCTestCase {

    func testReturnAddFolderAndManageBookmarksWhenAddToMenuWithManageBookmarksSectionIsCalled() {
        // GIVEN
        let menu = NSMenu(title: "")
        let targetMock = BookmarksBarTargetMock()
        XCTAssertTrue(menu.items.isEmpty)

        // WHEN
        BookmarksBarMenuFactory.addToMenuWithManageBookmarksSection(menu, target: targetMock, addFolderSelector: #selector(targetMock.addFolder(_:)), manageBookmarksSelector: #selector(targetMock.manageBookmarks))

        // THEN
        XCTAssertEqual(menu.items.count, 4)
        XCTAssertEqual(menu.items[1].title, "")
        XCTAssertNil(menu.items[1].action)
        XCTAssertEqual(menu.items[2].title, UserText.addFolder)
        XCTAssertEqual(menu.items[2].action, #selector(targetMock.addFolder(_:)))
        XCTAssertEqual(menu.items[3].title, UserText.bookmarksManageBookmarks)
        XCTAssertEqual(menu.items[3].action, #selector(targetMock.manageBookmarks))
    }

    func testShouldNotReturnAddFolderAndManageBookmarksWhenAddToMenuIsCalled() {
        // GIVEN
        let menu = NSMenu(title: "")
        XCTAssertTrue(menu.items.isEmpty)

        // WHEN
        BookmarksBarMenuFactory.addToMenu(menu)

        // THEN
        XCTAssertEqual(menu.items.count, 1)
    }
}

private class BookmarksBarTargetMock: NSObject {
    @objc func addFolder(_ sender: NSMenuItem) {}
    @objc func manageBookmarks() {}
}
