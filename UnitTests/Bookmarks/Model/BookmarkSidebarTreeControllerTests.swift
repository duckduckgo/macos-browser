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
        let dataSource = BookmarkSidebarTreeController(bookmarkManager: LocalBookmarkManager())
        let treeController = BookmarkTreeController(dataSource: dataSource, sortMode: .manual)
        let defaultNodes = treeController.rootNode.childNodes
        let representedObjects = defaultNodes.representedObjects()

        // The sidebar defines one hardcoded nodes:
        //
        // 1. Bookmarks node

        XCTAssertEqual(defaultNodes.count, 1)

        XCTAssertTrue(defaultNodes[0].canHaveChildNodes)

        XCTAssert(representedObjects.first === PseudoFolder.bookmarks)
    }

    @MainActor
    func testWhenBookmarkStoreHasNoTopLevelFolders_ThenTheDefaultBookmarksNodeHasNoChildren() throws {
        let bookmarkStoreMock = BookmarkStoreMock(bookmarks: [Bookmark.mock])
        let faviconManagerMock = FaviconManagerMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconManagement: faviconManagerMock)
        bookmarkManager.loadBookmarks()

        let dataSource = BookmarkSidebarTreeController(bookmarkManager: bookmarkManager)
        let treeController = BookmarkTreeController(dataSource: dataSource, sortMode: .manual)
        let defaultNodes = treeController.rootNode.childNodes
        XCTAssertEqual(defaultNodes.count, 1)

        // The sidebar tree controller only shows folders, so if there are only bookmarks then the bookmarks default folder will be empty.
        let bookmarksNode = defaultNodes[0]
        let pseudoFolder = try XCTUnwrap(bookmarksNode.representedObject as? PseudoFolder)
        XCTAssertTrue(bookmarksNode.childNodes.isEmpty)
        XCTAssertEqual(pseudoFolder.name, "Bookmarks")
    }

    @MainActor
    func testWhenBookmarkStoreHasTopLevelFolders_ThenTheDefaultBookmarksNodeHasThemAsChildren() {
        let topLevelFolder = BookmarkFolder.mock
        let bookmarkStoreMock = BookmarkStoreMock(bookmarks: [topLevelFolder])
        let faviconManagerMock = FaviconManagerMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconManagement: faviconManagerMock)
        bookmarkManager.loadBookmarks()

        let dataSource = BookmarkSidebarTreeController(bookmarkManager: bookmarkManager)
        let treeController = BookmarkTreeController(dataSource: dataSource, sortMode: .manual)
        let defaultNodes = treeController.rootNode.childNodes
        XCTAssertEqual(defaultNodes.count, 1)

        let bookmarksNode = defaultNodes[0]
        XCTAssertEqual(bookmarksNode.childNodes.count, 1)

        let childNode = bookmarksNode.childNodes[0]
        XCTAssert(childNode.representedObjectEquals(topLevelFolder))
    }

    @MainActor
    func testWhenBookmarkStoreHasNestedFolders_ThenTheTreeContainsNestedNodes() {
        let childFolder = BookmarkFolder(id: UUID().uuidString, title: "Child")
        let rootFolder = BookmarkFolder(id: UUID().uuidString, title: "Root", children: [childFolder])

        let bookmarkStoreMock = BookmarkStoreMock(bookmarks: [rootFolder])
        let faviconManagerMock = FaviconManagerMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconManagement: faviconManagerMock)
        bookmarkManager.loadBookmarks()

        let dataSource = BookmarkSidebarTreeController(bookmarkManager: bookmarkManager)
        let treeController = BookmarkTreeController(dataSource: dataSource, sortMode: .manual)
        let defaultNodes = treeController.rootNode.childNodes
        XCTAssertEqual(defaultNodes.count, 1)

        let bookmarksNode = defaultNodes[0]
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
