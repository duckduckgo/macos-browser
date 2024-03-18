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

import CoreData
import XCTest

@testable import DuckDuckGo_Privacy_Browser

class BookmarkManagedObjectTests: XCTestCase {

    let container = CoreData.legacyBookmarkContainer()

    func testWhenSavingBookmarksWithValidData_ThenSavingIsSuccessful() {
        let context = container.viewContext
        let parent = createTestRootFolderManagedObject(in: context)

        createTestBookmarkManagedObject(in: context, parent: parent)

        XCTAssertNoThrow(try context.save())
    }

    func testWhenSavingFoldersWithValidData_ThenSavingIsSuccessful() {
        let context = container.viewContext
        let parent = createTestRootFolderManagedObject(in: context)

        createTestFolderManagedObject(in: context, parent: parent)

        XCTAssertNoThrow(try context.save())
    }

    func testWhenSavingWithDuplicateUUID_ThenSavingFails() {
        let context = container.viewContext
        let parent = createTestRootFolderManagedObject(in: context)
        let id = UUID()

        createTestBookmarkManagedObject(with: id, in: context, parent: parent)
        XCTAssertNoThrow(try context.save())

        createTestBookmarkManagedObject(with: id, in: context, parent: parent)
        XCTAssertThrowsError(try context.save())
    }

    func testWhenSavingBookmarkWithoutURL_ThenSavingFails() {
        let context = container.viewContext
        let parent = createTestRootFolderManagedObject(in: context)
        let id = UUID()

        let bookmark = BookmarkManagedObject(entity: BookmarkManagedObject.entity(in: context),
                                             insertInto: context)

        bookmark.id = id
        bookmark.urlEncrypted = nil
        bookmark.titleEncrypted = "Bookmark" as NSObject
        bookmark.isFolder = false
        bookmark.dateAdded = NSDate.now
        bookmark.parentFolder = parent

        XCTAssertThrowsError(try context.save()) { error in
            XCTAssertEqual(error as? BookmarkManagedObject.BookmarkError, BookmarkManagedObject.BookmarkError.bookmarkRequiresURL)
        }
    }

    func testWhenSavingFolder_AndFolderHasURL_ThenSavingFails() {
        let context = container.viewContext
        let parent = createTestRootFolderManagedObject(in: context)
        let id = UUID()

        let folder = BookmarkManagedObject(entity: BookmarkManagedObject.entity(in: context),
                                           insertInto: context)

        folder.id = id
        folder.urlEncrypted = URL(string: "https://example.com")! as NSObject
        folder.titleEncrypted = "Folder" as NSObject
        folder.isFolder = true
        folder.dateAdded = NSDate.now
        folder.parentFolder = parent

        XCTAssertThrowsError(try context.save()) { error in
            XCTAssertEqual(error as? BookmarkManagedObject.BookmarkError, BookmarkManagedObject.BookmarkError.folderHasURL)
        }
    }

    func testWhenSavingFolders_AndTheParentFolderIsTheSameAsTheFolder_ThenSavingFails() {
        let context = container.viewContext
        let id = UUID()

        let folder = BookmarkManagedObject(entity: BookmarkManagedObject.entity(in: context),
                                           insertInto: context)
        folder.id = id
        folder.titleEncrypted = "Folder" as NSObject
        folder.isFolder = true
        folder.dateAdded = NSDate.now
        folder.parentFolder = folder

        XCTAssertThrowsError(try context.save()) { error in
            XCTAssertEqual(error as? BookmarkManagedObject.BookmarkError, BookmarkManagedObject.BookmarkError.folderStructureHasCycle)
        }
    }

    func testWhenSavingFolders_AndFolderContainsAncestorAsChild_ThenSavingFails() {
        let context = container.viewContext
        let parent = createTestRootFolderManagedObject(in: context)

        let topLevelFolder = createTestFolderManagedObject(in: context, parent: parent)
        XCTAssertNoThrow(try context.save())
        XCTAssertEqual(topLevelFolder.children?.count, 0)

        let midLevelFolder = createTestFolderManagedObject(in: context, parent: parent)
        midLevelFolder.parentFolder = topLevelFolder
        XCTAssertNoThrow(try context.save())
        XCTAssertEqual(topLevelFolder.children, [midLevelFolder])

        let bottomLevelFolder = createTestFolderManagedObject(in: context, parent: parent)
        bottomLevelFolder.parentFolder = midLevelFolder
        XCTAssertNoThrow(try context.save())
        XCTAssertEqual(midLevelFolder.children, [bottomLevelFolder])

        bottomLevelFolder.addToChildren(topLevelFolder)
        XCTAssertThrowsError(try context.save())
    }

