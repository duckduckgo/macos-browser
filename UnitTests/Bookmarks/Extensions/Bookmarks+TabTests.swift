//
//  Bookmarks+TabTests.swift
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

final class Bookmarks_TabTests: XCTestCase {

    @MainActor
    func testWhenBuildTabsWithContentOfFolderThenItShouldReturnAsManyTabsAsBookmarksWithinTheFolder() {
        // GIVEN
        let bookmark1 = Bookmark(id: "A", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: false)
        let bookmark2 = Bookmark(id: "B", url: URL.atb, title: "ATB", isFavorite: false)
        let subFolder = BookmarkFolder(id: "C", title: "Child")
        let folder = BookmarkFolder(id: "1", title: "Test", children: [bookmark1, subFolder, bookmark2])

        // WHEN
        let tab = Tab.withContentOfBookmark(folder: folder, burnerMode: .regular)

        // THEN
        XCTAssertEqual(tab.count, 2)
        XCTAssertEqual(tab.first?.url?.absoluteString, bookmark1.url)
        XCTAssertEqual(tab.first?.burnerMode, .regular)
        XCTAssertEqual(tab.last?.url?.absoluteString, bookmark2.url)
        XCTAssertEqual(tab.last?.burnerMode, .regular)
    }

    @MainActor
    func testWhenBuildTabCollectionWithContentOfFolderThenItShouldReturnACollectionWithAsManyTabsAsBookmarksWithinTheFolder() {
        // GIVEN
        let bookmark1 = Bookmark(id: "A", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: false)
        let bookmark2 = Bookmark(id: "B", url: URL.atb, title: "ATB", isFavorite: false)
        let subFolder = BookmarkFolder(id: "C", title: "Child")
        let folder = BookmarkFolder(id: "1", title: "Test", children: [bookmark1, subFolder, bookmark2])

        // WHEN
        let tabCollection = TabCollection.withContentOfBookmark(folder: folder, burnerMode: .regular)

        // THEN
        XCTAssertEqual(tabCollection.tabs.count, 2)
        XCTAssertEqual(tabCollection.tabs.first?.url?.absoluteString, bookmark1.url)
        XCTAssertEqual(tabCollection.tabs.first?.burnerMode, .regular)
        XCTAssertEqual(tabCollection.tabs.last?.url?.absoluteString, bookmark2.url)
        XCTAssertEqual(tabCollection.tabs.last?.burnerMode, .regular)
    }

}
