//
//  BookmarkManagedObjectTests.swift
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
import CoreData
@testable import DuckDuckGo_Privacy_Browser

class BookmarkManagedObjectTests: XCTestCase {

    func testWhenSavingBookmarksWithValidData_ThenSavingIsSuccessful() {
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext

        createTestBookmarkManagedObject(in: context)

        XCTAssertNoThrow(try context.save())
    }

    func testWhenSavingFoldersWithValidData_ThenSavingIsSuccessful() {
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext

        createTestFolderManagedObject(in: context)

        XCTAssertNoThrow(try context.save())
    }

    func testWhenSavingWithDuplicateUUID_ThenSavingFails() {
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext
        let id = UUID()

        createTestBookmarkManagedObject(with: id, in: context)
        XCTAssertNoThrow(try context.save())

        createTestBookmarkManagedObject(with: id, in: context)
        XCTAssertThrowsError(try context.save())
    }

    func testWhenSavingBookmarkWithoutURL_ThenSavingFails() {
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext
        let id = UUID()

        let bookmark = BookmarkManagedObject(context: context)

        bookmark.id = id
        bookmark.urlEncrypted = nil
        bookmark.titleEncrypted = "Bookmark" as NSObject
        bookmark.isFolder = false
        bookmark.isFavorite = false
        bookmark.dateAdded = NSDate.now

        XCTAssertThrowsError(try context.save()) { error in
            XCTAssertEqual(error as? BookmarkManagedObject.Error, BookmarkManagedObject.Error.bookmarkURLRequirement)
        }
    }

    func testWhenSavingFolder_AndFolderHasURL_ThenSavingFails() {
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext
        let id = UUID()

        let folder = BookmarkManagedObject(context: context)

        folder.id = id
        folder.urlEncrypted = URL(string: "https://example.com")! as NSObject
        folder.titleEncrypted = "Folder" as NSObject
        folder.isFolder = true
        folder.isFavorite = false
        folder.dateAdded = NSDate.now

        XCTAssertThrowsError(try context.save()) { error in
            XCTAssertEqual(error as? BookmarkManagedObject.Error, BookmarkManagedObject.Error.folderBookmarkDistinction)
        }
    }

    func testWhenSavingFolders_AndTheParentFolderIsTheSameAsTheFolder_ThenSavingFails() {
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext
        let id = UUID()

        let folder = BookmarkManagedObject(context: context)
        folder.id = id
        folder.titleEncrypted = "Folder" as NSObject
        folder.isFolder = true
        folder.isFavorite = false
        folder.dateAdded = NSDate.now
        folder.parentFolder = folder

        XCTAssertThrowsError(try context.save()) { error in
            XCTAssertEqual(error as? BookmarkManagedObject.Error, BookmarkManagedObject.Error.folderRecursion)
        }
    }

    func testWhenSavingFolders_AndFolderContainsAncestorAsChild_ThenSavingFails() {
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext

        let topLevelFolder = createTestFolderManagedObject(in: context)
        XCTAssertNoThrow(try context.save())
        XCTAssertEqual(topLevelFolder.children?.count, 0)

        let midLevelFolder = createTestFolderManagedObject(in: context)
        midLevelFolder.parentFolder = topLevelFolder
        XCTAssertNoThrow(try context.save())
        XCTAssertEqual(topLevelFolder.children, [midLevelFolder])

        let bottomLevelFolder = createTestFolderManagedObject(in: context)
        bottomLevelFolder.parentFolder = midLevelFolder
        XCTAssertNoThrow(try context.save())
        XCTAssertEqual(midLevelFolder.children, [bottomLevelFolder])

        bottomLevelFolder.addToChildren(topLevelFolder)
        XCTAssertThrowsError(try context.save())
    }

    @discardableResult
    private func createTestBookmarkManagedObject(with id: UUID = UUID(), in context: NSManagedObjectContext) -> BookmarkManagedObject {
        let bookmark = BookmarkManagedObject(context: context)

        bookmark.id = id
        bookmark.urlEncrypted = URL(string: "https://example.com")! as NSObject
        bookmark.titleEncrypted = "Bookmark" as NSObject
        bookmark.isFolder = false
        bookmark.isFavorite = false
        bookmark.dateAdded = NSDate.now

        return bookmark
    }

    @discardableResult
    private func createTestFolderManagedObject(with id: UUID = UUID(), in context: NSManagedObjectContext) -> BookmarkManagedObject {
        let folder = BookmarkManagedObject(context: context)

        folder.id = id
        folder.titleEncrypted = "Folder" as NSObject
        folder.isFolder = true
        folder.isFavorite = false
        folder.dateAdded = NSDate.now

        return folder
    }

}
