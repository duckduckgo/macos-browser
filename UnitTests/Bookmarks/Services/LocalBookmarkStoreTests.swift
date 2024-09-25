//
//  LocalBookmarkStoreTests.swift
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

import Foundation
import Bookmarks
import XCTest
@testable import DuckDuckGo_Privacy_Browser

extension LocalBookmarkStore {

    convenience init(context: NSManagedObjectContext) {
        self.init {
            context
        }
    }
}

final class LocalBookmarkStoreTests: XCTestCase {

    // MARK: Save/Delete

    let container = CoreData.bookmarkContainer()

    @MainActor
    override func setUp() {
        super.setUp()

        BookmarkUtils.prepareFoldersStructure(in: container.viewContext)
        do {
            try container.viewContext.save()
        } catch {
            XCTFail("Could not prepare Bookmarks Structure")
        }
    }

    @MainActor
    func testWhenBookmarkIsSaved_ThenItMustBeLoadedFromStore() {

        let context = container.viewContext

        let bookmarkStore = LocalBookmarkStore(context: context)

        let savingExpectation = self.expectation(description: "Saving")
        let loadingExpectation = self.expectation(description: "Loading")

        let bookmark = Bookmark(id: UUID().uuidString, url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true, parentFolderUUID: "bookmarks_root")

        bookmarkStore.save(bookmark: bookmark, index: nil) { error in
            XCTAssertNil(error)

            savingExpectation.fulfill()

            bookmarkStore.loadAll(type: .bookmarks) { bookmarks, error in
                XCTAssertNotNil(bookmarks)
                XCTAssertNil(error)
                XCTAssert(bookmarks?.count == 1)
                XCTAssert(bookmarks?.first == bookmark)

                loadingExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 2, handler: nil)
    }

    @MainActor
    func testWhenBookmarkIsRemoved_ThenItShouldntBeLoadedFromStore() {
        let context = container.viewContext

        let bookmarkStore = LocalBookmarkStore(context: context)

        let savingExpectation = self.expectation(description: "Saving")
        let removingExpectation = self.expectation(description: "Removing")
        let loadingExpectation = self.expectation(description: "Loading")

        let bookmark = Bookmark(id: UUID().uuidString, url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true)
        bookmarkStore.save(bookmark: bookmark, index: nil) { error in
            XCTAssertNil(error)

            savingExpectation.fulfill()

            bookmarkStore.remove(objectsWithUUIDs: [bookmark.id]) { error in
                XCTAssertNil(error)

                removingExpectation.fulfill()

                bookmarkStore.loadAll(type: .bookmarks) { bookmarks, error in
                    XCTAssertNotNil(bookmarks)
                    XCTAssertNil(error)
                    XCTAssert(bookmarks?.count == 0)

                    loadingExpectation.fulfill()
                }
            }
        }

        waitForExpectations(timeout: 2, handler: nil)
    }

    @MainActor
    func testWhenBookmarkIsUpdated_ThenTheUpdatedVersionIsLoadedFromTheStore() {
        let context = container.viewContext

        let bookmarkStore = LocalBookmarkStore(context: context)

        let savingExpectation = self.expectation(description: "Saving")
        let loadingExpectation = self.expectation(description: "Loading")

        let bookmark = Bookmark(id: UUID().uuidString, url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true)

        bookmarkStore.save(bookmark: bookmark, index: nil) { error in
            XCTAssertNil(error)

            savingExpectation.fulfill()

            let modifiedBookmark = Bookmark(id: bookmark.id, url: URL.duckDuckGo.absoluteString, title: "New Title", isFavorite: false, parentFolderUUID: "bookmarks_root")
            bookmarkStore.update(bookmark: modifiedBookmark)

            bookmarkStore.loadAll(type: .bookmarks) { bookmarks, error in
                XCTAssertNotNil(bookmarks)
                XCTAssertNil(error)
                XCTAssert(bookmarks?.count == 1)
                XCTAssert(bookmarks?.first == modifiedBookmark)

                loadingExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 2, handler: nil)
    }

    @MainActor
    func testWhenFolderIsAdded_AndItHasNoParentFolder_ThenItMustBeLoadedFromTheStore() {
        let context = container.viewContext

        let bookmarkStore = LocalBookmarkStore(context: context)

        let savingExpectation = self.expectation(description: "Saving")
        let loadingExpectation = self.expectation(description: "Loading")

        let folder = BookmarkFolder(id: UUID().uuidString, title: "Folder", parentFolderUUID: "bookmarks_root")

        bookmarkStore.save(folder: folder) { error in
            XCTAssertNil(error)

            savingExpectation.fulfill()

            bookmarkStore.loadAll(type: .topLevelEntities) { entities, error in
                XCTAssertNotNil(entities)
                XCTAssertNil(error)
                XCTAssert(entities?.count == 1)
                XCTAssert(entities?.first == folder)

                loadingExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 2, handler: nil)
    }

    @MainActor
    func testWhenFolderIsAdded_AndItHasParentFolder_ThenItMustBeLoadedFromTheStore() {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let saveParentExpectation = self.expectation(description: "Save Parent Folder")
        let saveChildExpectation = self.expectation(description: "Save Child Folder")
        let loadingExpectation = self.expectation(description: "Loading")

        let parentId = UUID().uuidString
        let childFolder = BookmarkFolder(id: UUID().uuidString, title: "Child", parentFolderUUID: parentId)
        let parentFolder = BookmarkFolder(id: parentId, title: "Parent", parentFolderUUID: "bookmarks_root", children: [childFolder])

        bookmarkStore.save(folder: parentFolder) { error in
            XCTAssertNil(error)

            saveParentExpectation.fulfill()

            bookmarkStore.save(folder: childFolder) { error in
                XCTAssertNil(error)

                saveChildExpectation.fulfill()

                bookmarkStore.loadAll(type: .topLevelEntities) { entities, error in
                    XCTAssertNotNil(entities)
                    XCTAssertNil(error)
                    XCTAssert(entities?.count == 1)

                    let parentLoadedFromStore = entities?.first as? BookmarkFolder
                    XCTAssertEqual(parentLoadedFromStore, parentFolder)
                    XCTAssert(parentLoadedFromStore?.children.count == 1)
                    XCTAssert(parentLoadedFromStore?.childFolders.count == 1)
                    XCTAssert(parentLoadedFromStore?.childBookmarks.count == 0)
                    XCTAssertEqual(parentLoadedFromStore?.children.first, childFolder)

                    loadingExpectation.fulfill()
                }
            }
        }

        waitForExpectations(timeout: 3, handler: nil)
    }

    @MainActor
    func testWhenBookmarkIsAdded_AndFolderHasBeenProvided_ThenBookmarkIsSavedToParentFolder() {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let saveFolderExpectation = self.expectation(description: "Save Parent Folder")
        let saveBookmarkExpectation = self.expectation(description: "Save Bookmark")
        let loadingExpectation = self.expectation(description: "Loading")

        let parentId = UUID().uuidString
        let bookmark = Bookmark(id: UUID().uuidString, url: "https://example.com", title: "Example", isFavorite: false, parentFolderUUID: parentId)
        let folder = BookmarkFolder(id: parentId, title: "Parent", parentFolderUUID: "bookmarks_root", children: [bookmark])

        bookmarkStore.save(folder: folder) { error in
            XCTAssertNil(error)

            saveFolderExpectation.fulfill()

            bookmarkStore.save(bookmark: bookmark, index: nil) { error in
                XCTAssertNil(error)

                saveBookmarkExpectation.fulfill()

                bookmarkStore.loadAll(type: .topLevelEntities) { entities, error in
                    XCTAssertNotNil(entities)
                    XCTAssertNil(error)
                    XCTAssert(entities?.count == 1)

                    let parentLoadedFromStore = entities?.first as? BookmarkFolder
                    XCTAssertEqual(parentLoadedFromStore, folder)
                    XCTAssert(parentLoadedFromStore?.children.count == 1)
                    XCTAssert(parentLoadedFromStore?.childFolders.count == 0)
                    XCTAssert(parentLoadedFromStore?.childBookmarks.count == 1)
                    XCTAssertEqual(parentLoadedFromStore?.children.first, bookmark)

                    loadingExpectation.fulfill()
                }
            }
        }

        waitForExpectations(timeout: 3, handler: nil)
    }

    @MainActor
    func testWhenSaveMultipleWebsiteInfoToANewFolderInRootFolder_ThenTheNewFolderIsCreated_AndBoomarksAreAddedToTheFolder() async throws {
        // GIVEN
        let context = container.viewContext
        let sut = LocalBookmarkStore(context: context)
        let newFolderName = "Bookmark All Open Tabs"
        let websites = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo, occurrences: 50)
        var bookmarksEntity = try await sut.loadAll(type: .bookmarks)
        var topLevelEntities = try await sut.loadAll(type: .topLevelEntities)
        XCTAssertEqual(bookmarksEntity.count, 0)
        XCTAssertEqual(topLevelEntities.count, 0)

        // WHEN
        sut.saveBookmarks(for: websites, inNewFolderNamed: newFolderName, withinParentFolder: .root)

        // THEN
        bookmarksEntity = try await sut.loadAll(type: .bookmarks)
        topLevelEntities = try await sut.loadAll(type: .topLevelEntities)
        let bookmarks = try XCTUnwrap(bookmarksEntity as? [Bookmark])
        let folders = try XCTUnwrap(topLevelEntities as? [BookmarkFolder])
        let folder = try XCTUnwrap(folders.first)
        XCTAssertEqual(bookmarksEntity.count, 50)
        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(folder.parentFolderUUID, BookmarkEntity.Constants.rootFolderID)
        XCTAssertEqual(folder.title, newFolderName)
        XCTAssertEqual(Set(folder.children), Set(bookmarks))
        bookmarks.forEach { bookmark in
            XCTAssertEqual(bookmark.parentFolderUUID, folder.id)
        }
    }

    @MainActor
    func testWhenSaveMultipleWebsiteInfoToANewFolderInSubfolder_ThenTheNewFolderIsCreated_AndBoomarksAreAddedToTheFolder() async throws {
        // GIVEN
        let context = container.viewContext
        let sut = LocalBookmarkStore(context: context)
        let newFolderName = "Bookmark All Open Tabs"
        let websites = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo, occurrences: 50)
        let parentFolderToInsert = BookmarkFolder(id: "ABCDE", title: "Subfolder")
        _ = try await sut.save(folder: parentFolderToInsert)
        var bookmarksEntity = try await sut.loadAll(type: .bookmarks)
        var topLevelEntities = try await sut.loadAll(type: .topLevelEntities)
        XCTAssertEqual(bookmarksEntity.count, 0)
        XCTAssertEqual(topLevelEntities.count, 1)
        XCTAssertEqual(topLevelEntities.first, parentFolderToInsert)
        XCTAssertEqual((topLevelEntities.first as? BookmarkFolder)?.parentFolderUUID, BookmarkEntity.Constants.rootFolderID)

        // WHEN
        sut.saveBookmarks(for: websites, inNewFolderNamed: newFolderName, withinParentFolder: .parent(uuid: parentFolderToInsert.id))

        // THEN
        bookmarksEntity = try await sut.loadAll(type: .bookmarks)
        topLevelEntities = try await sut.loadAll(type: .topLevelEntities)
        let bookmarks = try XCTUnwrap(bookmarksEntity as? [Bookmark])
        let folders = try XCTUnwrap(topLevelEntities as? [BookmarkFolder])
        let parentFolder = try XCTUnwrap(folders.first)
        let subFolder = try XCTUnwrap(parentFolder.children.first as? BookmarkFolder)
        XCTAssertEqual(bookmarksEntity.count, 50)
        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(parentFolder.title, parentFolderToInsert.title)
        XCTAssertEqual(parentFolder.children.count, 1)
        XCTAssertEqual(subFolder.title, newFolderName)
        XCTAssertEqual(Set(subFolder.children), Set(bookmarks))
        bookmarks.forEach { bookmark in
            XCTAssertEqual(bookmark.parentFolderUUID, subFolder.id)
        }
    }

    @MainActor
    func testWhenSaveMultipleWebsiteInfo_AndTitleIsNotNil_ThenTitleIsUsedAsBookmarkTitle() async throws {
        // GIVEN
        let context = container.viewContext
        let sut = LocalBookmarkStore(context: context)
        let websiteName = "Test Website"
        let websites = WebsiteInfo.makeWebsitesInfo(url: .duckDuckGo, title: websiteName, occurrences: 1)
        var bookmarksEntity = try await sut.loadAll(type: .bookmarks)
        XCTAssertEqual(bookmarksEntity.count, 0)

        // WHEN
        sut.saveBookmarks(for: websites, inNewFolderNamed: "Saved Tabs", withinParentFolder: .root)

        // THEN
        bookmarksEntity = try await sut.loadAll(type: .bookmarks)
        let bookmark = try XCTUnwrap((bookmarksEntity as? [Bookmark])?.first)
        XCTAssertEqual(bookmarksEntity.count, 1)
        XCTAssertEqual(bookmark.title, websiteName)
    }

    @MainActor
    func testWhenSaveMultipleWebsiteInfo_AndTitleIsNil_ThenURLDomainIsUsedAsBookmarkTitle() async throws {
        // GIVEN
        let context = container.viewContext
        let sut = LocalBookmarkStore(context: context)
        let url = URL.duckDuckGo
        let websites = WebsiteInfo.makeWebsitesInfo(url: url, title: nil, occurrences: 1)
        var bookmarksEntity = try await sut.loadAll(type: .bookmarks)
        XCTAssertEqual(bookmarksEntity.count, 0)

        // WHEN
        sut.saveBookmarks(for: websites, inNewFolderNamed: "Saved Tabs", withinParentFolder: .root)

        // THEN
        bookmarksEntity = try await sut.loadAll(type: .bookmarks)
        let bookmark = try XCTUnwrap((bookmarksEntity as? [Bookmark])?.first)
        XCTAssertEqual(bookmarksEntity.count, 1)
        XCTAssertEqual(bookmark.title, url.host)
    }

    @MainActor
    func testWhenSaveMultipleWebsiteInfo_AndTitleIsNil_AndURLDoesNotConformToRFC3986_ThenURLAbsoluteStringIsUsedAsBookmarkTitle() async throws {
        // GIVEN
        let context = container.viewContext
        let sut = LocalBookmarkStore(context: context)
        let url = try XCTUnwrap(URL(string: "duckduckgo.com"))
        let websites = WebsiteInfo.makeWebsitesInfo(url: url, title: nil, occurrences: 1)
        var bookmarksEntity = try await sut.loadAll(type: .bookmarks)
        XCTAssertEqual(bookmarksEntity.count, 0)

        // WHEN
        sut.saveBookmarks(for: websites, inNewFolderNamed: "Saved Tabs", withinParentFolder: .root)

        // THEN
        bookmarksEntity = try await sut.loadAll(type: .bookmarks)
        let bookmark = try XCTUnwrap((bookmarksEntity as? [Bookmark])?.first)
        XCTAssertEqual(bookmarksEntity.count, 1)
        XCTAssertEqual(bookmark.title, url.absoluteString)
    }

    // MARK: Moving Bookmarks/Folders

    @MainActor
    func testWhenMovingBookmarkWithinParentCollection_AndIndexIsValid_ThenBookmarkIsMoved() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let folder = BookmarkFolder(id: UUID().uuidString, title: "Parent")
        let bookmark1 = Bookmark(id: UUID().uuidString, url: "https://example1.com", title: "Example 1", isFavorite: false, parentFolderUUID: folder.id)
        let bookmark2 = Bookmark(id: UUID().uuidString, url: "https://example2.com", title: "Example 2", isFavorite: false, parentFolderUUID: folder.id)
        let bookmark3 = Bookmark(id: UUID().uuidString, url: "https://example3.com", title: "Example 3", isFavorite: false, parentFolderUUID: folder.id)

        // Save the initial bookmarks state:

        _ = try await bookmarkStore.save(folder: folder)
        _ = try await bookmarkStore.save(bookmark: bookmark1, index: nil)
        _ = try await bookmarkStore.save(bookmark: bookmark2, index: nil)
        _ = try await bookmarkStore.save(bookmark: bookmark3, index: nil)

        // Fetch persisted bookmarks back from the store:

        let initialTopLevelEntities = try await bookmarkStore.loadAll(type: .topLevelEntities)
        guard let initialParentFolder = initialTopLevelEntities.first as? BookmarkFolder else {
            XCTFail("Couldn't load top level entities")
            return
        }

        XCTAssertEqual(initialParentFolder.children.count, 3)

        // Verify initial order of saved bookmarks:

        let initialBookmarkUUIDs = [bookmark1.id, bookmark2.id, bookmark3.id]
        let initialFetchedBookmarkUUIDs = initialParentFolder.children.map(\.id)
        XCTAssertEqual(initialBookmarkUUIDs, initialFetchedBookmarkUUIDs)

        // Update the order of the bookmarks:

        let moveBookmarksError = await bookmarkStore.move(objectUUIDs: [bookmark3.id], toIndex: 0, withinParentFolder: .parent(uuid: folder.id))
        XCTAssertNil(moveBookmarksError)

        // Check the new bookmarks order:

        let updatedTopLevelEntities = try await bookmarkStore.loadAll(type: .topLevelEntities)
        guard let updatedParentFolder = updatedTopLevelEntities.first as? BookmarkFolder else {
            XCTFail("Couldn't load top level entities")
            return
        }

        let expectedBookmarkUUIDs = [bookmark3.id, bookmark1.id, bookmark2.id]
        let updatedFetchedBookmarkUUIDs = updatedParentFolder.children.map(\.id)
        XCTAssertEqual(expectedBookmarkUUIDs, updatedFetchedBookmarkUUIDs)
    }

