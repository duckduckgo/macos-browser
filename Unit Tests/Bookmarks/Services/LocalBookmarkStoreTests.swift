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

    func testWhenBookmarkIsSaved_ThenItMustBeLoadedFromStore() {
        let container = CoreData.bookmarkContainer()
        let context = container.viewContext

        let bookmarkStore = LocalBookmarkStore(context: context)

        let savingExpectation = self.expectation(description: "Saving")
        let loadingExpectation = self.expectation(description: "Loading")

        let bookmark = Bookmark(id: UUID(), url: URL.duckDuckGo, title: "DuckDuckGo", isFavorite: true)

        bookmarkStore.save(bookmark: bookmark, parent: nil) { (success, error) in
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
        bookmarkStore.save(bookmark: bookmark, parent: nil) { (success, error) in
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

        bookmarkStore.save(bookmark: bookmark, parent: nil) { (success, error) in
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
                XCTAssertFalse(success)
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

            bookmarkStore.save(bookmark: bookmark, parent: folder) { (success, error) in
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