    func testWhenSavingBookmark_AndBookmarkDoesNotHaveParentFolder_ThenSavingFails() {
        let context = container.viewContext
        let id = UUID()

        let bookmark = BookmarkManagedObject(entity: BookmarkManagedObject.entity(in: context),
                                             insertInto: context)

        bookmark.id = id
        bookmark.urlEncrypted = URL(string: "https://example.com")! as NSObject
        bookmark.titleEncrypted = "Bookmark" as NSObject
        bookmark.isFolder = false
        bookmark.dateAdded = NSDate.now

        XCTAssertThrowsError(try context.save()) { error in
            XCTAssertEqual(error as? BookmarkManagedObject.BookmarkError, BookmarkManagedObject.BookmarkError.mustExistInsideRootFolder)
        }
    }

    func testWhenSavingFolder_AndFolderDoesNotHaveParentFolder_ThenSavingFails() {
        let context = container.viewContext
        let id = UUID()

        let folder = BookmarkManagedObject(entity: BookmarkManagedObject.entity(in: context),
                                           insertInto: context)

        folder.id = id
        folder.titleEncrypted = "Folder" as NSObject
        folder.isFolder = false
        folder.dateAdded = NSDate.now

        XCTAssertThrowsError(try context.save()) { error in
            XCTAssertEqual(error as? BookmarkManagedObject.BookmarkError, BookmarkManagedObject.BookmarkError.mustExistInsideRootFolder)
        }
    }

    func testWhenSavingBookmark_AndBookmarkHasInvalidFavoritesFolder_ThenSavingFails() {
        let context = container.viewContext
        let rootFolder = createTestRootFolderManagedObject(in: context)
        let otherFolder = createTestFolderManagedObject(in: context, parent: rootFolder)
        let id = UUID()

        let bookmark = BookmarkManagedObject(entity: BookmarkManagedObject.entity(in: context),
                                             insertInto: context)

        bookmark.id = id
        bookmark.urlEncrypted = URL(string: "https://example.com")! as NSObject
        bookmark.titleEncrypted = "Bookmark" as NSObject
        bookmark.isFolder = false
        bookmark.dateAdded = NSDate.now

        bookmark.parentFolder = rootFolder
        bookmark.favoritesFolder = otherFolder

        XCTAssertThrowsError(try context.save()) { error in
            XCTAssertEqual(error as? BookmarkManagedObject.BookmarkError, BookmarkManagedObject.BookmarkError.invalidFavoritesFolder)
        }
    }

    @discardableResult
    private func createTestRootFolderManagedObject(in context: NSManagedObjectContext) -> BookmarkManagedObject {
        let folder = BookmarkManagedObject(entity: BookmarkManagedObject.entity(in: context),
                                           insertInto: context)

        folder.id = UUID(uuidString: LegacyBookmarkStore.Constants.rootFolderUUID)
        folder.titleEncrypted = "RootFolder" as NSObject
        folder.isFolder = true
        folder.dateAdded = NSDate.now

        return folder
    }

    @discardableResult
    private func createTestBookmarkManagedObject(with id: UUID = UUID(),
                                                 in context: NSManagedObjectContext,
                                                 parent: BookmarkManagedObject) -> BookmarkManagedObject {
        let bookmark = BookmarkManagedObject(entity: BookmarkManagedObject.entity(in: context),
                                             insertInto: context)

        bookmark.id = id
        bookmark.urlEncrypted = URL(string: "https://example.com")! as NSObject
        bookmark.titleEncrypted = "Bookmark" as NSObject
        bookmark.isFolder = false
        bookmark.dateAdded = NSDate.now
        bookmark.parentFolder = parent

        return bookmark
    }

    @discardableResult
    private func createTestFolderManagedObject(with id: UUID = UUID(),
                                               in context: NSManagedObjectContext,
                                               parent: BookmarkManagedObject) -> BookmarkManagedObject {
        let folder = BookmarkManagedObject(entity: BookmarkManagedObject.entity(in: context),
                                           insertInto: context)

        folder.id = id
        folder.titleEncrypted = "Folder" as NSObject
        folder.isFolder = true
        folder.dateAdded = NSDate.now
        folder.parentFolder = parent

        return folder
    }

}