    @MainActor
    func testWhenMovingBookmarkWithinParentCollection_AndThereAreStubs_ThenIndexIsCalculatedAndBookmarkIsMoved() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        guard let rootMO = BookmarkUtils.fetchRootFolder(context) else {
            XCTFail("Missing root folder")
            return
        }

        let folderMO = BookmarkEntity.makeFolder(title: "Parent", parent: rootMO, context: context)

        let bookmarkStub1MO = BookmarkEntity.makeBookmark(title: "Stub 1", url: "", parent: folderMO,
                                                          context: context)
        bookmarkStub1MO.isStub = true

        let bookmark1MO = BookmarkEntity.makeBookmark(title: "Example 1", url: "https://example1.com", parent: folderMO,
                                                      context: context)

        let bookmarkStub2MO = BookmarkEntity.makeBookmark(title: "Stub 2", url: "", parent: folderMO,
                                                          context: context)
        bookmarkStub2MO.isStub = true

        let bookmark2MO = BookmarkEntity.makeBookmark(title: "Example 2", url: "https://example2.com", parent: folderMO,
                                                      context: context)

        let bookmarkStub3MO = BookmarkEntity.makeBookmark(title: "Stub 3", url: "", parent: folderMO,
                                                          context: context)
        bookmarkStub3MO.isStub = true
        let bookmarkStub4MO = BookmarkEntity.makeBookmark(title: "Stub 4", url: "", parent: folderMO,
                                                          context: context)
        bookmarkStub4MO.isStub = true

