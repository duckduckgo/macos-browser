//
//  BookmarkTests.swift
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
import Bookmarks
@testable import DuckDuckGo_Privacy_Browser

class BookmarkTests: XCTestCase {

    var rootFolder: BookmarkEntity!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()

        let container = CoreData.bookmarkContainer()
        context = container.viewContext

        BookmarkUtils.prepareFoldersStructure(in: context)
        rootFolder = BookmarkUtils.fetchRootFolder(context)
    }

    func testWhenInitializingBaseBookmarkEntityFromBookmarkManagedObject_ThenBookmarkIsCreated() {

        let bookmarkManagedObject = BookmarkEntity.makeBookmark(title: "Bookmark",
                                                                url: "https://example.com/",
                                                                parent: rootFolder,
                                                                context: context)
        guard let bookmark = BaseBookmarkEntity.from(
            managedObject: bookmarkManagedObject,
            favoritesDisplayMode: .displayNative(.desktop)
        ) as? Bookmark else {
            XCTFail("Failed to create Bookmark from managed object")
            return
        }

        XCTAssertEqual(bookmark.title, "Bookmark")
        XCTAssertEqual(bookmark.url, "https://example.com/")
    }

    func testWhenInitializingBaseBookmarkEntityFromBookmarkManagedObject_AndBookmarkIsFolder_ThenFolderIsCreated() {
        let folderManagedObject = BookmarkEntity.makeFolder(title: "Folder", parent: rootFolder, context: context)

        guard let folder = BaseBookmarkEntity.from(
            managedObject: folderManagedObject,
            favoritesDisplayMode: .displayNative(.desktop)
        ) as? BookmarkFolder else {
            XCTFail("Failed to create Folder from managed object")
            return
        }

        XCTAssertEqual(folder.title, "Folder")
    }

    func testWhenInitializingBaseBookmarkEntityWithFolder_AndFolderHasChildren_ThenChildrenArrayIsPopulated() {

        let folderManagedObject = BookmarkEntity.makeFolder(title: "Folder",
                                                            parent: rootFolder,
                                                            context: context)

        let bookmarkManagedObject = BookmarkEntity.makeBookmark(title: "Bookmark",
                                                                url: "https://example.com/",
                                                                parent: folderManagedObject,
                                                                context: context)

        guard let folder = BaseBookmarkEntity.from(
            managedObject: folderManagedObject,
            favoritesDisplayMode: .displayNative(.desktop)
        ) as? BookmarkFolder else {
            XCTFail("Failed to create Folder from managed object")
            return
        }

        XCTAssertEqual(folder.children.count, 1)
        XCTAssertEqual(folder.childFolders.count, 0)
        XCTAssertEqual(folder.childBookmarks.count, 1)
        XCTAssertEqual(folder.children, [
            BaseBookmarkEntity.from(managedObject: bookmarkManagedObject, parentFolderUUID: folder.id, favoritesDisplayMode: .displayNative(.desktop))
        ])
        XCTAssertNil(folder.parentFolderUUID)

        let childBookmark = folder.children.first as? Bookmark
        XCTAssertEqual(childBookmark?.parentFolderUUID, folder.id)
    }

}
