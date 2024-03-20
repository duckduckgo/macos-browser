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

    override func setUp() {
        super.setUp()

        BookmarkUtils.prepareFoldersStructure(in: container.viewContext)
        do {
            try container.viewContext.save()
        } catch {
            XCTFail("Could not prepare Bookmarks Structure")
        }
    }

    func testWhenBookmarkIsSaved_ThenItMustBeLoadedFromStore() {

        let context = container.viewContext

        let bookmarkStore = LocalBookmarkStore(context: context)

        let savingExpectation = self.expectation(description: "Saving")
        let loadingExpectation = self.expectation(description: "Loading")

        let bookmark = Bookmark(id: UUID().uuidString, url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true, parentFolderUUID: "bookmarks_root")

        bookmarkStore.save(bookmark: bookmark, parent: nil, index: nil) { (success, error) in
            XCTAssert(success)
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

    func testWhenBookmarkIsRemoved_ThenItShouldntBeLoadedFromStore() {
        let context = container.viewContext

        let bookmarkStore = LocalBookmarkStore(context: context)

        let savingExpectation = self.expectation(description: "Saving")
        let removingExpectation = self.expectation(description: "Removing")
        let loadingExpectation = self.expectation(description: "Loading")

        let bookmark = Bookmark(id: UUID().uuidString, url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true)
        bookmarkStore.save(bookmark: bookmark, parent: nil, index: nil) { (success, error) in
            XCTAssert(success)
            XCTAssertNil(error)

            savingExpectation.fulfill()

            bookmarkStore.remove(objectsWithUUIDs: [bookmark.id]) { (success, error) in
                XCTAssert(success)
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

    func testWhenBookmarkIsUpdated_ThenTheUpdatedVersionIsLoadedFromTheStore() {
        let context = container.viewContext

        let bookmarkStore = LocalBookmarkStore(context: context)

        let savingExpectation = self.expectation(description: "Saving")
        let loadingExpectation = self.expectation(description: "Loading")

        let bookmark = Bookmark(id: UUID().uuidString, url: URL.duckDuckGo.absoluteString, title: "DuckDuckGo", isFavorite: true)

        bookmarkStore.save(bookmark: bookmark, parent: nil, index: nil) { (success, error) in
            XCTAssert(success)
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

    func testWhenFolderIsAdded_AndItHasNoParentFolder_ThenItMustBeLoadedFromTheStore() {
        let context = container.viewContext

        let bookmarkStore = LocalBookmarkStore(context: context)

        let savingExpectation = self.expectation(description: "Saving")
        let loadingExpectation = self.expectation(description: "Loading")

        let folder = BookmarkFolder(id: UUID().uuidString, title: "Folder", parentFolderUUID: "bookmarks_root")

        bookmarkStore.save(folder: folder, parent: nil) { (success, error) in
            XCTAssert(success)
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

    func testWhenFolderIsAdded_AndItHasParentFolder_ThenItMustBeLoadedFromTheStore() {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let saveParentExpectation = self.expectation(description: "Save Parent Folder")
        let saveChildExpectation = self.expectation(description: "Save Child Folder")
        let loadingExpectation = self.expectation(description: "Loading")

        let parentId = UUID().uuidString
        let childFolder = BookmarkFolder(id: UUID().uuidString, title: "Child", parentFolderUUID: parentId)
        let parentFolder = BookmarkFolder(id: parentId, title: "Parent", parentFolderUUID: "bookmarks_root", children: [childFolder])

        bookmarkStore.save(folder: parentFolder, parent: nil) { (success, error) in
            XCTAssert(success)
            XCTAssertNil(error)

            saveParentExpectation.fulfill()

            bookmarkStore.save(folder: childFolder, parent: parentFolder) { (success, error) in
                XCTAssert(success)
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

    func testWhenBookmarkIsAdded_AndFolderHasBeenProvided_ThenBookmarkIsSavedToParentFolder() {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let saveFolderExpectation = self.expectation(description: "Save Parent Folder")
        let saveBookmarkExpectation = self.expectation(description: "Save Bookmark")
        let loadingExpectation = self.expectation(description: "Loading")

        let parentId = UUID().uuidString
        let bookmark = Bookmark(id: UUID().uuidString, url: "https://example.com", title: "Example", isFavorite: false, parentFolderUUID: parentId)
        let folder = BookmarkFolder(id: parentId, title: "Parent", parentFolderUUID: "bookmarks_root", children: [bookmark])

        bookmarkStore.save(folder: folder, parent: nil) { (success, error) in
            XCTAssert(success)
            XCTAssertNil(error)

            saveFolderExpectation.fulfill()

            bookmarkStore.save(bookmark: bookmark, parent: folder, index: nil) { (success, error) in
                XCTAssert(success)
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

    // MARK: Moving Bookmarks/Folders

    func testWhenMovingBookmarkWithinParentCollection_AndIndexIsValid_ThenBookmarkIsMoved() async {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let folder = BookmarkFolder(id: UUID().uuidString, title: "Parent")
        let bookmark1 = Bookmark(id: UUID().uuidString, url: "https://example1.com", title: "Example 1", isFavorite: false)
        let bookmark2 = Bookmark(id: UUID().uuidString, url: "https://example2.com", title: "Example 2", isFavorite: false)
        let bookmark3 = Bookmark(id: UUID().uuidString, url: "https://example3.com", title: "Example 3", isFavorite: false)

        // Save the initial bookmarks state:

        _ = await bookmarkStore.save(folder: folder, parent: nil)
        _ = await bookmarkStore.save(bookmark: bookmark1, parent: folder, index: nil)
        _ = await bookmarkStore.save(bookmark: bookmark2, parent: folder, index: nil)
        _ = await bookmarkStore.save(bookmark: bookmark3, parent: folder, index: nil)

        // Fetch persisted bookmarks back from the store:

        guard case let .success(initialTopLevelEntities) = await bookmarkStore.loadAll(type: .topLevelEntities),
              let initialParentFolder = initialTopLevelEntities.first as? BookmarkFolder else {
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

        guard case let .success(updatedTopLevelEntities) = await bookmarkStore.loadAll(type: .topLevelEntities),
              let updatedParentFolder = updatedTopLevelEntities.first as? BookmarkFolder else {
            XCTFail("Couldn't load top level entities")
            return
        }

        let expectedBookmarkUUIDs = [bookmark3.id, bookmark1.id, bookmark2.id]
        let updatedFetchedBookmarkUUIDs = updatedParentFolder.children.map(\.id)
        XCTAssertEqual(expectedBookmarkUUIDs, updatedFetchedBookmarkUUIDs)
    }

    func testWhenMovingBookmarkWithinParentCollection_AndIndexIsOutOfBounds_ThenBookmarkIsAppended() async {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let initialParentFolder = BookmarkFolder(id: UUID().uuidString, title: "Parent")
        let bookmark1 = Bookmark(id: UUID().uuidString, url: "https://example1.com", title: "Example 1", isFavorite: false)
        let bookmark2 = Bookmark(id: UUID().uuidString, url: "https://example2.com", title: "Example 2", isFavorite: false)
        let bookmark3 = Bookmark(id: UUID().uuidString, url: "https://example3.com", title: "Example 3", isFavorite: false)

        // Save the initial bookmarks state:

        _ = await bookmarkStore.save(folder: initialParentFolder, parent: nil)
        _ = await bookmarkStore.save(bookmark: bookmark1, parent: initialParentFolder, index: nil)
        _ = await bookmarkStore.save(bookmark: bookmark2, parent: initialParentFolder, index: nil)
        _ = await bookmarkStore.save(bookmark: bookmark3, parent: initialParentFolder, index: nil)

        // Fetch persisted bookmarks back from the store:

        guard case let .success(initialTopLevelEntities) = await bookmarkStore.loadAll(type: .topLevelEntities),
              let initialParentFolder = initialTopLevelEntities.first as? BookmarkFolder else {
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

        guard case let .success(updatedTopLevelEntities) = await bookmarkStore.loadAll(type: .topLevelEntities),
              let updatedParentFolder = updatedTopLevelEntities.first as? BookmarkFolder else {
            XCTFail("Couldn't load top level entities")
            return
        }

        let expectedBookmarkUUIDs = [bookmark2.id, bookmark3.id, bookmark1.id]
        let updatedFetchedBookmarkUUIDs = updatedParentFolder.children.map(\.id)
        XCTAssertEqual(expectedBookmarkUUIDs, updatedFetchedBookmarkUUIDs)
    }

    func testWhenMovingMultipleBookmarksWithinParentCollection_AndIndexIsValid_ThenBookmarksAreMoved() async {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let folder = BookmarkFolder(id: UUID().uuidString, title: "Parent")
        let bookmark1 = Bookmark(id: UUID().uuidString, url: "https://example1.com", title: "Example 1", isFavorite: false)
        let bookmark2 = Bookmark(id: UUID().uuidString, url: "https://example2.com", title: "Example 2", isFavorite: false)
        let bookmark3 = Bookmark(id: UUID().uuidString, url: "https://example3.com", title: "Example 3", isFavorite: false)

        // Save the initial bookmarks state:

        _ = await bookmarkStore.save(folder: folder, parent: nil)
        _ = await bookmarkStore.save(bookmark: bookmark1, parent: folder, index: nil)
        _ = await bookmarkStore.save(bookmark: bookmark2, parent: folder, index: nil)
        _ = await bookmarkStore.save(bookmark: bookmark3, parent: folder, index: nil)

        // Fetch persisted bookmarks back from the store:

        guard case let .success(initialTopLevelEntities) = await bookmarkStore.loadAll(type: .topLevelEntities),
              let initialParentFolder = initialTopLevelEntities.first as? BookmarkFolder else {
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

        guard case let .success(updatedTopLevelEntities) = await bookmarkStore.loadAll(type: .topLevelEntities),
              let updatedParentFolder = updatedTopLevelEntities.first as? BookmarkFolder else {
            XCTFail("Couldn't load top level entities")
            return
        }

        let expectedBookmarkUUIDs = [bookmark3.id, bookmark1.id, bookmark2.id]
        let updatedFetchedBookmarkUUIDs = updatedParentFolder.children.map(\.id)
        XCTAssertEqual(expectedBookmarkUUIDs, updatedFetchedBookmarkUUIDs)
    }

    func testWhenMovingBookmarkToRootFolder_AndIndexIsValid_ThenBookmarkIsMoved() async {
        guard let testState = await createInitialEntityMovementTestState() else {
            XCTFail("Failed to configure test state")
            return
        }

        // Update the order of the bookmarks:

        let moveBookmarksError = await testState.bookmarkStore.move(objectUUIDs: [testState.bookmark3.id], toIndex: 0, withinParentFolder: .root)
        XCTAssertNil(moveBookmarksError)

        // Check the new bookmarks order:

        guard case let .success(updatedTopLevelEntities) = await testState.bookmarkStore.loadAll(type: .topLevelEntities) else {
            XCTFail("Couldn't load top level entities")
            return
        }

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

    func testWhenMovingBookmarkToRootFolder_AndIndexIsOutOfBounds_ThenBookmarkIsAppended() async {
        guard let testState = await createInitialEntityMovementTestState() else {
            XCTFail("Failed to configure test state")
            return
        }

        // Update the order of the bookmarks:

        let moveBookmarksError = await testState.bookmarkStore.move(objectUUIDs: [testState.bookmark3.id], toIndex: 999, withinParentFolder: .root)
        XCTAssertNil(moveBookmarksError)

        // Check the new bookmarks order:

        guard case let .success(updatedTopLevelEntities) = await testState.bookmarkStore.loadAll(type: .topLevelEntities) else {
            XCTFail("Couldn't load top level entities")
            return
        }

        XCTAssertEqual(updatedTopLevelEntities.count, 2)

        let topLevelEntityIDs = updatedTopLevelEntities.map(\.id)
        XCTAssertEqual(topLevelEntityIDs, [testState.initialParentFolder.id, testState.bookmark3.id])
    }

    func testWhenUpdatingBookmarkFolder_ThenBookmarkFolderTitleIsUpdated() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        let folder1 = BookmarkFolder(id: UUID().uuidString, title: "Folder 1", parentFolderUUID: "bookmarks_root")

        // Save the initial bookmarks state:

        _ = await bookmarkStore.save(folder: folder1, parent: nil)

        // Fetch persisted bookmark folders back from the store:

        let folders = try await bookmarkStore.loadAll(type: .topLevelEntities).get().compactMap { $0 as? BookmarkFolder }

        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(folders.first, folder1)

        // Update the folder title and parent:

        let folderToMove = folder1
        folderToMove.title = #function
        bookmarkStore.update(folder: folder1)

        // Check the new bookmark folders order:

        let newFolders = try await bookmarkStore.loadAll(type: .topLevelEntities).get().compactMap { $0 as? BookmarkFolder }

        XCTAssertEqual(newFolders.count, 1)
        XCTAssertEqual(newFolders.first, folderToMove)
    }

    func testWhenUpdatingAndMovingBookmarkFolder_ThenBookmarkFolderIsMovedAndTitleUpdated() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let folder1 = BookmarkFolder(id: UUID().uuidString, title: "Folder 1", parentFolderUUID: "bookmarks_root")
        let folder2 = BookmarkFolder(id: UUID().uuidString, title: "Folder 2", parentFolderUUID: "bookmarks_root")
        let folder3 = BookmarkFolder(id: UUID().uuidString, title: "Folder 3", parentFolderUUID: "bookmarks_root")

        // Save the initial bookmarks state:

        _ = await bookmarkStore.save(folder: folder1, parent: nil)
        _ = await bookmarkStore.save(folder: folder2, parent: nil)
        _ = await bookmarkStore.save(folder: folder3, parent: nil)

        // Fetch persisted bookmark folders back from the store:

        let folders = try await bookmarkStore.loadAll(type: .topLevelEntities).get().compactMap { $0 as? BookmarkFolder }

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

        let newFolders = try await bookmarkStore.loadAll(type: .topLevelEntities).get().compactMap { $0 as? BookmarkFolder }

        XCTAssertEqual(newFolders.count, 2)
        XCTAssertEqual(newFolders[0].id, folder2.id)
        XCTAssertEqual(newFolders[0].children, [expectedFolderAfterMove])
        XCTAssertEqual(newFolders[1], folder3)
    }

    func testWhenMovingBookmarkFolderToSubfolder_ThenBookmarkFolderLocationIsUpdated() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let folder1 = BookmarkFolder(id: UUID().uuidString, title: "Folder 1", parentFolderUUID: "bookmarks_root")
        let folder2 = BookmarkFolder(id: UUID().uuidString, title: "Folder 2", parentFolderUUID: "bookmarks_root")

        // Save the initial bookmarks state:

        _ = await bookmarkStore.save(folder: folder1, parent: nil)
        _ = await bookmarkStore.save(folder: folder2, parent: nil)

        // Fetch persisted bookmark folders back from the store:

        let folders = try await bookmarkStore.loadAll(type: .topLevelEntities).get().compactMap { $0 as? BookmarkFolder }

        XCTAssertEqual(folders.count, 2)
        XCTAssertEqual(folders.first, folder1)
        XCTAssertEqual(folders.last, folder2)

        // Update the folder parent:

        _ = await bookmarkStore.move(objectUUIDs: [folder2.id], toIndex: nil, withinParentFolder: .parent(uuid: folder1.id))
        let expectedChildFolderAfterMove = BookmarkFolder(id: folder2.id, title: folder2.title, parentFolderUUID: folder1.id, children: folder2.children)
        let expectedParentFolderAfterMove = BookmarkFolder(id: folder1.id, title: folder1.title, parentFolderUUID: folder1.parentFolderUUID, children: [expectedChildFolderAfterMove])

        // Check the new bookmark folders order:

        let newFolders = try await bookmarkStore.loadAll(type: .topLevelEntities).get().compactMap { $0 as? BookmarkFolder }

        XCTAssertEqual(newFolders.count, 1)
        XCTAssertEqual(newFolders.first, expectedParentFolderAfterMove)
        XCTAssertEqual(newFolders.first?.children, [expectedChildFolderAfterMove])
    }

    func testWhenMovingBookmarkFolderToRootFolder_ThenBookmarkFolderLocationIsUpdated() async throws {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let folder2Id = UUID().uuidString
        let folder1 = BookmarkFolder(id: UUID().uuidString, title: "Folder 1", parentFolderUUID: folder2Id)
        let folder2 = BookmarkFolder(id: folder2Id, title: "Folder 2", parentFolderUUID: "bookmarks_root", children: [folder1])

        // Save the initial bookmarks state:

        _ = await bookmarkStore.save(folder: folder2, parent: nil)
        _ = await bookmarkStore.save(folder: folder1, parent: folder2)

        // Fetch persisted bookmark folders back from the store:

        let folders = try await bookmarkStore.loadAll(type: .topLevelEntities).get().compactMap { $0 as? BookmarkFolder }

        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(folders.first, folder2)
        XCTAssertEqual(folders.first?.children, [folder1])

        // Update the folder parent:

        _ = await bookmarkStore.move(objectUUIDs: [folder1.id], toIndex: 0, withinParentFolder: .root)

        // Check the new bookmark folders order:

        let newFolders = try await bookmarkStore.loadAll(type: .topLevelEntities).get().compactMap { $0 as? BookmarkFolder }
        let expectedFolder1AfterMove = BookmarkFolder(id: folder1.id, title: folder1.title, parentFolderUUID: "bookmarks_root", children: folder1.children)
        let expectedFolder2AfterMove = BookmarkFolder(id: folder2.id, title: folder2.title, parentFolderUUID: "bookmarks_root", children: [])

        XCTAssertEqual(newFolders.count, 2)
        XCTAssertEqual(newFolders.first, expectedFolder1AfterMove)
        XCTAssertEqual(newFolders.last, expectedFolder2AfterMove)
        XCTAssertEqual(newFolders.last?.children, [])
    }

    // MARK: Favorites

    func testThatTopLevelEntitiesDoNotContainFavoritesFolder() async {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        // Create and save favorites:

        let bookmark1 = Bookmark(id: UUID().uuidString, url: "https://example1.com", title: "Example 1", isFavorite: true)
        let bookmark2 = Bookmark(id: UUID().uuidString, url: "https://example2.com", title: "Example 2", isFavorite: true)

        _ = await bookmarkStore.save(bookmark: bookmark1, parent: nil, index: nil)
        _ = await bookmarkStore.save(bookmark: bookmark2, parent: nil, index: nil)

        // Fetch top level entities:

        guard case let .success(topLevelEntities) = await bookmarkStore.loadAll(type: .topLevelEntities) else {
            XCTFail("Couldn't load top level entities")
            return
        }

        XCTAssertEqual(topLevelEntities.count, 2)
        XCTAssertFalse(topLevelEntities.map(\.id).contains(FavoritesFolderID.unified.rawValue))
    }

    func testWhenBookmarkIsMarkedAsFavorite_ThenItDoesNotChangeParentFolder() async {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let folder1 = BookmarkFolder(id: UUID().uuidString, title: "Folder 1")
        let folder2 = BookmarkFolder(id: UUID().uuidString, title: "Folder 2")
        let bookmark = Bookmark(id: UUID().uuidString, url: "https://example1.com", title: "Example", isFavorite: false)

        // Save the initial bookmarks state:

        _ = await bookmarkStore.save(folder: folder1, parent: nil)
        _ = await bookmarkStore.save(folder: folder2, parent: nil)
        _ = await bookmarkStore.save(bookmark: bookmark, parent: folder1, index: nil)

        // Fetch persisted bookmarks back from the store:

        guard case let .success(initialTopLevelEntities) = await bookmarkStore.loadAll(type: .topLevelEntities),
              initialTopLevelEntities.count == 2,
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

        guard case let .success(updatedTopLevelEntities) = await bookmarkStore.loadAll(type: .topLevelEntities),
              updatedTopLevelEntities.count == 2,
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

    func testWhenMovingFavorite_AndIndexIsValid_ThenFavoriteIsMoved() async {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let folder = BookmarkFolder(id: UUID().uuidString, title: "Parent")
        let bookmark1 = Bookmark(id: UUID().uuidString, url: "https://example1.com", title: "Example 1", isFavorite: true)
        let bookmark2 = Bookmark(id: UUID().uuidString, url: "https://example2.com", title: "Example 2", isFavorite: true)
        let bookmark3 = Bookmark(id: UUID().uuidString, url: "https://example3.com", title: "Example 3", isFavorite: true)

        // Save the initial bookmarks state:

        _ = await bookmarkStore.save(folder: folder, parent: nil)
        _ = await bookmarkStore.save(bookmark: bookmark1, parent: folder, index: nil)
        _ = await bookmarkStore.save(bookmark: bookmark2, parent: folder, index: nil)
        _ = await bookmarkStore.save(bookmark: bookmark3, parent: folder, index: nil)

        // Fetch persisted favorites back from the store:

        guard case let .success(initialFavorites) = await bookmarkStore.loadAll(type: .favorites) else {
            XCTFail("Couldn't load favorites")
            return
        }

        XCTAssertEqual(initialFavorites.count, 3)

        // Verify initial order of saved favorites:

        let initialBookmarkUUIDs = [bookmark1.id, bookmark2.id, bookmark3.id]
        let initialFetchedBookmarkUUIDs = initialFavorites.map(\.id)
        XCTAssertEqual(initialBookmarkUUIDs, initialFetchedBookmarkUUIDs)

        // Update the order of the favorites:

        let moveFavoritesError = await bookmarkStore.moveFavorites(with: [bookmark3.id], toIndex: 0)
        XCTAssertNil(moveFavoritesError)

        // Check the new favorites order:

        guard case let .success(updatedFavorites) = await bookmarkStore.loadAll(type: .favorites) else {
            XCTFail("Couldn't load favorites")
            return
        }

        let expectedBookmarkUUIDs = [bookmark3.id, bookmark1.id, bookmark2.id]
        let updatedFetchedBookmarkUUIDs = updatedFavorites.map(\.id)
        XCTAssertEqual(expectedBookmarkUUIDs, updatedFetchedBookmarkUUIDs)
    }

    func testWhenMovingFavorite_AndIndexIsOutOfBounds_ThenFavoriteIsAppended() async {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let initialParentFolder = BookmarkFolder(id: UUID().uuidString, title: "Parent")
        let bookmark1 = Bookmark(id: UUID().uuidString, url: "https://example1.com", title: "Example 1", isFavorite: true)
        let bookmark2 = Bookmark(id: UUID().uuidString, url: "https://example2.com", title: "Example 2", isFavorite: true)
        let bookmark3 = Bookmark(id: UUID().uuidString, url: "https://example3.com", title: "Example 3", isFavorite: true)

        // Save the initial bookmarks state:

        _ = await bookmarkStore.save(folder: initialParentFolder, parent: nil)
        _ = await bookmarkStore.save(bookmark: bookmark1, parent: initialParentFolder, index: nil)
        _ = await bookmarkStore.save(bookmark: bookmark2, parent: initialParentFolder, index: nil)
        _ = await bookmarkStore.save(bookmark: bookmark3, parent: initialParentFolder, index: nil)

        // Fetch persisted favorites back from the store:

        guard case let .success(initialFavorites) = await bookmarkStore.loadAll(type: .favorites) else {
            XCTFail("Couldn't load favorites")
            return
        }

        XCTAssertEqual(initialFavorites.count, 3)

        // Verify initial order of saved favorites:

        let initialBookmarkUUIDs = [bookmark1.id, bookmark2.id, bookmark3.id]
        let initialFetchedBookmarkUUIDs = initialFavorites.map(\.id)
        XCTAssertEqual(initialBookmarkUUIDs, initialFetchedBookmarkUUIDs)

        // Update the order of the favorites:

        let moveFavoritesError = await bookmarkStore.moveFavorites(with: [bookmark1.id], toIndex: 999)
        XCTAssertNil(moveFavoritesError)

        // Check the new favorites order:

        guard case let .success(updatedFavorites) = await bookmarkStore.loadAll(type: .favorites) else {
            XCTFail("Couldn't load favorites")
            return
        }

        let expectedBookmarkUUIDs = [bookmark2.id, bookmark3.id, bookmark1.id]
        let updatedFetchedBookmarkUUIDs = updatedFavorites.map(\.id)
        XCTAssertEqual(expectedBookmarkUUIDs, updatedFetchedBookmarkUUIDs)
    }

    func testWhenMovingMultipleFavorites_AndIndexIsValid_ThenFavoritesAreMoved() async {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let folder = BookmarkFolder(id: UUID().uuidString, title: "Parent")
        let bookmark1 = Bookmark(id: UUID().uuidString, url: "https://example1.com", title: "Example 1", isFavorite: true)
        let bookmark2 = Bookmark(id: UUID().uuidString, url: "https://example2.com", title: "Example 2", isFavorite: true)
        let bookmark3 = Bookmark(id: UUID().uuidString, url: "https://example3.com", title: "Example 3", isFavorite: true)

        // Save the initial bookmarks state:

        _ = await bookmarkStore.save(folder: folder, parent: nil)
        _ = await bookmarkStore.save(bookmark: bookmark1, parent: folder, index: nil)
        _ = await bookmarkStore.save(bookmark: bookmark2, parent: folder, index: nil)
        _ = await bookmarkStore.save(bookmark: bookmark3, parent: folder, index: nil)

        // Fetch persisted favorites back from the store:

        guard case let .success(initialFavorites) = await bookmarkStore.loadAll(type: .favorites) else {
            XCTFail("Couldn't load favorites")
            return
        }

        XCTAssertEqual(initialFavorites.count, 3)

        // Verify initial order of saved favorites:

        let initialBookmarkUUIDs = [bookmark1.id, bookmark2.id, bookmark3.id]
        let initialFetchedBookmarkUUIDs = initialFavorites.map(\.id)
        XCTAssertEqual(initialBookmarkUUIDs, initialFetchedBookmarkUUIDs)

        // Update the order of the favorites:

        let moveFavoritesError = await bookmarkStore.moveFavorites(with: [bookmark1.id, bookmark2.id], toIndex: 3)
        XCTAssertNil(moveFavoritesError)

        // Check the new favorites order:

        guard case let .success(updatedFavorites) = await bookmarkStore.loadAll(type: .favorites) else {
            XCTFail("Couldn't load favorites")
            return
        }

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

    private func createInitialEntityMovementTestState() async -> EntityMovementTestState? {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let initialParentFolder = BookmarkFolder(id: UUID().uuidString, title: "Parent")
        let bookmark1 = Bookmark(id: UUID().uuidString, url: "https://example1.com", title: "Example 1", isFavorite: false)
        let bookmark2 = Bookmark(id: UUID().uuidString, url: "https://example2.com", title: "Example 2", isFavorite: false)
        let bookmark3 = Bookmark(id: UUID().uuidString, url: "https://example3.com", title: "Example 3", isFavorite: false)

        // Save the initial bookmarks state:

        _ = await bookmarkStore.save(folder: initialParentFolder, parent: nil)
        _ = await bookmarkStore.save(bookmark: bookmark1, parent: initialParentFolder, index: nil)
        _ = await bookmarkStore.save(bookmark: bookmark2, parent: initialParentFolder, index: nil)
        _ = await bookmarkStore.save(bookmark: bookmark3, parent: initialParentFolder, index: nil)

        // Fetch persisted bookmarks back from the store:

        guard case let .success(initialTopLevelEntities) = await bookmarkStore.loadAll(type: .topLevelEntities),
              let initialParentFolder = initialTopLevelEntities.first as? BookmarkFolder else {
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
        _ = await bookmarkStore.save(bookmark: bookmark, parent: nil, index: nil)

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
        _ = await bookmarkStore.save(bookmark: bookmark, parent: nil, index: nil)

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

    // MARK: Import

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

    func testWhenBookmarksAreImported_AndDuplicatesExist_ThenBookmarksAreStillImported() async {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        let importedBookmarks = createMockImportedBookmarks()

        // Import bookmarks once, and then again to test duplicates
        _ = bookmarkStore.importBookmarks(importedBookmarks, source: .thirdPartyBrowser(.safari))
        let result = bookmarkStore.importBookmarks(importedBookmarks, source: .thirdPartyBrowser(.safari))

        XCTAssertEqual(result.successful, 2)
        XCTAssertEqual(result.duplicates, 0)
        XCTAssertEqual(result.failed, 0)

        let loadResult = await bookmarkStore.loadAll(type: .bookmarks)

        switch loadResult {
        case .success(let bookmarks):
            XCTAssertEqual(bookmarks.count, 4)
        case .failure:
            XCTFail("Did not expect failure")
        }
    }

    func testWhenSafariBookmarksAreImported_AndTheBookmarksStoreIsEmpty_ThenBookmarksAreImportedToTheRootFolder_AndRootBookmarksAreFavorited() async {
        await validateInitialImport(for: .thirdPartyBrowser(.safari))
    }

    func testWhenChromeBookmarksAreImported_AndTheBookmarksStoreIsEmpty_ThenBookmarksAreImportedToTheRootFolder_AndRootBookmarksAreFavorited() async {
        await validateInitialImport(for: .thirdPartyBrowser(.chrome))
    }

    func testWhenFirefoxBookmarksAreImported_AndTheBookmarksStoreIsEmpty_ThenBookmarksAreImportedToTheRootFolder_AndRootBookmarksAreFavorited() async {
        await validateInitialImport(for: .thirdPartyBrowser(.firefox))
    }

    func testWhenSafariBookmarksAreImported_AndTheBookmarksStoreIsNotEmpty_ThenBookmarksAreImportedToTheirOwnFolder_AndNoBookmarksAreFavorited() async {
        await validateSubsequentImport(for: .thirdPartyBrowser(.safari))
    }

    func testWhenChromeBookmarksAreImported_AndTheBookmarksStoreIsNotEmpty_ThenBookmarksAreImportedToTheirOwnFolder_AndNoBookmarksAreFavorited() async {
        await validateSubsequentImport(for: .thirdPartyBrowser(.chrome))
    }

    func testWhenFirefoxBookmarksAreImported_AndTheBookmarksStoreIsNotEmpty_ThenBookmarksAreImportedToTheirOwnFolder_AndNoBookmarksAreFavorited() async {
        await validateSubsequentImport(for: .thirdPartyBrowser(.firefox))
    }

    func testWhenHTMLBookmarksAreImported_AndTheBookmarksStoreIsNotEmpty_ThenBookmarksAreImportedToTheirOwnFolder_AndNoBookmarksAreFavorited() async {
        await validateSubsequentImport(for: .thirdPartyBrowser(.bookmarksHTML))
    }

    func testWhenDDGHTMLBookmarksAreImported_AndTheBookmarksStoreIsNotEmpty_ThenBookmarksAreImportedToTheirOwnFolder_AndNoBookmarksAreFavorited() async {
        await validateSubsequentImport(for: .duckduckgoWebKit)
    }

    private func validateInitialImport(for source: BookmarkImportSource) async {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        let importedBookmarks = createMockImportedBookmarks()

        let result = bookmarkStore.importBookmarks(importedBookmarks, source: source)

        XCTAssertEqual(result.successful, 2)
        XCTAssertEqual(result.duplicates, 0)
        XCTAssertEqual(result.failed, 0)

        let topLevelEntitiesResult = await bookmarkStore.loadAll(type: .topLevelEntities)
        let bookmarksResult = await bookmarkStore.loadAll(type: .bookmarks)

        switch topLevelEntitiesResult {
        case .success(let entities):
            XCTAssert(entities.contains(where: { $0.title == "DuckDuckGo" }))
            XCTAssert(entities.contains(where: { $0.title == "Folder" }))
        case .failure:
            XCTFail("Did not expect failure when checking topLevelEntitiesResult")
        }

        switch bookmarksResult {
        case .success(let bookmarks):
            var totalFavorites = 0

            for bookmarkEntity in bookmarks {
                if let bookmark = bookmarkEntity as? Bookmark, bookmark.isFavorite {
                    totalFavorites += 1
                }
            }

            XCTAssertEqual(totalFavorites, 1)
        case .failure:
            XCTFail("Did not expect failure when checking bookmarksResult")
        }
    }

    private func validateSubsequentImport(for source: BookmarkImportSource) async {
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        let importedBookmarks = createMockImportedBookmarks()

        // Import bookmarks twice, one to initially populate the store and again to create the "Imported from [Browser]" folder.
        _ = bookmarkStore.importBookmarks(importedBookmarks, source: source)
        _ = bookmarkStore.importBookmarks(importedBookmarks, source: source)

        let topLevelEntitiesResult = await bookmarkStore.loadAll(type: .topLevelEntities)
        let bookmarksResult = await bookmarkStore.loadAll(type: .bookmarks)

        switch topLevelEntitiesResult {
        case .success(let entities):
            XCTAssert(entities.contains(where: { $0.title == "DuckDuckGo" }))
            XCTAssert(entities.contains(where: { $0.title == "Folder" }))
            XCTAssert(entities.contains(where: { $0.title.contains(source.importSourceName) }))
        case .failure:
            XCTFail("Did not expect failure when checking topLevelEntitiesResult")
        }

        switch bookmarksResult {
        case .success(let bookmarks):
            var totalFavorites = 0

            for bookmarkEntity in bookmarks {
                if let bookmark = bookmarkEntity as? Bookmark, bookmark.isFavorite {
                    totalFavorites += 1
                }
            }

            XCTAssertEqual(totalFavorites, 1)
        case .failure:
            XCTFail("Did not expect failure when checking bookmarksResult")
        }
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