        let bookmark3MO = BookmarkEntity.makeBookmark(title: "Example 3", url: "https://example3.com", parent: folderMO,
                                                      context: context)

        let bookmarkStub5MO = BookmarkEntity.makeBookmark(title: "Stub 5", url: "", parent: folderMO,
                                                          context: context)
        bookmarkStub5MO.isStub = true

        let bookmark4MO = BookmarkEntity.makeBookmark(title: "Example 4", url: "https://example3.com", parent: folderMO,
                                                      context: context)

        let bookmarkStub6MO = BookmarkEntity.makeBookmark(title: "Stub 6", url: "", parent: folderMO,
                                                          context: context)
        bookmarkStub6MO.isStub = true

        // Save the initial bookmarks state:

        do {
            try context.save()
        } catch {
            XCTFail("Failed to save context")
        }

        // Fetch persisted bookmarks back from the store:

        let initialTopLevelEntities = try await bookmarkStore.loadAll(type: .topLevelEntities)
        guard let initialParentFolder = initialTopLevelEntities.first as? BookmarkFolder else {
            XCTFail("Couldn't load top level entities")
            return
        }

        XCTAssertEqual(initialParentFolder.children.count, 4)

        // Verify initial order of saved bookmarks:

        let initialBookmarkUUIDs = [bookmark1MO.uuid, bookmark2MO.uuid, bookmark3MO.uuid, bookmark4MO.uuid]
        let initialFetchedBookmarkUUIDs = initialParentFolder.children.map(\.id)
        XCTAssertEqual(initialBookmarkUUIDs, initialFetchedBookmarkUUIDs)

        func testMoving(bookmarkUUIDs: [String], toIndex: Int) async throws -> [String] {
            let moveBookmarksError = await bookmarkStore.move(objectUUIDs: bookmarkUUIDs, toIndex: toIndex, withinParentFolder: .parent(uuid: folderMO.uuid!))
            XCTAssertNil(moveBookmarksError)

            let updatedTopLevelEntities = try await bookmarkStore.loadAll(type: .topLevelEntities)
            guard let updatedParentFolder = updatedTopLevelEntities.first as? BookmarkFolder else {
                XCTFail("Couldn't load top level entities")
                return []
            }

            return updatedParentFolder.children.map(\.title)
        }

        // Update the order of the bookmarks:
        // More than one bookmark
        // To the end
        var result = try await testMoving(bookmarkUUIDs: [bookmark1MO.uuid!, bookmark2MO.uuid!], toIndex: 4)
        XCTAssertEqual(result, [bookmark3MO.title, bookmark4MO.title, bookmark1MO.title, bookmark2MO.title])
        // To the beginning
        result = try await testMoving(bookmarkUUIDs: [bookmark1MO.uuid!, bookmark2MO.uuid!], toIndex: 0)
        XCTAssertEqual(result, [bookmark1MO.title, bookmark2MO.title, bookmark3MO.title, bookmark4MO.title])
        // To middle
        result = try await testMoving(bookmarkUUIDs: [bookmark1MO.uuid!, bookmark2MO.uuid!], toIndex: 3)
        XCTAssertEqual(result, [bookmark3MO.title, bookmark1MO.title, bookmark2MO.title, bookmark4MO.title])
        // To the beginning
        result = try await testMoving(bookmarkUUIDs: [bookmark1MO.uuid!, bookmark2MO.uuid!], toIndex: 0)
        XCTAssertEqual(result, [bookmark1MO.title, bookmark2MO.title, bookmark3MO.title, bookmark4MO.title])

