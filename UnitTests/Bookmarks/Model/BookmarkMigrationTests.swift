//
//  BookmarkMigrationTests.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import Bookmarks
import CoreData
import Persistence
import XCTest

@testable import DuckDuckGo_Privacy_Browser

class MockBookmarksDatabase {

    static func tempDBDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    static func make(prepareFolderStructure: Bool = true) -> CoreDataDatabase {
        let db = BookmarkDatabase.make(location: tempDBDir())
        db.loadStore()

        if prepareFolderStructure {
            let context = db.makeContext(concurrencyType: .privateQueueConcurrencyType)
            context.performAndWait {
                do {
                    BookmarkUtils.prepareFoldersStructure(in: context)
                    try context.save()
                } catch {
                    fatalError("Could not setup mock DB")
                }
            }
        }

        return db
    }
}

class BookmarksMigrationTests: XCTestCase {

    var destinationStack: CoreDataDatabase!
    var sourceStack: NSPersistentContainer!

    override func setUp() async throws {
        try await super.setUp()

        destinationStack = MockBookmarksDatabase.make(prepareFolderStructure: false)
        sourceStack = CoreData.legacyBookmarkContainer()
    }

    override func tearDown() async throws {
        try await super.tearDown()

        try destinationStack.tearDown(deleteStores: true)
    }

    private func url(for title: String) -> URL {
        URL(string: "https://\(title).com")!
    }

    func makeBookmark(title: String,
                      url: URL,
                      parent: BookmarkManagedObject?,
                      context: NSManagedObjectContext) -> BookmarkManagedObject {
        let bookmark = BookmarkManagedObject(entity: BookmarkManagedObject.entity(in: context),
                                             insertInto: context)

        bookmark.id = UUID()
        bookmark.urlEncrypted = url as NSURL
        bookmark.titleEncrypted = title as NSObject
        bookmark.isFolder = false
        bookmark.dateAdded = NSDate.now
        bookmark.parentFolder = parent

        return bookmark
    }

    func makeFavorite(title: String,
                      url: URL,
                      parent: BookmarkManagedObject,
                      favoriteRoot: BookmarkManagedObject,
                      context: NSManagedObjectContext) -> BookmarkManagedObject {
        let bookmark = BookmarkManagedObject(entity: BookmarkManagedObject.entity(in: context),
                                             insertInto: context)

        bookmark.id = UUID()
        bookmark.urlEncrypted = url as NSURL
        bookmark.titleEncrypted = title as NSObject
        bookmark.isFolder = false
        bookmark.isFavorite = true
        bookmark.dateAdded = NSDate.now
        bookmark.parentFolder = parent
        bookmark.favoritesFolder = favoriteRoot

        return bookmark
    }

    func makeFolder(title: String,
                    parent: BookmarkManagedObject?,
                    context: NSManagedObjectContext) -> BookmarkManagedObject {
        let bookmark = BookmarkManagedObject(entity: BookmarkManagedObject.entity(in: context),
                                             insertInto: context)

        bookmark.id = UUID()
        bookmark.titleEncrypted = title as NSObject
        bookmark.isFolder = true
        bookmark.dateAdded = NSDate.now
        bookmark.parentFolder = parent

        return bookmark
    }

    // Migrate IDs
    func prepareDB(with context: NSManagedObjectContext) {

        let topLevelBookmarksFolder = makeFolder(title: LegacyBookmarkStore.Constants.rootFolderUUID,
                                                 parent: nil,
                                                 context: context)
        topLevelBookmarksFolder.setValue(UUID(uuidString: LegacyBookmarkStore.Constants.rootFolderUUID), forKey: "id")

        let topLevelFavoritesFolder = makeFolder(title: LegacyBookmarkStore.Constants.rootFolderUUID,
                                                 parent: nil,
                                                 context: context)
        topLevelFavoritesFolder.setValue(UUID(uuidString: LegacyBookmarkStore.Constants.favoritesFolderUUID), forKey: "id")
        topLevelFavoritesFolder.isFavorite = true

        // Bookmarks:
        // One
        // Folder A /
        //   - Folder B/
        //       - Three (F3)
        //   - Two (F2)
        // Four (F1)
        //
        // Favorites: Four -> Two -> Three

        _ = makeBookmark(title: "One", url: url(for: "one"), parent: topLevelBookmarksFolder, context: context)

        let fAId = makeFolder(title: "Folder A", parent: topLevelBookmarksFolder, context: context)
        let fBId = makeFolder(title: "Folder B", parent: fAId, context: context)

        _ = makeFavorite(title: "Four", url: url(for: "four"), parent: topLevelBookmarksFolder, favoriteRoot: topLevelFavoritesFolder, context: context)

        _ = makeFavorite(title: "Two", url: url(for: "two"), parent: fAId, favoriteRoot: topLevelFavoritesFolder, context: context)

        _ = makeFavorite(title: "Three", url: url(for: "three"), parent: fBId, favoriteRoot: topLevelFavoritesFolder, context: context)

        XCTAssert((topLevelBookmarksFolder.children?.count ?? 0) > 0)
    }

