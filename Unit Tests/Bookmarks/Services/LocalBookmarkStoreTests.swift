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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class LocalBookmarkStoreTests: XCTestCase {

    // MARK: Save/Delete

    func testWhenBookmarkIsSaved_ThenItMustBeLoadedFromStore() {
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext

        let bookmarkStore = LocalBookmarkStore(context: context)

        let savingExpectation = self.expectation(description: "Saving")
        let loadingExpectation = self.expectation(description: "Loading")

        let bookmark = Bookmark(id: UUID(), url: URL.duckDuckGo, title: "DuckDuckGo", isFavorite: true)

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
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext

        let bookmarkStore = LocalBookmarkStore(context: context)

        let savingExpectation = self.expectation(description: "Saving")
        let removingExpectation = self.expectation(description: "Removing")
        let loadingExpectation = self.expectation(description: "Loading")

        let bookmark = Bookmark(id: UUID(), url: URL.duckDuckGo, title: "DuckDuckGo", isFavorite: true)
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
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext

        let bookmarkStore = LocalBookmarkStore(context: context)

        let savingExpectation = self.expectation(description: "Saving")
        let loadingExpectation = self.expectation(description: "Loading")

        let bookmark = Bookmark(id: UUID(), url: URL.duckDuckGo, title: "DuckDuckGo", isFavorite: true)

        bookmarkStore.save(bookmark: bookmark, parent: nil, index: nil) { (success, error) in
            XCTAssert(success)
            XCTAssertNil(error)

            savingExpectation.fulfill()

            let modifiedBookmark = Bookmark(id: bookmark.id, url: URL.duckDuckGo, title: "New Title", isFavorite: false)
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
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext

        let bookmarkStore = LocalBookmarkStore(context: context)

        let savingExpectation = self.expectation(description: "Saving")
        let loadingExpectation = self.expectation(description: "Loading")

        let folder = BookmarkFolder(id: UUID(), title: "Folder")

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
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let saveParentExpectation = self.expectation(description: "Save Parent Folder")
        let saveChildExpectation = self.expectation(description: "Save Child Folder")
        let loadingExpectation = self.expectation(description: "Loading")

        let parentFolder = BookmarkFolder(id: UUID(), title: "Parent")
        let childFolder = BookmarkFolder(id: UUID(), title: "Child")

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

    func testWhenFolderIsAdded_AndUUIDHasAlreadyBeenUsed_ThenSavingFails() {
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let firstSaveExpectation = self.expectation(description: "First Save")
        let secondSaveExpectation = self.expectation(description: "Second Save")

        let folder = BookmarkFolder(id: UUID(), title: "Folder")

        bookmarkStore.save(folder: folder, parent: nil) { (success, error) in
            XCTAssert(success)
            XCTAssertNil(error)

            firstSaveExpectation.fulfill()

            bookmarkStore.save(folder: folder, parent: nil) { (success, error) in
                // `true` is provided here anyway, in case the error in unrelated to the save action.
                XCTAssert(success)
                XCTAssertNotNil(error)

                secondSaveExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testWhenBookmarkIsAdded_AndFolderHasBeenProvided_ThenBookmarkIsSavedToParentFolder() {
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let saveFolderExpectation = self.expectation(description: "Save Parent Folder")
        let saveBookmarkExpectation = self.expectation(description: "Save Bookmark")
        let loadingExpectation = self.expectation(description: "Loading")

        let folder = BookmarkFolder(id: UUID(), title: "Parent")
        let bookmark = Bookmark(id: UUID(), url: URL(string: "https://example.com")!, title: "Example", isFavorite: false)

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
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        
        let folder = BookmarkFolder(id: UUID(), title: "Parent")
        let bookmark1 = Bookmark(id: UUID(), url: URL(string: "https://example1.com")!, title: "Example 1", isFavorite: false)
        let bookmark2 = Bookmark(id: UUID(), url: URL(string: "https://example2.com")!, title: "Example 2", isFavorite: false)
        let bookmark3 = Bookmark(id: UUID(), url: URL(string: "https://example3.com")!, title: "Example 3", isFavorite: false)
        
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
        
        let moveBookmarksError = await bookmarkStore.move(objectUUIDs: [bookmark3.id], toIndex: 0, withinParentFolder: .parent(folder.id))
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
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        
        let initialParentFolder = BookmarkFolder(id: UUID(), title: "Parent")
        let bookmark1 = Bookmark(id: UUID(), url: URL(string: "https://example1.com")!, title: "Example 1", isFavorite: false)
        let bookmark2 = Bookmark(id: UUID(), url: URL(string: "https://example2.com")!, title: "Example 2", isFavorite: false)
        let bookmark3 = Bookmark(id: UUID(), url: URL(string: "https://example3.com")!, title: "Example 3", isFavorite: false)
        
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
        
        let moveBookmarksError = await bookmarkStore.move(objectUUIDs: [bookmark1.id], toIndex: 999, withinParentFolder: .parent(initialParentFolder.id))
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
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        
        let folder = BookmarkFolder(id: UUID(), title: "Parent")
        let bookmark1 = Bookmark(id: UUID(), url: URL(string: "https://example1.com")!, title: "Example 1", isFavorite: false)
        let bookmark2 = Bookmark(id: UUID(), url: URL(string: "https://example2.com")!, title: "Example 2", isFavorite: false)
        let bookmark3 = Bookmark(id: UUID(), url: URL(string: "https://example3.com")!, title: "Example 3", isFavorite: false)
        
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
        
        let moveBookmarksError = await bookmarkStore.move(objectUUIDs: [bookmark1.id, bookmark2.id], toIndex: 3, withinParentFolder: .parent(folder.id))
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
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        
        let initialParentFolder = BookmarkFolder(id: UUID(), title: "Parent")
        let bookmark1 = Bookmark(id: UUID(), url: URL(string: "https://example1.com")!, title: "Example 1", isFavorite: false)
        let bookmark2 = Bookmark(id: UUID(), url: URL(string: "https://example2.com")!, title: "Example 2", isFavorite: false)
        let bookmark3 = Bookmark(id: UUID(), url: URL(string: "https://example3.com")!, title: "Example 3", isFavorite: false)
        
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
        
        let moveBookmarksError = await bookmarkStore.move(objectUUIDs: [bookmark3.id], toIndex: 0, withinParentFolder: .root)
        XCTAssertNil(moveBookmarksError)
        
        // Check the new bookmarks order:
        
        guard case let .success(updatedTopLevelEntities) = await bookmarkStore.loadAll(type: .topLevelEntities) else {
            XCTFail("Couldn't load top level entities")
            return
        }
        
        XCTAssertEqual(updatedTopLevelEntities.count, 2)
        
        let topLevelEntityIDs = updatedTopLevelEntities.map(\.id)
        XCTAssertEqual(topLevelEntityIDs, [bookmark3.id, initialParentFolder.id])
        
        guard let folder = updatedTopLevelEntities.first(where: { $0.id == initialParentFolder.id }) as? BookmarkFolder else {
            XCTFail("Couldn't find expected folder")
            return
        }
        
        let expectedBookmarkUUIDs = [bookmark1.id, bookmark2.id]
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
    
    private struct EntityMovementTestState {
        let bookmarkStore: LocalBookmarkStore
        let bookmark1: Bookmark
        let bookmark2: Bookmark
        let bookmark3: Bookmark
        let initialParentFolder: BookmarkFolder
    }
    
    private func createInitialEntityMovementTestState() async -> EntityMovementTestState? {
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)
        
        let initialParentFolder = BookmarkFolder(id: UUID(), title: "Parent")
        let bookmark1 = Bookmark(id: UUID(), url: URL(string: "https://example1.com")!, title: "Example 1", isFavorite: false)
        let bookmark2 = Bookmark(id: UUID(), url: URL(string: "https://example2.com")!, title: "Example 2", isFavorite: false)
        let bookmark3 = Bookmark(id: UUID(), url: URL(string: "https://example3.com")!, title: "Example 3", isFavorite: false)
        
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
    
    // MARK: Import

    func testWhenBookmarksAreImported_AndNoDuplicatesExist_ThenBookmarksAreImported() {
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let bookmark = ImportedBookmarks.BookmarkOrFolder(name: "DuckDuckGo", type: "bookmark", urlString: "https://duckduckgo.com", children: nil)
        let bookmarkBar = ImportedBookmarks.BookmarkOrFolder(name: "Bookmark Bar", type: "folder", urlString: nil, children: [bookmark])
        let otherBookmarks = ImportedBookmarks.BookmarkOrFolder(name: "Other Bookmarks", type: "folder", urlString: nil, children: [])

        let topLevelFolders = ImportedBookmarks.TopLevelFolders(bookmarkBar: bookmarkBar, otherBookmarks: otherBookmarks)
        let importedBookmarks = ImportedBookmarks(topLevelFolders: topLevelFolders)

        let result = bookmarkStore.importBookmarks(importedBookmarks, source: .safari)

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

    func testWhenBookmarksAreImported_AndDuplicatesExist_ThenNoBookmarksAreImported() {
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext
        let bookmarkStore = LocalBookmarkStore(context: context)

        let bookmark = ImportedBookmarks.BookmarkOrFolder(name: "DuckDuckGo", type: "bookmark", urlString: "https://duckduckgo.com", children: nil)
        let bookmarkBar = ImportedBookmarks.BookmarkOrFolder(name: "Bookmark Bar", type: "folder", urlString: nil, children: [bookmark])
        let otherBookmarks = ImportedBookmarks.BookmarkOrFolder(name: "Other Bookmarks", type: "folder", urlString: nil, children: [])

        let topLevelFolders = ImportedBookmarks.TopLevelFolders(bookmarkBar: bookmarkBar, otherBookmarks: otherBookmarks)
        let importedBookmarks = ImportedBookmarks(topLevelFolders: topLevelFolders)

        // Import bookmarks once, and then again to test duplicates
        _ = bookmarkStore.importBookmarks(importedBookmarks, source: .safari)
        let result = bookmarkStore.importBookmarks(importedBookmarks, source: .safari)

        XCTAssertEqual(result.successful, 0)
        XCTAssertEqual(result.duplicates, 1)
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

}