        // Single bookmark
        // Middle to end
        result = try await testMoving(bookmarkUUIDs: [bookmark2MO.uuid!], toIndex: 4)
        XCTAssertEqual(result, [bookmark1MO.title, bookmark3MO.title, bookmark4MO.title, bookmark2MO.title])
        // First to Beginning
        result = try await testMoving(bookmarkUUIDs: [bookmark1MO.uuid!], toIndex: 0)
        XCTAssertEqual(result, [bookmark1MO.title, bookmark3MO.title, bookmark4MO.title, bookmark2MO.title])
        // First to First
        result = try await testMoving(bookmarkUUIDs: [bookmark1MO.uuid!], toIndex: 1)
        XCTAssertEqual(result, [bookmark1MO.title, bookmark3MO.title, bookmark4MO.title, bookmark2MO.title])
        // First to Second
        result = try await testMoving(bookmarkUUIDs: [bookmark1MO.uuid!], toIndex: 2)
        XCTAssertEqual(result, [bookmark3MO.title, bookmark1MO.title, bookmark4MO.title, bookmark2MO.title])
        // First to End
        result = try await testMoving(bookmarkUUIDs: [bookmark3MO.uuid!], toIndex: 4)
        XCTAssertEqual(result, [bookmark1MO.title, bookmark4MO.title, bookmark2MO.title, bookmark3MO.title])
    }

    @MainActor
    func testWhenMovingBookmarkWithinParentCollection_AndIndexIsOutOfBounds_ThenBookmarkIsAppended() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let initialParentFolder = BookmarkFolder(id: UUID().uuidString, title: "Parent")
        let bookmark1 = Bookmark(id: UUID().uuidString, url: "https://example1.com", title: "Example 1", isFavorite: false, parentFolderUUID: initialParentFolder.id)
        let bookmark2 = Bookmark(id: UUID().uuidString, url: "https://example2.com", title: "Example 2", isFavorite: false, parentFolderUUID: initialParentFolder.id)
        let bookmark3 = Bookmark(id: UUID().uuidString, url: "https://example3.com", title: "Example 3", isFavorite: false, parentFolderUUID: initialParentFolder.id)

        // Save the initial bookmarks state:

        _ = try await bookmarkStore.save(folder: initialParentFolder)
        _ = try await bookmarkStore.save(bookmark: bookmark1, index: nil)
        _ = try await bookmarkStore.save(bookmark: bookmark2, index: nil)
        _ = try await bookmarkStore.save(bookmark: bookmark3, index: nil)

        // Fetch persisted bookmarks back from the store:

        let initialTopLevelEntities = try await bookmarkStore.loadAll(type: .topLevelEntities)
        guard let initialParentFolder = initialTopLevelEntities.first as? BookmarkFolder else {
            XCTFail("Couldn't load top level entities")
            return
        }

        XCTAssertEqual(initialParentFolder.children.count, 3)

        // Verify initial order of saved bookmarks:

        let initialBookmarkUUIDs = [bookmark1.id, bookmark2.id, bookmark3.id]
        let initialFetchedBookmarkUUIDs = initialParentFolder.children.map(\.id)
        XCTAssertEqual(initialBookmarkUUIDs, initialFetchedBookmarkUUIDs)

        // Update the order of the bookmarks:

        let moveBookmarksError = await bookmarkStore.move(objectUUIDs: [bookmark1.id], toIndex: 999, withinParentFolder: .parent(uuid: initialParentFolder.id))
        XCTAssertNil(moveBookmarksError)

        // Check the new bookmarks order:

        let updatedTopLevelEntities = try await bookmarkStore.loadAll(type: .topLevelEntities)
        guard let updatedParentFolder = updatedTopLevelEntities.first as? BookmarkFolder else {
            XCTFail("Couldn't load top level entities")
            return
        }

        let expectedBookmarkUUIDs = [bookmark2.id, bookmark3.id, bookmark1.id]
        let updatedFetchedBookmarkUUIDs = updatedParentFolder.children.map(\.id)
        XCTAssertEqual(expectedBookmarkUUIDs, updatedFetchedBookmarkUUIDs)
    }

    @MainActor
    func testWhenMovingMultipleBookmarksWithinParentCollection_AndIndexIsValid_ThenBookmarksAreMoved() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let folder = BookmarkFolder(id: UUID().uuidString, title: "Parent")
        let bookmark1 = Bookmark(id: UUID().uuidString, url: "https://example1.com", title: "Example 1", isFavorite: false, parentFolderUUID: folder.id)
        let bookmark2 = Bookmark(id: UUID().uuidString, url: "https://example2.com", title: "Example 2", isFavorite: false, parentFolderUUID: folder.id)
        let bookmark3 = Bookmark(id: UUID().uuidString, url: "https://example3.com", title: "Example 3", isFavorite: false, parentFolderUUID: folder.id)

        // Save the initial bookmarks state:

        _ = try await bookmarkStore.save(folder: folder)
        _ = try await bookmarkStore.save(bookmark: bookmark1, index: nil)
        _ = try await bookmarkStore.save(bookmark: bookmark2, index: nil)
        _ = try await bookmarkStore.save(bookmark: bookmark3, index: nil)

        // Fetch persisted bookmarks back from the store:

        let initialTopLevelEntities = try await bookmarkStore.loadAll(type: .topLevelEntities)
        guard let initialParentFolder = initialTopLevelEntities.first as? BookmarkFolder else {
            XCTFail("Couldn't load top level entities")
            return
        }

        XCTAssertEqual(initialParentFolder.children.count, 3)

        // Verify initial order of saved bookmarks:

        let initialBookmarkUUIDs = [bookmark1.id, bookmark2.id, bookmark3.id]
        let initialFetchedBookmarkUUIDs = initialParentFolder.children.map(\.id)
        XCTAssertEqual(initialBookmarkUUIDs, initialFetchedBookmarkUUIDs)

        // Update the order of the bookmarks:

        let moveBookmarksError = await bookmarkStore.move(objectUUIDs: [bookmark1.id, bookmark2.id], toIndex: 3, withinParentFolder: .parent(uuid: folder.id))
        XCTAssertNil(moveBookmarksError)

        // Check the new bookmarks order:

        let updatedTopLevelEntities = try await bookmarkStore.loadAll(type: .topLevelEntities)
        guard let updatedParentFolder = updatedTopLevelEntities.first as? BookmarkFolder else {
            XCTFail("Couldn't load top level entities")
            return
        }

        let expectedBookmarkUUIDs = [bookmark3.id, bookmark1.id, bookmark2.id]
        let updatedFetchedBookmarkUUIDs = updatedParentFolder.children.map(\.id)
        XCTAssertEqual(expectedBookmarkUUIDs, updatedFetchedBookmarkUUIDs)
    }

    @MainActor
    func testWhenMovingBookmarkToRootFolder_AndIndexIsValid_ThenBookmarkIsMoved() async throws {
        guard let testState = try await createInitialEntityMovementTestState() else {
            XCTFail("Failed to configure test state")
            return
        }

        // Update the order of the bookmarks:

        let moveBookmarksError = await testState.bookmarkStore.move(objectUUIDs: [testState.bookmark3.id], toIndex: 0, withinParentFolder: .root)
        XCTAssertNil(moveBookmarksError)

        // Check the new bookmarks order:

        let updatedTopLevelEntities = try await testState.bookmarkStore.loadAll(type: .topLevelEntities)

        XCTAssertEqual(updatedTopLevelEntities.count, 2)

        let topLevelEntityIDs = updatedTopLevelEntities.map(\.id)
        XCTAssertEqual(topLevelEntityIDs, [testState.bookmark3.id, testState.initialParentFolder.id])

        guard let folder = updatedTopLevelEntities.first(where: { $0.id == testState.initialParentFolder.id }) as? BookmarkFolder else {
            XCTFail("Couldn't find expected folder")
            return
        }

        let expectedBookmarkUUIDs = [testState.bookmark1.id, testState.bookmark2.id]
        let updatedFetchedBookmarkUUIDs = folder.children.map(\.id)
        XCTAssertEqual(expectedBookmarkUUIDs, updatedFetchedBookmarkUUIDs)
    }

    @MainActor
    func testWhenMovingBookmarkToRootFolder_AndIndexIsOutOfBounds_ThenBookmarkIsAppended() async throws {
        guard let testState = try await createInitialEntityMovementTestState() else {
            XCTFail("Failed to configure test state")
            return
        }

        // Update the order of the bookmarks:

        let moveBookmarksError = await testState.bookmarkStore.move(objectUUIDs: [testState.bookmark3.id], toIndex: 999, withinParentFolder: .root)
        XCTAssertNil(moveBookmarksError)

        // Check the new bookmarks order:

        let updatedTopLevelEntities = try await testState.bookmarkStore.loadAll(type: .topLevelEntities)

        XCTAssertEqual(updatedTopLevelEntities.count, 2)

        let topLevelEntityIDs = updatedTopLevelEntities.map(\.id)
        XCTAssertEqual(topLevelEntityIDs, [testState.initialParentFolder.id, testState.bookmark3.id])
    }

    @MainActor
    func testWhenUpdatingBookmarkFolder_ThenBookmarkFolderTitleIsUpdated() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        let folder1 = BookmarkFolder(id: UUID().uuidString, title: "Folder 1", parentFolderUUID: "bookmarks_root")

        // Save the initial bookmarks state:

        _ = try await bookmarkStore.save(folder: folder1)

        // Fetch persisted bookmark folders back from the store:

        let folders = try await bookmarkStore.loadAll(type: .topLevelEntities).compactMap { $0 as? BookmarkFolder }

        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(folders.first, folder1)

        // Update the folder title and parent:

        let folderToMove = folder1
        folderToMove.title = #function
        bookmarkStore.update(folder: folder1)

        // Check the new bookmark folders order:

        let newFolders = try await bookmarkStore.loadAll(type: .topLevelEntities).compactMap { $0 as? BookmarkFolder }

        XCTAssertEqual(newFolders.count, 1)
        XCTAssertEqual(newFolders.first, folderToMove)
    }

    @MainActor
    func testWhenUpdatingAndMovingBookmarkFolder_ThenBookmarkFolderIsMovedAndTitleUpdated() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let folder1 = BookmarkFolder(id: UUID().uuidString, title: "Folder 1", parentFolderUUID: "bookmarks_root")
        let folder2 = BookmarkFolder(id: UUID().uuidString, title: "Folder 2", parentFolderUUID: "bookmarks_root")
        let folder3 = BookmarkFolder(id: UUID().uuidString, title: "Folder 3", parentFolderUUID: "bookmarks_root")

        // Save the initial bookmarks state:

        _ = try await bookmarkStore.save(folder: folder1)
        _ = try await bookmarkStore.save(folder: folder2)
        _ = try await bookmarkStore.save(folder: folder3)

        // Fetch persisted bookmark folders back from the store:

        let folders = try await bookmarkStore.loadAll(type: .topLevelEntities).compactMap { $0 as? BookmarkFolder }

        XCTAssertEqual(folders.count, 3)
        XCTAssertEqual(folders[0], folder1)
        XCTAssertEqual(folders[1], folder2)
        XCTAssertEqual(folders[2], folder3)

        // Update the folder title and parent:

        let folderToMove = folder1
        folderToMove.title = #function
        bookmarkStore.update(folder: folder1, andMoveToParent: .parent(uuid: folder2.id))
        let expectedFolderAfterMove = BookmarkFolder(id: folder1.id, title: folder1.title, parentFolderUUID: folder2.id, children: folder1.children)

        // Check the new bookmark folders order:

        let newFolders = try await bookmarkStore.loadAll(type: .topLevelEntities).compactMap { $0 as? BookmarkFolder }

        XCTAssertEqual(newFolders.count, 2)
        XCTAssertEqual(newFolders[0].id, folder2.id)
        XCTAssertEqual(newFolders[0].children, [expectedFolderAfterMove])
        XCTAssertEqual(newFolders[1], folder3)
    }

    @MainActor
    func testWhenMovingBookmarkFolderToSubfolder_ThenBookmarkFolderLocationIsUpdated() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let folder1 = BookmarkFolder(id: UUID().uuidString, title: "Folder 1", parentFolderUUID: "bookmarks_root")
        let folder2 = BookmarkFolder(id: UUID().uuidString, title: "Folder 2", parentFolderUUID: "bookmarks_root")

        // Save the initial bookmarks state:

        _ = try await bookmarkStore.save(folder: folder1)
        _ = try await bookmarkStore.save(folder: folder2)

        // Fetch persisted bookmark folders back from the store:

        let folders = try await bookmarkStore.loadAll(type: .topLevelEntities).compactMap { $0 as? BookmarkFolder }

        XCTAssertEqual(folders.count, 2)
        XCTAssertEqual(folders.first, folder1)
        XCTAssertEqual(folders.last, folder2)

        // Update the folder parent:

        _ = await bookmarkStore.move(objectUUIDs: [folder2.id], toIndex: nil, withinParentFolder: .parent(uuid: folder1.id))
        let expectedChildFolderAfterMove = BookmarkFolder(id: folder2.id, title: folder2.title, parentFolderUUID: folder1.id, children: folder2.children)
        let expectedParentFolderAfterMove = BookmarkFolder(id: folder1.id, title: folder1.title, parentFolderUUID: folder1.parentFolderUUID, children: [expectedChildFolderAfterMove])

        // Check the new bookmark folders order:

        let newFolders = try await bookmarkStore.loadAll(type: .topLevelEntities).compactMap { $0 as? BookmarkFolder }

        XCTAssertEqual(newFolders.count, 1)
        XCTAssertEqual(newFolders.first, expectedParentFolderAfterMove)
        XCTAssertEqual(newFolders.first?.children, [expectedChildFolderAfterMove])
    }

    @MainActor
    func testWhenMovingBookmarkFolderToRootFolder_ThenBookmarkFolderLocationIsUpdated() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let folder2Id = UUID().uuidString
        let folder1 = BookmarkFolder(id: UUID().uuidString, title: "Folder 1", parentFolderUUID: folder2Id)
        let folder2 = BookmarkFolder(id: folder2Id, title: "Folder 2", parentFolderUUID: "bookmarks_root", children: [folder1])

        // Save the initial bookmarks state:

        _ = try await bookmarkStore.save(folder: folder2)
        _ = try await bookmarkStore.save(folder: folder1)

        // Fetch persisted bookmark folders back from the store:

        let folders = try await bookmarkStore.loadAll(type: .topLevelEntities).compactMap { $0 as? BookmarkFolder }

        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(folders.first, folder2)
        XCTAssertEqual(folders.first?.children, [folder1])

        // Update the folder parent:

        _ = await bookmarkStore.move(objectUUIDs: [folder1.id], toIndex: 0, withinParentFolder: .root)

        // Check the new bookmark folders order:

        let newFolders = try await bookmarkStore.loadAll(type: .topLevelEntities).compactMap { $0 as? BookmarkFolder }
        let expectedFolder1AfterMove = BookmarkFolder(id: folder1.id, title: folder1.title, parentFolderUUID: "bookmarks_root", children: folder1.children)
        let expectedFolder2AfterMove = BookmarkFolder(id: folder2.id, title: folder2.title, parentFolderUUID: "bookmarks_root", children: [])

        XCTAssertEqual(newFolders.count, 2)
        XCTAssertEqual(newFolders.first, expectedFolder1AfterMove)
        XCTAssertEqual(newFolders.last, expectedFolder2AfterMove)
        XCTAssertEqual(newFolders.last?.children, [])
    }

    // MARK: Favorites

    @MainActor
    func testThatTopLevelEntitiesDoNotContainFavoritesFolder() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        // Create and save favorites:

        let bookmark1 = Bookmark(id: UUID().uuidString, url: "https://example1.com", title: "Example 1", isFavorite: true)
        let bookmark2 = Bookmark(id: UUID().uuidString, url: "https://example2.com", title: "Example 2", isFavorite: true)

        _ = try await bookmarkStore.save(bookmark: bookmark1, index: nil)
        _ = try await bookmarkStore.save(bookmark: bookmark2, index: nil)

        // Fetch top level entities:

        let topLevelEntities = try await bookmarkStore.loadAll(type: .topLevelEntities)

        XCTAssertEqual(topLevelEntities.count, 2)
        XCTAssertFalse(topLevelEntities.map(\.id).contains(FavoritesFolderID.unified.rawValue))
    }

    @MainActor
    func testWhenBookmarkIsMarkedAsFavorite_ThenItDoesNotChangeParentFolder() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let folder1 = BookmarkFolder(id: UUID().uuidString, title: "Folder 1")
        let folder2 = BookmarkFolder(id: UUID().uuidString, title: "Folder 2")
        let bookmark = Bookmark(id: UUID().uuidString, url: "https://example1.com", title: "Example", isFavorite: false, parentFolderUUID: folder1.id)

        // Save the initial bookmarks state:

        _ = try await bookmarkStore.save(folder: folder1)
        _ = try await bookmarkStore.save(folder: folder2)
        _ = try await bookmarkStore.save(bookmark: bookmark, index: nil)

        // Fetch persisted bookmarks back from the store:

        let initialTopLevelEntities = try await bookmarkStore.loadAll(type: .topLevelEntities)
        guard initialTopLevelEntities.count == 2,
              let initialFetchedFolder1 = (initialTopLevelEntities[0] as? BookmarkFolder),
              let initialFetchedFolder2 = (initialTopLevelEntities[1] as? BookmarkFolder)
        else {
            XCTFail("Couldn't load top level entities")
            return
        }
        XCTAssertEqual(initialFetchedFolder1.children.map(\.id), [bookmark.id])
        XCTAssertEqual(initialFetchedFolder2.children.count, 0)

        guard let initialBookmark = initialFetchedFolder1.children.first as? Bookmark else {
            XCTFail("Couldn't load saved bookmark")
            return
        }
        XCTAssertFalse(initialBookmark.isFavorite)

        // Mark bookmark as favorite:

        bookmark.isFavorite = true
        bookmarkStore.update(bookmark: bookmark)

        // Fetch updated bookmarks from the store:

        let updatedTopLevelEntities = try await bookmarkStore.loadAll(type: .topLevelEntities)
        guard updatedTopLevelEntities.count == 2,
              let updatedFetchedFolder1 = (updatedTopLevelEntities[0] as? BookmarkFolder),
              let updatedFetchedFolder2 = (updatedTopLevelEntities[1] as? BookmarkFolder)
        else {
            XCTFail("Couldn't load top level entities")
            return
        }
        XCTAssertEqual(updatedFetchedFolder1.children.map(\.id), [bookmark.id])
        XCTAssertEqual(updatedFetchedFolder2.children.count, 0)

        guard let updatedBookmark = updatedFetchedFolder1.children.first as? Bookmark else {
            XCTFail("Couldn't load saved bookmark")
            return
        }
        XCTAssertTrue(updatedBookmark.isFavorite)
    }

    @MainActor
    func testWhenMovingFavorite_AndIndexIsValid_ThenFavoriteIsMoved() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let folder = BookmarkFolder(id: UUID().uuidString, title: "Parent")
        let bookmark1 = Bookmark(id: UUID().uuidString, url: "https://example1.com", title: "Example 1", isFavorite: true)
        let bookmark2 = Bookmark(id: UUID().uuidString, url: "https://example2.com", title: "Example 2", isFavorite: true)
        let bookmark3 = Bookmark(id: UUID().uuidString, url: "https://example3.com", title: "Example 3", isFavorite: true)

        // Save the initial bookmarks state:

        _ = try await bookmarkStore.save(folder: folder)
        _ = try await bookmarkStore.save(bookmark: bookmark1, index: nil)
        _ = try await bookmarkStore.save(bookmark: bookmark2, index: nil)
        _ = try await bookmarkStore.save(bookmark: bookmark3, index: nil)

        // Fetch persisted favorites back from the store:

        let initialFavorites = try await bookmarkStore.loadAll(type: .favorites)

        XCTAssertEqual(initialFavorites.count, 3)

        // Verify initial order of saved favorites:

        let initialBookmarkUUIDs = [bookmark1.id, bookmark2.id, bookmark3.id]
        let initialFetchedBookmarkUUIDs = initialFavorites.map(\.id)
        XCTAssertEqual(initialBookmarkUUIDs, initialFetchedBookmarkUUIDs)

        // Update the order of the favorites:

        let moveFavoritesError = await bookmarkStore.moveFavorites(with: [bookmark3.id], toIndex: 0)
        XCTAssertNil(moveFavoritesError)

        // Check the new favorites order:

        let updatedFavorites = try await bookmarkStore.loadAll(type: .favorites)

        let expectedBookmarkUUIDs = [bookmark3.id, bookmark1.id, bookmark2.id]
        let updatedFetchedBookmarkUUIDs = updatedFavorites.map(\.id)
        XCTAssertEqual(expectedBookmarkUUIDs, updatedFetchedBookmarkUUIDs)
    }

    @MainActor
    func testWhenMovingFavorite_AndThereAreStubs_ThenIndexIsCalculatedAndBookmarkIsMoved() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        bookmarkStore.applyFavoritesDisplayMode(.displayUnified(native: .desktop))

        guard let rootMO = BookmarkUtils.fetchRootFolder(context) else {
            XCTFail("Missing root folder")
            return
        }

        let folderMO = BookmarkEntity.makeFolder(title: "Parent", parent: rootMO, context: context)

        let bookmark1MO = BookmarkEntity.makeBookmark(title: "Example 1", url: "https://example1.com", parent: folderMO,
                                                      context: context)
        let bookmark2MO = BookmarkEntity.makeBookmark(title: "Example 2", url: "https://example2.com", parent: folderMO,
                                                      context: context)
        let bookmarkStub1MO = BookmarkEntity.makeBookmark(title: "Stub 1", url: "", parent: folderMO,
                                                          context: context)
        bookmarkStub1MO.isStub = true
        let bookmarkStub2MO = BookmarkEntity.makeBookmark(title: "Stub 2", url: "", parent: folderMO,
                                                          context: context)
        bookmarkStub2MO.isStub = true
        let bookmark3MO = BookmarkEntity.makeBookmark(title: "Example 3", url: "https://example3.com", parent: folderMO,
                                                      context: context)
        let bookmarkStub3MO = BookmarkEntity.makeBookmark(title: "Stub 3", url: "", parent: folderMO,
                                                          context: context)
        bookmarkStub3MO.isStub = true

        let favoriteRoots = BookmarkUtils.fetchFavoritesFolders(for: .displayUnified(native: .desktop), in: context)
        guard !favoriteRoots.isEmpty else {
            XCTFail("No favorite root")
            return
        }
        bookmark1MO.addToFavorites(folders: favoriteRoots)
        bookmark2MO.addToFavorites(folders: favoriteRoots)
        bookmarkStub1MO.addToFavorites(folders: favoriteRoots)
        bookmarkStub2MO.addToFavorites(folders: favoriteRoots)
        bookmark3MO.addToFavorites(folders: favoriteRoots)
        bookmarkStub3MO.addToFavorites(folders: favoriteRoots)

        // Save the initial state:

        do {
            try context.save()
        } catch {
            XCTFail("Failed to save context")
        }

        // Fetch persisted bookmarks back from the store:

        let favorites = try await bookmarkStore.loadAll(type: .favorites)

        XCTAssertEqual(favorites.count, 3)

        // Verify initial order of saved bookmarks:

        let initialBookmarkUUIDs = [bookmark1MO.uuid, bookmark2MO.uuid, bookmark3MO.uuid]
        let initialFetchedBookmarkUUIDs = favorites.map(\.id)
        XCTAssertEqual(initialBookmarkUUIDs, initialFetchedBookmarkUUIDs)

        func testMoving(bookmarkUUID: String, toIndex: Int) async throws -> [String] {
            let moveBookmarksError = await bookmarkStore.moveFavorites(with: [bookmarkUUID], toIndex: toIndex)
            XCTAssertNil(moveBookmarksError)

            let updatedFavorites = try await bookmarkStore.loadAll(type: .favorites)

            return updatedFavorites.map(\.title)
        }

        // Update the order of the bookmarks:
        // Middle to end
        var result = try await testMoving(bookmarkUUID: bookmark2MO.uuid!, toIndex: 3)
        XCTAssertEqual(result, [bookmark1MO.title, bookmark3MO.title, bookmark2MO.title])
        // First to Beginning
        result = try await testMoving(bookmarkUUID: bookmark1MO.uuid!, toIndex: 0)
        XCTAssertEqual(result, [bookmark1MO.title, bookmark3MO.title, bookmark2MO.title])
        // First to First
        result = try await testMoving(bookmarkUUID: bookmark1MO.uuid!, toIndex: 1)
        XCTAssertEqual(result, [bookmark1MO.title, bookmark3MO.title, bookmark2MO.title])
        // First to Second
        result = try await testMoving(bookmarkUUID: bookmark1MO.uuid!, toIndex: 2)
        XCTAssertEqual(result, [bookmark3MO.title, bookmark1MO.title, bookmark2MO.title])
        // First to End
        result = try await testMoving(bookmarkUUID: bookmark3MO.uuid!, toIndex: 3)
        XCTAssertEqual(result, [bookmark1MO.title, bookmark2MO.title, bookmark3MO.title])
    }

    @MainActor
    func testWhenMovingFavorite_AndIndexIsOutOfBounds_ThenFavoriteIsAppended() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let initialParentFolder = BookmarkFolder(id: UUID().uuidString, title: "Parent")
        let bookmark1 = Bookmark(id: UUID().uuidString, url: "https://example1.com", title: "Example 1", isFavorite: true)
        let bookmark2 = Bookmark(id: UUID().uuidString, url: "https://example2.com", title: "Example 2", isFavorite: true)
        let bookmark3 = Bookmark(id: UUID().uuidString, url: "https://example3.com", title: "Example 3", isFavorite: true)

        // Save the initial bookmarks state:

        _ = try await bookmarkStore.save(folder: initialParentFolder)
        _ = try await bookmarkStore.save(bookmark: bookmark1, index: nil)
        _ = try await bookmarkStore.save(bookmark: bookmark2, index: nil)
        _ = try await bookmarkStore.save(bookmark: bookmark3, index: nil)

        // Fetch persisted favorites back from the store:

        let initialFavorites = try await bookmarkStore.loadAll(type: .favorites)

        XCTAssertEqual(initialFavorites.count, 3)

        // Verify initial order of saved favorites:

        let initialBookmarkUUIDs = [bookmark1.id, bookmark2.id, bookmark3.id]
        let initialFetchedBookmarkUUIDs = initialFavorites.map(\.id)
        XCTAssertEqual(initialBookmarkUUIDs, initialFetchedBookmarkUUIDs)

        // Update the order of the favorites:

        let moveFavoritesError = await bookmarkStore.moveFavorites(with: [bookmark1.id], toIndex: 999)
        XCTAssertNil(moveFavoritesError)

        // Check the new favorites order:

        let updatedFavorites = try await bookmarkStore.loadAll(type: .favorites)

        let expectedBookmarkUUIDs = [bookmark2.id, bookmark3.id, bookmark1.id]
        let updatedFetchedBookmarkUUIDs = updatedFavorites.map(\.id)
        XCTAssertEqual(expectedBookmarkUUIDs, updatedFetchedBookmarkUUIDs)
    }

    @MainActor
    func testWhenMovingMultipleFavorites_AndIndexIsValid_ThenFavoritesAreMoved() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let folder = BookmarkFolder(id: UUID().uuidString, title: "Parent")
        let bookmark1 = Bookmark(id: UUID().uuidString, url: "https://example1.com", title: "Example 1", isFavorite: true)
        let bookmark2 = Bookmark(id: UUID().uuidString, url: "https://example2.com", title: "Example 2", isFavorite: true)
        let bookmark3 = Bookmark(id: UUID().uuidString, url: "https://example3.com", title: "Example 3", isFavorite: true)

        // Save the initial bookmarks state:

        _ = try await bookmarkStore.save(folder: folder)
        _ = try await bookmarkStore.save(bookmark: bookmark1, index: nil)
        _ = try await bookmarkStore.save(bookmark: bookmark2, index: nil)
        _ = try await bookmarkStore.save(bookmark: bookmark3, index: nil)

        // Fetch persisted favorites back from the store:

        let initialFavorites = try await bookmarkStore.loadAll(type: .favorites)

        XCTAssertEqual(initialFavorites.count, 3)

        // Verify initial order of saved favorites:

        let initialBookmarkUUIDs = [bookmark1.id, bookmark2.id, bookmark3.id]
        let initialFetchedBookmarkUUIDs = initialFavorites.map(\.id)
        XCTAssertEqual(initialBookmarkUUIDs, initialFetchedBookmarkUUIDs)

        // Update the order of the favorites:

        let moveFavoritesError = await bookmarkStore.moveFavorites(with: [bookmark1.id, bookmark2.id], toIndex: 3)
        XCTAssertNil(moveFavoritesError)

        // Check the new favorites order:

        let updatedFavorites = try await bookmarkStore.loadAll(type: .favorites)

        let expectedBookmarkUUIDs = [bookmark3.id, bookmark1.id, bookmark2.id]
        let updatedFetchedBookmarkUUIDs = updatedFavorites.map(\.id)
        XCTAssertEqual(expectedBookmarkUUIDs, updatedFetchedBookmarkUUIDs)
    }

    private struct EntityMovementTestState {
        let bookmarkStore: LocalBookmarkStore
        let bookmark1: Bookmark
        let bookmark2: Bookmark
        let bookmark3: Bookmark
        let initialParentFolder: BookmarkFolder
    }

    @MainActor
    private func createInitialEntityMovementTestState() async throws -> EntityMovementTestState? {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let initialParentFolder = BookmarkFolder(id: UUID().uuidString, title: "Parent")
        let bookmark1 = Bookmark(id: UUID().uuidString, url: "https://example1.com", title: "Example 1", isFavorite: false, parentFolderUUID: initialParentFolder.id)
        let bookmark2 = Bookmark(id: UUID().uuidString, url: "https://example2.com", title: "Example 2", isFavorite: false, parentFolderUUID: initialParentFolder.id)
        let bookmark3 = Bookmark(id: UUID().uuidString, url: "https://example3.com", title: "Example 3", isFavorite: false, parentFolderUUID: initialParentFolder.id)

        // Save the initial bookmarks state:

        _ = try await bookmarkStore.save(folder: initialParentFolder)
        _ = try await bookmarkStore.save(bookmark: bookmark1, index: nil)
        _ = try await bookmarkStore.save(bookmark: bookmark2, index: nil)
        _ = try await bookmarkStore.save(bookmark: bookmark3, index: nil)

        // Fetch persisted bookmarks back from the store:

        let initialTopLevelEntities = try await bookmarkStore.loadAll(type: .topLevelEntities)
        guard let initialParentFolder = initialTopLevelEntities.first as? BookmarkFolder else {
            XCTFail("Couldn't load top level entities")
            return nil
        }

        XCTAssertEqual(initialParentFolder.children.count, 3)

        // Verify initial order of saved bookmarks:

        let initialBookmarkUUIDs = [bookmark1.id, bookmark2.id, bookmark3.id]
        let initialFetchedBookmarkUUIDs = initialParentFolder.children.map(\.id)
        XCTAssertEqual(initialBookmarkUUIDs, initialFetchedBookmarkUUIDs)

        return EntityMovementTestState(bookmarkStore: bookmarkStore,
                                       bookmark1: bookmark1,
                                       bookmark2: bookmark2,
                                       bookmark3: bookmark3,
                                       initialParentFolder: initialParentFolder)
    }

    // MARK: Favorites Display Mode

    func testDisplayNativeMode_WhenBookmarkIsFavorited_ThenItIsAddedToNativeAndUnifiedFolders() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        bookmarkStore.applyFavoritesDisplayMode(.displayNative(.desktop))

        let bookmark = Bookmark(id: UUID().uuidString, url: "https://example1.com", title: "Example", isFavorite: true)
        _ = try await bookmarkStore.save(bookmark: bookmark, index: nil)

        context.performAndWait {
            let rootFolder = BookmarkUtils.fetchRootFolder(context)!
            let bookmarkMO = rootFolder.childrenArray.first!
            XCTAssertEqual(Set(bookmarkMO.favoritedOn), Set([.desktop, .unified]))
        }
    }

    func testDisplayNativeMode_WhenNonNativeFavoriteIsFavoritedThenItIsAddedToNativeFolder() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        bookmarkStore.applyFavoritesDisplayMode(.displayNative(.desktop))

        context.performAndWait {
            let rootFolder = BookmarkUtils.fetchRootFolder(context)!
            var bookmarkMO = BookmarkEntity.makeBookmark(title: "Example", url: "https://example1.com", parent: rootFolder, context: context)
            bookmarkMO.addToFavorites(with: .displayNative(.mobile), in: context)
            try! context.save()

            let bookmark = Bookmark.from(managedObject: bookmarkMO, favoritesDisplayMode: bookmarkStore.favoritesDisplayMode) as! Bookmark

            bookmark.isFavorite = true
            bookmarkStore.update(bookmark: bookmark)

            bookmarkMO = rootFolder.childrenArray.first!
            XCTAssertEqual(Set(bookmarkMO.favoritedOn), Set(FavoritesFolderID.allCases))
        }
    }

    func testDisplayNativeMode_WhenNonNativeBrokenFavoriteIsFavoritedThenItIsAddedToNativeAndUnifiedFolder() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        bookmarkStore.applyFavoritesDisplayMode(.displayNative(.desktop))

        context.performAndWait {
            let rootFolder = BookmarkUtils.fetchRootFolder(context)!
            var bookmarkMO = BookmarkEntity.makeBookmark(title: "Example", url: "https://example1.com", parent: rootFolder, context: context)
            let nonNativeFolder = BookmarkUtils.fetchFavoritesFolder(withUUID: FavoritesFolderID.mobile.rawValue, in: context)!
            bookmarkMO.addToFavorites(folders: [nonNativeFolder])
            try! context.save()

            let bookmark = Bookmark.from(managedObject: bookmarkMO, favoritesDisplayMode: bookmarkStore.favoritesDisplayMode) as! Bookmark

            bookmark.isFavorite = true
            bookmarkStore.update(bookmark: bookmark)

            bookmarkMO = rootFolder.childrenArray.first!
            XCTAssertEqual(Set(bookmarkMO.favoritedOn), Set(FavoritesFolderID.allCases))
        }
    }

    func testDisplayNativeMode_WhenFavoriteIsUnfavoritedThenItIsRemovedFromNativeAndUnifiedFolder() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        bookmarkStore.applyFavoritesDisplayMode(.displayNative(.desktop))

        context.performAndWait {
            let rootFolder = BookmarkUtils.fetchRootFolder(context)!
            var bookmarkMO = BookmarkEntity.makeBookmark(title: "Example", url: "https://example1.com", parent: rootFolder, context: context)
            bookmarkMO.addToFavorites(with: bookmarkStore.favoritesDisplayMode, in: context)
            try! context.save()

            let bookmark = Bookmark.from(managedObject: bookmarkMO, favoritesDisplayMode: bookmarkStore.favoritesDisplayMode) as! Bookmark

            bookmark.isFavorite = false
            bookmarkStore.update(bookmark: bookmark)

            bookmarkMO = rootFolder.childrenArray.first!
            XCTAssertTrue(bookmarkMO.favoritedOn.isEmpty)
        }
    }

    func testDisplayNativeMode_WhenAllFormFactorsFavoriteIsUnfavoritedThenItIsOnlyRemovedFromNativeFolder() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        bookmarkStore.applyFavoritesDisplayMode(.displayNative(.desktop))

        context.performAndWait {
            let rootFolder = BookmarkUtils.fetchRootFolder(context)!
            var bookmarkMO = BookmarkEntity.makeBookmark(title: "Example", url: "https://example1.com", parent: rootFolder, context: context)
            bookmarkMO.addToFavorites(with: bookmarkStore.favoritesDisplayMode, in: context)
            let nonNativeFolder = BookmarkUtils.fetchFavoritesFolder(withUUID: FavoritesFolderID.mobile.rawValue, in: context)!
            bookmarkMO.addToFavorites(folders: [nonNativeFolder])
            try! context.save()

            let bookmark = Bookmark.from(managedObject: bookmarkMO, favoritesDisplayMode: bookmarkStore.favoritesDisplayMode) as! Bookmark

            bookmark.isFavorite = false
            bookmarkStore.update(bookmark: bookmark)

            bookmarkMO = rootFolder.childrenArray.first!
            XCTAssertEqual(Set(bookmarkMO.favoritedOn), Set([.mobile, .unified]))
        }
    }

    func testDisplayUnifiedMode_WhenBookmarkIsFavoritedThenItIsAddedToNativeAndUnifiedFolders() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        bookmarkStore.applyFavoritesDisplayMode(.displayUnified(native: .desktop))

        let bookmark = Bookmark(id: UUID().uuidString, url: "https://example1.com", title: "Example", isFavorite: true)
        _ = try await bookmarkStore.save(bookmark: bookmark, index: nil)

        context.performAndWait {
            let rootFolder = BookmarkUtils.fetchRootFolder(context)!
            let bookmarkMO = rootFolder.childrenArray.first!
            XCTAssertEqual(Set(bookmarkMO.favoritedOn), Set([.desktop, .unified]))
        }
    }

    func testDisplayUnifiedMode_WhenNonNativeFavoriteIsUnfavoritedThenItIsRemovedFromAllFolders() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        bookmarkStore.applyFavoritesDisplayMode(.displayUnified(native: .desktop))

        context.performAndWait {
            let rootFolder = BookmarkUtils.fetchRootFolder(context)!
            var bookmarkMO = BookmarkEntity.makeBookmark(title: "Example", url: "https://example1.com", parent: rootFolder, context: context)
            bookmarkMO.addToFavorites(with: .displayNative(.mobile), in: context)
            try! context.save()

            let bookmark = Bookmark.from(managedObject: bookmarkMO, favoritesDisplayMode: bookmarkStore.favoritesDisplayMode) as! Bookmark

            bookmark.isFavorite = true
            bookmarkStore.update(bookmark: bookmark)

            bookmarkMO = rootFolder.childrenArray.first!
            XCTAssertEqual(Set(bookmarkMO.favoritedOn), Set(FavoritesFolderID.allCases))
        }
    }

    func testDisplayUnifiedMode_WhenNonNativeBrokenFavoriteIsFavoritedThenItIsAddedToNativeAndUnifiedFolder() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        bookmarkStore.applyFavoritesDisplayMode(.displayUnified(native: .desktop))

        context.performAndWait {
            let rootFolder = BookmarkUtils.fetchRootFolder(context)!
            var bookmarkMO = BookmarkEntity.makeBookmark(title: "Example", url: "https://example1.com", parent: rootFolder, context: context)
            let nonNativeFolder = BookmarkUtils.fetchFavoritesFolder(withUUID: FavoritesFolderID.mobile.rawValue, in: context)!
            bookmarkMO.addToFavorites(folders: [nonNativeFolder])
            try! context.save()

            let bookmark = Bookmark.from(managedObject: bookmarkMO, favoritesDisplayMode: bookmarkStore.favoritesDisplayMode) as! Bookmark

            bookmark.isFavorite = true
            bookmarkStore.update(bookmark: bookmark)

            bookmarkMO = rootFolder.childrenArray.first!
            XCTAssertEqual(Set(bookmarkMO.favoritedOn), Set(FavoritesFolderID.allCases))
        }
    }

    func testDisplayUnifiedMode_WhenAllFormFactorsFavoriteIsUnfavoritedThenItIsRemovedFromAllFolders() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        bookmarkStore.applyFavoritesDisplayMode(.displayUnified(native: .desktop))

        context.performAndWait {
            let rootFolder = BookmarkUtils.fetchRootFolder(context)!
            var bookmarkMO = BookmarkEntity.makeBookmark(title: "Example", url: "https://example1.com", parent: rootFolder, context: context)
            bookmarkMO.addToFavorites(with: bookmarkStore.favoritesDisplayMode, in: context)
            let nonNativeFolder = BookmarkUtils.fetchFavoritesFolder(withUUID: FavoritesFolderID.mobile.rawValue, in: context)!
            bookmarkMO.addToFavorites(folders: [nonNativeFolder])
            try! context.save()

            let bookmark = Bookmark.from(managedObject: bookmarkMO, favoritesDisplayMode: bookmarkStore.favoritesDisplayMode) as! Bookmark

            bookmark.isFavorite = false
            bookmarkStore.update(bookmark: bookmark)

            bookmarkMO = rootFolder.childrenArray.first!
            XCTAssertTrue(bookmarkMO.favoritedOn.isEmpty)
        }
    }

    // MARK: - Retrieve Bookmark Folder

    @MainActor
    func testWhenFetchingBookmarkFolderWithId_AndFolderExist_ThenFolderIsReturned() async throws {
        // GIVEN
        let context = container.viewContext
        let sut = LocalBookmarkStore(context: context)
        let folderId = "ABCDE"
        let folder = BookmarkFolder(id: folderId, title: "Test")
        _ = try await sut.save(folder: folder)

        // WHEN
        let result = sut.bookmarkFolder(withId: folderId)

        // THEN
        XCTAssertEqual(result, folder)
    }

    @MainActor
    func testWhenFetchingBookmarkFolderWithId_AndFolderDoesNotExist_ThenNilIsReturned() {
        // GIVEN
        let context = container.viewContext
        let sut = LocalBookmarkStore(context: context)
        let folderId = "ABCDE"

        // WHEN
        let result = sut.bookmarkFolder(withId: folderId)

        // THEN
        XCTAssertNil(result)
    }

    @MainActor
    func testWhenFetchingBookmarkFolderWithId_AndFolderHasBeenMoved_ThenFolderIsStillReturned() async throws {
        // GIVEN
        let context = container.viewContext
        let sut = LocalBookmarkStore(context: context)
        let folderId = "ABCDE"
        let folder1 = BookmarkFolder(id: UUID().uuidString, title: "Test")
        let folder2 = BookmarkFolder(id: folderId, title: "Test")
        let expectedFolder = BookmarkFolder(id: folderId, title: "Test", parentFolderUUID: folder1.id)
        _ = try await sut.save(folder: folder1)
        _ = try await sut.save(folder: folder2)

        // WHEN
        let firstFetchResult = sut.bookmarkFolder(withId: folderId)

        // THEN
        XCTAssertEqual(firstFetchResult, folder2)

        // Move folder
        _ = await sut.move(objectUUIDs: [folder2.id], toIndex: nil, withinParentFolder: .parent(uuid: folder1.id))

        // WHEN
        let secondFetchResult = sut.bookmarkFolder(withId: folderId)

        // THEN
        XCTAssertEqual(secondFetchResult, expectedFolder)
    }

    // MARK: Import

    @MainActor
    func testWhenBookmarksAreImported_AndNoDuplicatesExist_ThenBookmarksAreImported() {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let bookmark = ImportedBookmarks.BookmarkOrFolder(name: "DuckDuckGo", type: .bookmark, urlString: "https://duckduckgo.com", children: nil)
        let bookmarkBar = ImportedBookmarks.BookmarkOrFolder(name: "Bookmark Bar", type: .folder, urlString: nil, children: [bookmark])
        let otherBookmarks = ImportedBookmarks.BookmarkOrFolder(name: "Other Bookmarks", type: .folder, urlString: nil, children: [])

        let topLevelFolders = ImportedBookmarks.TopLevelFolders(bookmarkBar: bookmarkBar, otherBookmarks: otherBookmarks, syncedBookmarks: nil)
        let importedBookmarks = ImportedBookmarks(topLevelFolders: topLevelFolders)

        let result = bookmarkStore.importBookmarks(importedBookmarks, source: .thirdPartyBrowser(.safari))

        XCTAssertEqual(result.successful, 1)
        XCTAssertEqual(result.duplicates, 0)
        XCTAssertEqual(result.failed, 0)

        let loadingExpectation = self.expectation(description: "Loading")

        bookmarkStore.loadAll(type: .bookmarks) { bookmarks, error in
            XCTAssertNotNil(bookmarks)
            XCTAssertNil(error)
            XCTAssert(bookmarks?.count == 1)

            loadingExpectation.fulfill()
        }

        waitForExpectations(timeout: 3, handler: nil)
    }

    @MainActor
    func testWhenBookmarksAreImported_AndDuplicatesExist_ThenBookmarksAreStillImported() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        let importedBookmarks = createMockImportedBookmarks()

        // Import bookmarks once, and then again to test duplicates
        _ = bookmarkStore.importBookmarks(importedBookmarks, source: .thirdPartyBrowser(.safari))
        let result = bookmarkStore.importBookmarks(importedBookmarks, source: .thirdPartyBrowser(.safari))

        XCTAssertEqual(result.successful, 2)
        XCTAssertEqual(result.duplicates, 0)
        XCTAssertEqual(result.failed, 0)

        let bookmarks = try await bookmarkStore.loadAll(type: .bookmarks)
        XCTAssertEqual(bookmarks.count, 4)
    }

    func testWhenSafariBookmarksAreImported_AndTheBookmarksStoreIsEmpty_ThenBookmarksAreImportedToTheRootFolder_AndRootBookmarksAreFavorited() async throws {
        try await validateInitialImport(for: .thirdPartyBrowser(.safari))
    }

    func testWhenChromeBookmarksAreImported_AndTheBookmarksStoreIsEmpty_ThenBookmarksAreImportedToTheRootFolder_AndRootBookmarksAreFavorited() async throws {
        try await validateInitialImport(for: .thirdPartyBrowser(.chrome))
    }

    func testWhenFirefoxBookmarksAreImported_AndTheBookmarksStoreIsEmpty_ThenBookmarksAreImportedToTheRootFolder_AndRootBookmarksAreFavorited() async throws {
        try await validateInitialImport(for: .thirdPartyBrowser(.firefox))
    }

    func testWhenSafariBookmarksAreImported_AndTheBookmarksStoreIsNotEmpty_ThenBookmarksAreImportedToTheirOwnFolder_AndNoBookmarksAreFavorited() async throws {
        try await validateSubsequentImport(for: .thirdPartyBrowser(.safari))
    }

    func testWhenChromeBookmarksAreImported_AndTheBookmarksStoreIsNotEmpty_ThenBookmarksAreImportedToTheirOwnFolder_AndNoBookmarksAreFavorited() async throws {
        try await validateSubsequentImport(for: .thirdPartyBrowser(.chrome))
    }

    func testWhenFirefoxBookmarksAreImported_AndTheBookmarksStoreIsNotEmpty_ThenBookmarksAreImportedToTheirOwnFolder_AndNoBookmarksAreFavorited() async throws {
        try await validateSubsequentImport(for: .thirdPartyBrowser(.firefox))
    }

    func testWhenHTMLBookmarksAreImported_AndTheBookmarksStoreIsNotEmpty_ThenBookmarksAreImportedToTheirOwnFolder_AndNoBookmarksAreFavorited() async throws {
        try await validateSubsequentImport(for: .thirdPartyBrowser(.bookmarksHTML))
    }

    func testWhenDDGHTMLBookmarksAreImported_AndTheBookmarksStoreIsNotEmpty_ThenBookmarksAreImportedToTheirOwnFolder_AndNoBookmarksAreFavorited() async throws {
        try await validateSubsequentImport(for: .duckduckgoWebKit)
    }

    @MainActor
    private func validateInitialImport(for source: BookmarkImportSource) async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        let importedBookmarks = createMockImportedBookmarks()

        let result = bookmarkStore.importBookmarks(importedBookmarks, source: source)

        XCTAssertEqual(result.successful, 2)
        XCTAssertEqual(result.duplicates, 0)
        XCTAssertEqual(result.failed, 0)

        let entities = try await bookmarkStore.loadAll(type: .topLevelEntities)
        let bookmarks = try await bookmarkStore.loadAll(type: .bookmarks)

        XCTAssert(entities.contains(where: { $0.title == "DuckDuckGo" }))
        XCTAssert(entities.contains(where: { $0.title == "Folder" }))

        var totalFavorites = 0

        for bookmarkEntity in bookmarks {
            if let bookmark = bookmarkEntity as? Bookmark, bookmark.isFavorite {
                totalFavorites += 1
            }
        }

        XCTAssertEqual(totalFavorites, 1)
    }

    @MainActor
    private func validateSubsequentImport(for source: BookmarkImportSource) async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        let importedBookmarks = createMockImportedBookmarks()

        // Import bookmarks twice, one to initially populate the store and again to create the "Imported from [Browser]" folder.
        _ = bookmarkStore.importBookmarks(importedBookmarks, source: source)
        _ = bookmarkStore.importBookmarks(importedBookmarks, source: source)

        let entities = try await bookmarkStore.loadAll(type: .topLevelEntities)
        let bookmarks = try await bookmarkStore.loadAll(type: .bookmarks)

        XCTAssert(entities.contains(where: { $0.title == "DuckDuckGo" }))
        XCTAssert(entities.contains(where: { $0.title == "Folder" }))
        XCTAssert(entities.contains(where: { $0.title.contains(source.importSourceName) }))

        var totalFavorites = 0

        for bookmarkEntity in bookmarks {
            if let bookmark = bookmarkEntity as? Bookmark, bookmark.isFavorite {
                totalFavorites += 1
            }
        }

        XCTAssertEqual(totalFavorites, 1)
    }

    private func createMockImportedBookmarks() -> ImportedBookmarks {
        let bookmark1 = ImportedBookmarks.BookmarkOrFolder(name: "DuckDuckGo", type: .bookmark, urlString: "https://duckduckgo.com", children: nil)
        let bookmark2 = ImportedBookmarks.BookmarkOrFolder(name: "Duck", type: .bookmark, urlString: "https://duck.com", children: nil)
        let folder1 = ImportedBookmarks.BookmarkOrFolder(name: "Folder", type: .folder, urlString: nil, children: [bookmark2])

        let bookmarkBar = ImportedBookmarks.BookmarkOrFolder(name: "Bookmark Bar", type: .folder, urlString: nil, children: [bookmark1, folder1])
        let otherBookmarks = ImportedBookmarks.BookmarkOrFolder(name: "Other Bookmarks", type: .folder, urlString: nil, children: [])

        let topLevelFolders = ImportedBookmarks.TopLevelFolders(bookmarkBar: bookmarkBar, otherBookmarks: otherBookmarks, syncedBookmarks: nil)

        return ImportedBookmarks(topLevelFolders: topLevelFolders)
    }

}