    func testWhenNothingToMigrateFromThenNewStackIsInitialized() throws {

        let context = destinationStack.makeContext(concurrencyType: .mainQueueConcurrencyType)
        XCTAssertNil(BookmarkUtils.fetchRootFolder(context))

        LegacyBookmarksStoreMigration.setupAndMigrate(from: sourceStack.viewContext, to: context)

        XCTAssertNotNil(BookmarkUtils.fetchRootFolder(context))
        XCTAssertNotNil(BookmarkUtils.fetchFavoritesFolder(withUUID: FavoritesFolderID.unified.rawValue, in: context))

        // Simulate subsequent app instantiations
        LegacyBookmarksStoreMigration.setupAndMigrate(from: sourceStack.viewContext, to: context)
        LegacyBookmarksStoreMigration.setupAndMigrate(from: sourceStack.viewContext, to: context)

        let countRequest = BookmarkEntity.fetchRequest()
        countRequest.predicate = NSPredicate(value: true)

        let count = try context.count(for: countRequest)
        XCTAssertEqual(count, 2)
    }

    func testWhenRegularMigrationIsNeededThenItIsDone() {

        prepareDB(with: sourceStack.viewContext)

        let context = destinationStack.makeContext(concurrencyType: .mainQueueConcurrencyType)
        LegacyBookmarksStoreMigration.setupAndMigrate(from: sourceStack.viewContext, to: context)

        let favoritesRoot = BookmarkUtils.fetchFavoritesFolder(withUUID: FavoritesFolderID.unified.rawValue, in: context)
        XCTAssertNotNil(BookmarkUtils.fetchRootFolder(context))
        XCTAssertNotNil(favoritesRoot)

        let favorites = (favoritesRoot?.favorites?.array as? [BookmarkEntity]) ?? []

        XCTAssertEqual(favorites[0].title, "Four")
        XCTAssertEqual(favorites[1].title, "Two")
        XCTAssertEqual(favorites[2].title, "Three")

        let topLevel = BookmarkListViewModel(bookmarksDatabase: destinationStack,
                                             parentID: nil,
                                             favoritesDisplayMode: .displayUnified(native: .desktop),
                                             errorEvents: .init(mapping: { event, _, _, _ in
            XCTFail("Unexpected error: \(event)")
        }))

        XCTAssertEqual(topLevel.bookmarks.count, 3)

        let topLevelNames = topLevel.bookmarks.map { $0.title }

        XCTAssertEqual(topLevelNames, ["One", "Folder A", "Four"])

        let bookOne = topLevel.bookmarks[0]
        XCTAssertEqual(bookOne.isFolder, false)
        XCTAssertEqual(bookOne.isFavorite(on: .unified), false)
        XCTAssertEqual(bookOne.title, "One")

        let folderA = topLevel.bookmarks[1]
        XCTAssertEqual(folderA.title, "Folder A")
        XCTAssertTrue(folderA.isFolder)

        let favFour = topLevel.bookmarks[2]
        XCTAssertEqual(favFour.isFolder, false)
        XCTAssertEqual(favFour.isFavorite(on: .unified), true)
        XCTAssertEqual(favFour.title, "Four")
        XCTAssertEqual(favFour.url, url(for: "four").absoluteString)

        let folderAContents = folderA.childrenArray

        XCTAssertEqual(folderAContents[1].isFolder, false)
        XCTAssertEqual(folderAContents[1].isFavorite(on: .unified), true)
        XCTAssertEqual(folderAContents[1].title, "Two")

        let folderB = folderAContents[0]
        XCTAssertEqual(folderB.title, "Folder B")
        XCTAssertTrue(folderB.isFolder)

        let folderBContents = folderB.childrenArray
        XCTAssertEqual(folderBContents.count, 1)
        XCTAssertEqual(folderBContents[0].isFolder, false)
        XCTAssertEqual(folderBContents[0].isFavorite(on: .unified), true)
        XCTAssertEqual(folderBContents[0].title, "Three")
    }

}
