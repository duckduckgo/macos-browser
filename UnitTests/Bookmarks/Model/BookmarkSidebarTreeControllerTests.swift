//
//  BookmarkSidebarTreeControllerTests.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

class BookmarkSidebarTreeControllerTests: XCTestCase {

    func testWhenBookmarkStoreHasNoFolders_ThenOnlyDefaultNodesAreReturned() {
        let dataSource = BookmarkSidebarTreeController()
        let treeController = BookmarkTreeController(dataSource: dataSource)
        let defaultNodes = treeController.rootNode.childNodes
        let representedObjects = defaultNodes.representedObjects()

        // The sidebar defines three hardcoded nodes:
        //
        // 1. Favorites node
        // 2. Spacer node
        // 3. Bookmarks node

        XCTAssertEqual(defaultNodes.count, 3)

        XCTAssertFalse(defaultNodes[0].canHaveChildNodes)
        XCTAssertFalse(defaultNodes[1].canHaveChildNodes)
        XCTAssertTrue(defaultNodes[2].canHaveChildNodes)

        XCTAssert(representedObjects[0] === PseudoFolder.favorites)
        XCTAssert(representedObjects[1] === SpacerNode.blank)
        XCTAssert(representedObjects[2] === PseudoFolder.bookmarks)
    }

    func testWhenBookmarkStoreHasNoTopLevelFolders_ThenTheDefaultBookmarksNodeHasNoChildren() {
        let bookmarkStoreMock = BookmarkStoreMock()
        let faviconManagerMock = FaviconManagerMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconManagement: faviconManagerMock)

        bookmarkStoreMock.bookmarks = [Bookmark.mock]
        bookmarkManager.loadBookmarks()

        let dataSource = BookmarkSidebarTreeController(bookmarkManager: bookmarkManager)
        let treeController = BookmarkTreeController(dataSource: dataSource)
        let defaultNodes = treeController.rootNode.childNodes
        XCTAssertEqual(defaultNodes.count, 3)

        // The sidebar tree controller only shows folders, so if there are only bookmarks then the bookmarks default folder will be empty.
        let bookmarksNode = defaultNodes[2]
        XCTAssert(bookmarksNode.childNodes.isEmpty)
    }

    func testWhenBookmarkStoreHasTopLevelFolders_ThenTheDefaultBookmarksNodeHasThemAsChildren() {
        let bookmarkStoreMock = BookmarkStoreMock()
        let faviconManagerMock = FaviconManagerMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconManagement: faviconManagerMock)
        let topLevelFolder = BookmarkFolder.mock

        bookmarkStoreMock.bookmarks = [topLevelFolder]
        bookmarkManager.loadBookmarks()

        let dataSource = BookmarkSidebarTreeController(bookmarkManager: bookmarkManager)
        let treeController = BookmarkTreeController(dataSource: dataSource)
        let defaultNodes = treeController.rootNode.childNodes
        XCTAssertEqual(defaultNodes.count, 3)

        let bookmarksNode = defaultNodes[2]
        XCTAssertEqual(bookmarksNode.childNodes.count, 1)

        let childNode = bookmarksNode.childNodes[0]
        XCTAssert(childNode.representedObjectEquals(topLevelFolder))
    }

    func testWhenBookmarkStoreHasNestedFolders_ThenTheTreeContainsNestedNodes() {
        let bookmarkStoreMock = BookmarkStoreMock()
        let faviconManagerMock = FaviconManagerMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconManagement: faviconManagerMock)

        let childFolder = BookmarkFolder(id: UUID().uuidString, title: "Child")
        let rootFolder = BookmarkFolder(id: UUID().uuidString, title: "Root", children: [childFolder])

        bookmarkStoreMock.bookmarks = [rootFolder]
        bookmarkManager.loadBookmarks()

        let dataSource = BookmarkSidebarTreeController(bookmarkManager: bookmarkManager)
        let treeController = BookmarkTreeController(dataSource: dataSource)
        let defaultNodes = treeController.rootNode.childNodes
        XCTAssertEqual(defaultNodes.count, 3)

        let bookmarksNode = defaultNodes[2]
        XCTAssertTrue(bookmarksNode.canHaveChildNodes)
        XCTAssertEqual(bookmarksNode.childNodes.count, 1)

        let rootFolderNode = bookmarksNode.childNodes[0]
        XCTAssertTrue(rootFolderNode.canHaveChildNodes)
        XCTAssert(rootFolderNode.representedObjectEquals(rootFolder))

        let childFolderNode = rootFolderNode.childNodes[0]
        XCTAssertEqual(childFolderNode.parent, rootFolderNode)
        XCTAssertFalse(childFolderNode.canHaveChildNodes)
        XCTAssert(childFolderNode.representedObjectEquals(childFolder))
    }

}
