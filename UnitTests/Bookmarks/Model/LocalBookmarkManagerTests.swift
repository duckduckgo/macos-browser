//
//  LocalBookmarkManagerTests.swift
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

import Bookmarks
import Combine
import Foundation

import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class LocalBookmarkManagerTests: XCTestCase {

    var container: NSPersistentContainer!

    enum BookmarkManagerError: Error {
        case somethingReallyBad
    }

    override func setUp() {
        container = CoreData.bookmarkContainer()
        let context = container.newBackgroundContext()
        context.performAndWait {
            BookmarkUtils.prepareFoldersStructure(in: context)
        }
        LocalBookmarkManager.context = context
    }

    @MainActor
    func testWhenBookmarksAreNotLoadedYet_ThenManagerIgnoresBookmarkingRequests() {
        let (bookmarkManager, _) = LocalBookmarkManager.manager(loadBookmarks: false) {}

        XCTAssertNil(bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Test", isFavorite: false))
        XCTAssertNil(bookmarkManager.updateUrl(of: Bookmark.aBookmark, to: URL.duckDuckGoAutocomplete))
    }

    @MainActor
    func testWhenBookmarksAreLoaded_ThenTheManagerHoldsAllLoadedBookmarks() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.manager {
            Bookmark.aBookmark
        }

        XCTAssert(bookmarkManager.isUrlBookmarked(url: Bookmark.aBookmark.urlObject!))
        XCTAssertNotNil(bookmarkManager.getBookmark(for: Bookmark.aBookmark.urlObject!))
        XCTAssert(bookmarkStoreMock.loadAllCalled)
        XCTAssertEqual(bookmarkManager.list?.bookmarks().count, 1)
    }

    @MainActor
    func testWhenLoadFails_ThenTheManagerHoldsBookmarksAreNil() {
        let bookmarkStoreMock = BookmarkStoreMock()
        let faviconManagerMock = FaviconManagerMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconManagement: faviconManagerMock)

        bookmarkStoreMock.loadError = BookmarkManagerError.somethingReallyBad
        bookmarkManager.loadBookmarks()

        XCTAssertNil(bookmarkManager.list?.bookmarks())
        XCTAssert(bookmarkStoreMock.loadAllCalled)
    }

    func testWhenBookmarkIsCreated_ThenManagerSavesItToStore() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager
        let bookmark = bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Title", isFavorite: false)!

        XCTAssert(bookmarkManager.isUrlBookmarked(url: bookmark.urlObject!))
        XCTAssert(bookmarkStoreMock.saveBookmarkCalled)
    }

    func testWhenBookmarkIsCreatedAndStoringFails_ThenManagerRemovesItFromList() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager

        bookmarkStoreMock.saveBookmarkSuccess = false
        let bookmark = bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Title", isFavorite: false)!

        XCTAssertFalse(bookmarkManager.isUrlBookmarked(url: bookmark.urlObject!))
        XCTAssert(bookmarkStoreMock.saveBookmarkCalled)
    }

    func testWhenUrlIsAlreadyBookmarked_ThenManagerReturnsNil() {
        let (bookmarkManager, _) = LocalBookmarkManager.aManager
        _ = bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Title", isFavorite: false)!

        XCTAssertNil(bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Title", isFavorite: false))
    }

    @MainActor
    func testWhenBookmarkIsRemoved_ThenManagerRemovesItFromStore() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager
        let bookmark = bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Title", isFavorite: false)!

        bookmarkManager.remove(bookmark: bookmark, undoManager: nil)

        XCTAssertFalse(bookmarkManager.isUrlBookmarked(url: bookmark.urlObject!))
        XCTAssert(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssert(bookmarkStoreMock.removeCalled)
    }

    @MainActor
    func testWhenFolderIsRemoved_ThenManagerRemovesItFromStore() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager
        var folder: BookmarkFolder!
        let e = expectation(description: "Folder created")
        bookmarkManager.makeFolder(for: "Folder", parent: nil) { result in
            folder = try? result.get()
            e.fulfill()
        }
        waitForExpectations(timeout: 1)
        guard let folder else { XCTFail("Folder not loaded"); return }

        let loadedFolder = bookmarkManager.getBookmarkFolder(withId: folder.id)
        XCTAssertEqual(folder, loadedFolder)

        bookmarkManager.remove(folder: folder, undoManager: nil)

        XCTAssertNil(bookmarkManager.getBookmarkFolder(withId: folder.id))
        XCTAssert(bookmarkStoreMock.saveFolderCalled)
        XCTAssertEqual(bookmarkStoreMock.removeCalledWithIds, [folder.id])
    }

    @MainActor
    func testWhenBookmarkAndFolderAreRemoved_ThenManagerRemovesThemFromStore() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager
        let bookmark = bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Title", isFavorite: false)!
        var folder: BookmarkFolder!
        let e = expectation(description: "Folder created")
        bookmarkManager.makeFolder(for: "Folder", parent: nil) { result in
            folder = try? result.get()
            e.fulfill()
        }
        waitForExpectations(timeout: 1)
        guard let folder else { XCTFail("Folder not loaded"); return }

        bookmarkManager.remove(objectsWithUUIDs: [folder.id, bookmark.id], undoManager: nil)

        XCTAssertEqual(Set(bookmarkStoreMock.removeCalledWithIds ?? []), Set([folder.id, bookmark.id]))
    }

    @MainActor
    func testWhenRemovalFails_ThenManagerPutsBookmarkBackToList() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager
        let bookmark = bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Title", isFavorite: false)!

        bookmarkStoreMock.removeSuccess = false
        bookmarkStoreMock.removeError = BookmarkManagerError.somethingReallyBad
        bookmarkManager.remove(bookmark: bookmark, undoManager: nil)

        XCTAssert(bookmarkManager.isUrlBookmarked(url: bookmark.urlObject!))
        XCTAssert(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssert(bookmarkStoreMock.removeCalled)
    }

    @MainActor
    func testWhenBookmarkRemovalIsUndone_ThenRestoreBookmarkIsCalled() async throws {
        let (bookmarkManager, bookmarkStoreMock) = await LocalBookmarkManager.manager(with: {
            bookmark(.duckDuckGo)
            bookmark(.duckDuckGoEmail)
            folder("Folder")
        })
        let undoManager = UndoManager()
        let removedBookmark = bookmarkManager.getBookmark(for: .duckDuckGoEmail)!

        // remove
        bookmarkManager.remove(bookmark: removedBookmark, undoManager: undoManager)

        // undo remove
        XCTAssertTrue(undoManager.canUndo)
        undoManager.undo()

        assertEqual(bookmarkStoreMock.saveEntitiesAtIndicesCalledWith, [(removedBookmark, 1)])
        // update the bookmark because it‘s recreated with a new id
        guard let removedBookmark = bookmarkManager.getBookmark(for: .duckDuckGoEmail) else { XCTFail("Could not fetch bookmark"); return }

        // redo remove
        bookmarkStoreMock.removeCalledWithIds = nil
        XCTAssertTrue(undoManager.canRedo)

        // validate bookmark is removed
        undoManager.redo()
        XCTAssertEqual(bookmarkStoreMock.removeCalledWithIds ?? [], [removedBookmark.id])

        // undo again
        XCTAssertTrue(undoManager.canUndo)
        undoManager.undo()

        assertEqual(bookmarkStoreMock.saveEntitiesAtIndicesCalledWith, [(removedBookmark, 1)])
        XCTAssertTrue(undoManager.canRedo)
    }

    @MainActor
    func testWhenFolderRemovalIsUndone_ThenRestoreFolderIsCalled() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.manager(with: {
            bookmark(.duckDuckGo)
            folder(id: "1", "Folder") {
                bookmark(.duckDuckGoEmailLogin)
                bookmark(.duckDuckGoEmailInfo, isFavorite: true)
                folder("Subfolder") {
                    bookmark(.duckDuckGoAutocomplete, isFavorite: true)
                }
            }
            bookmark(.duckDuckGoEmail)
        })
        let undoManager = UndoManager()
        let removedFolder = bookmarkManager.getBookmarkFolder(withId: "1")!

        // remove
        bookmarkManager.remove(folder: removedFolder, undoManager: undoManager)

        // undo remove
        XCTAssertTrue(undoManager.canUndo)
        undoManager.undo()

        // validate entities are restored
        guard let removedFolder = bookmarkStoreMock.saveEntitiesAtIndicesCalledWith?[safe: 0]?.entity as? BookmarkFolder else { XCTFail("1. Could not fetch folder"); return }
        assertEqual(bookmarkStoreMock.saveEntitiesAtIndicesCalledWith, [
            (removedFolder, 1),
            (Bookmark(.duckDuckGoEmailLogin, parentId: removedFolder.id), nil),
            (Bookmark(.duckDuckGoEmailInfo, isFavorite: true, parentId: removedFolder.id), nil),
            (BookmarkFolder("Subfolder"), nil),
            (Bookmark(.duckDuckGoAutocomplete, isFavorite: true, parentId: removedFolder.id), nil),
        ])

        // redo remove
        bookmarkStoreMock.removeCalledWithIds = nil
        XCTAssertTrue(undoManager.canRedo)

        // validate bookmark is removed
        undoManager.redo()
        XCTAssertEqual(bookmarkStoreMock.removeCalledWithIds ?? [], [removedFolder.id])

        // undo again
        XCTAssertTrue(undoManager.canUndo)
        undoManager.undo()

        // validate entities are restored
        guard let removedFolder = bookmarkStoreMock.saveEntitiesAtIndicesCalledWith?[safe: 0]?.entity as? BookmarkFolder else { XCTFail("2. Could not fetch folder"); return }
        assertEqual(bookmarkStoreMock.saveEntitiesAtIndicesCalledWith, [
            (removedFolder, 1),
            (Bookmark(.duckDuckGoEmailLogin, parentId: removedFolder.id), nil),
            (Bookmark(.duckDuckGoEmailInfo, parentId: removedFolder.id), nil),
            (BookmarkFolder("Subfolder"), nil),
            (Bookmark(.duckDuckGoAutocomplete, isFavorite: true, parentId: removedFolder.id), nil),
        ])
        XCTAssertTrue(undoManager.canRedo)
    }

//    @MainActor
//    func testWhenBookmarkAndFolderRemovalIsUndone_ThenRestoreEntitiesIsCalled() {
//        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager
//        let bookmark = bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Title", isFavorite: false)!
//        var folder: BookmarkFolder!
//        let e = expectation(description: "Folder created")
//        bookmarkManager.makeFolder(for: "Folder", parent: nil) { result in
//            folder = try? result.get()
//            e.fulfill()
//        }
//        waitForExpectations(timeout: 1)
//        guard let folder else { XCTFail("Folder not loaded"); return }
//
//        let undoManager = UndoManager()
//        bookmarkStoreMock.bookmarkEntitiesWithIds = { ids in
//            XCTAssertEqual(Set(ids), [folder.id, bookmark.id])
//            return [folder, bookmark]
//        }
//
//        bookmarkManager.remove(objectsWithUUIDs: [folder.id, bookmark.id], undoManager: undoManager)
//
//        XCTAssertTrue(undoManager.canUndo)
//        undoManager.undo()
//
//        XCTAssertEqual(bookmarkStoreMock.restoreCalledEntities, [folder, bookmark])
//
//        bookmarkStoreMock.removeCalledWithIds = nil
//        XCTAssertTrue(undoManager.canRedo)
//
//        undoManager.redo()
//        XCTAssertEqual(Set(bookmarkStoreMock.removeCalledWithIds ?? []), Set([folder.id, bookmark.id]))
//    }

    @MainActor
    func testWhenBookmarkNoLongerExist_ThenManagerIgnoresAttemptToRemoval() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager

        bookmarkManager.remove(bookmark: Bookmark.aBookmark, undoManager: nil)

        XCTAssertFalse(bookmarkManager.isUrlBookmarked(url: Bookmark.aBookmark.urlObject!))
        XCTAssertFalse(bookmarkStoreMock.removeCalled)
    }

    func testWhenBookmarkNoLongerExist_ThenManagerIgnoresAttemptToUpdate() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager

        bookmarkManager.update(bookmark: Bookmark.aBookmark)
        let updateUrlResult = bookmarkManager.updateUrl(of: Bookmark.aBookmark, to: URL.duckDuckGoAutocomplete)

        XCTAssertFalse(bookmarkManager.isUrlBookmarked(url: Bookmark.aBookmark.urlObject!))
        XCTAssertFalse(bookmarkStoreMock.updateBookmarkCalled)
        XCTAssertNil(updateUrlResult)
    }

    func testWhenBookmarkIsUpdated_ThenManagerUpdatesItInStore() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager
        let bookmark = bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Title", isFavorite: false)!

        bookmark.isFavorite = !bookmark.isFavorite
        bookmarkManager.update(bookmark: bookmark)

        XCTAssert(bookmarkManager.isUrlBookmarked(url: bookmark.urlObject!))
        XCTAssert(bookmarkStoreMock.updateBookmarkCalled)
    }

    func testWhenBookmarkUrlIsUpdated_ThenManagerUpdatesItAlsoInStore() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager
        let bookmark = bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Title", isFavorite: false)!

        let newURL = URL.duckDuckGoAutocomplete
        guard let newBookmark = bookmarkManager.updateUrl(of: bookmark, to: newURL) else {
            XCTFail("bookmark not saved")
            return
        }

        XCTAssertFalse(bookmarkManager.isUrlBookmarked(url: bookmark.urlObject!))
        XCTAssert(bookmarkManager.isUrlBookmarked(url: newBookmark.urlObject!))
        XCTAssert(bookmarkManager.isUrlBookmarked(url: newURL))
        XCTAssert(bookmarkStoreMock.updateBookmarkCalled)
    }

    func testWhenBookmarkFolderIsUpdatedAndMoved_ThenManagerUpdatesItAlsoInStore() throws {
        let parent = BookmarkFolder(id: "1", title: "Parent")
        let folder = BookmarkFolder(id: "2", title: "Child")
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.manager {
            parent
            folder
        }
        var bookmarkList: BookmarkList?
        let e = expectation(description: "list published")
        let cancellable = bookmarkManager.listPublisher
            .dropFirst()
            .sink { list in
                bookmarkList = list
                e.fulfill()
            }

        bookmarkManager.update(folder: folder, andMoveToParent: .parent(uuid: parent.id))

        withExtendedLifetime(cancellable) {
            wait(for: [e], timeout: 5)
        }
        XCTAssertTrue(bookmarkStoreMock.updateFolderAndMoveToParentCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedFolder, folder)
        XCTAssertEqual(bookmarkStoreMock.capturedParentFolderType, .parent(uuid: parent.id))
        XCTAssertNotNil(bookmarkList)
    }

    func testWhenGetBookmarkFolderIsCalledThenAskBookmarkStoreToRetrieveFolder() throws {
        // GIVEN
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager
        XCTAssertFalse(bookmarkStoreMock.bookmarkFolderWithIdCalled)
        XCTAssertNil(bookmarkStoreMock.capturedFolderId)

        // WHEN
        _ = bookmarkManager.getBookmarkFolder(withId: #function)

        // THEN
        XCTAssertTrue(bookmarkStoreMock.bookmarkFolderWithIdCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedFolderId, #function)
    }

    func testWhenGetBookmarkFolderIsCalledAndFolderExistsInStoreThenBookmarkStoreReturnsFolder() throws {
        // GIVEN
        let folder = BookmarkFolder(id: #function, title: "Test")
        let (bookmarkManager, _) = LocalBookmarkManager.manager { folder }

        // WHEN
        let result = bookmarkManager.getBookmarkFolder(withId: #function)

        // THEN
        XCTAssertEqual(result, folder)
    }

    func testWhenGetBookmarkFolderIsCalledAndFolderDoesNotExistInStoreThenBookmarkStoreReturnsNil() throws {
        // GIVEN
        let (bookmarkManager, _) = LocalBookmarkManager.aManager

        // WHEN
        let result = bookmarkManager.getBookmarkFolder(withId: #function)

        // THEN
        XCTAssertNil(result)
    }

    // MARK: - Save Multiple Bookmarks at once

    @MainActor
    func testWhenMakeBookmarksForWebsitesInfoIsCalledThenBookmarkStoreIsAskedToCreateMultipleBookmarks() {
        // GIVEN
        let (sut, bookmarkStoreMock) = LocalBookmarkManager.aManager
        let newFolderName = #function
        let websitesInfo = [
            WebsiteInfo(url: URL.duckDuckGo, title: "Website 1"),
            WebsiteInfo(url: URL.duckDuckGo, title: "Website 2"),
            WebsiteInfo(url: URL.duckDuckGo, title: "Website 3"),
            WebsiteInfo(url: URL.duckDuckGo, title: "Website 4"),
        ].compactMap { $0 }
        XCTAssertFalse(bookmarkStoreMock.saveBookmarksInNewFolderNamedCalled)
        XCTAssertNil(bookmarkStoreMock.capturedWebsitesInfo)
        XCTAssertNil(bookmarkStoreMock.capturedNewFolderName)
        XCTAssertNil(bookmarkStoreMock.capturedParentFolderType)

        // WHEN
        sut.makeBookmarks(for: websitesInfo, inNewFolderNamed: newFolderName, withinParentFolder: .root)

        // THEN
        XCTAssertTrue(bookmarkStoreMock.saveBookmarksInNewFolderNamedCalled)
        XCTAssertEqual(bookmarkStoreMock.capturedWebsitesInfo?.count, 4)
        XCTAssertEqual(bookmarkStoreMock.capturedWebsitesInfo, websitesInfo)
        XCTAssertEqual(bookmarkStoreMock.capturedNewFolderName, newFolderName)
        XCTAssertEqual(bookmarkStoreMock.capturedParentFolderType, .root)
    }

    @MainActor
    func testWhenMakeBookmarksForWebsiteInfoIsCalledThenReloadAllBookmarks() {
        // GIVEN
        let (sut, bookmarkStoreMock) = LocalBookmarkManager.aManager
        bookmarkStoreMock.loadAllCalled = false // Reset after load all bookmarks the first time
        XCTAssertFalse(bookmarkStoreMock.loadAllCalled)
        let websitesInfo = [WebsiteInfo(url: URL.duckDuckGo, title: "Website 1")].compactMap { $0 }

        // WHEN
        sut.makeBookmarks(for: websitesInfo, inNewFolderNamed: "Test", withinParentFolder: .root)

        // THEN
        XCTAssertTrue(bookmarkStoreMock.loadAllCalled)
    }

    // MARK: - Search

    func testWhenBookmarkListIsNilThenSearchIsEmpty() {
        let sut = LocalBookmarkManager()
        let results = sut.search(by: "abc")

        XCTAssertNil(sut.list)
        XCTAssertTrue(results.isEmpty)
    }

    @MainActor
    func testWhenQueryIsEmptyThenSearchResultsAreEmpty() {
        let (sut, _) = LocalBookmarkManager.manager(with: topLevelBookmarks)
        let results = sut.search(by: "")

        XCTAssertTrue(results.isEmpty)
    }

    @MainActor
    func testWhenQueryIsBlankThenSearchResultsAreEmpty() {
        let (sut, _) = LocalBookmarkManager.manager(with: topLevelBookmarks)

        let results = sut.search(by: "    ")

        XCTAssertTrue(results.isEmpty)
    }

    @MainActor
    func testWhenASearchIsDoneThenCorrectResultsAreReturnedAndIntheRightOrder() {
        let (sut, _) = LocalBookmarkManager.manager(with: topLevelBookmarks)
        let results = sut.search(by: "folder")

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[safe: 0]?.title, "This is a folder")
        XCTAssertEqual(results[safe: 1]?.title, "Favorite folder")
        XCTAssertEqual(results[safe: 2]?.title, "This is a sub-folder")
    }

    @MainActor
    func testWhenASearchIsDoneThenFoldersAndBookmarksAreReturned() {
        let (sut, _) = LocalBookmarkManager.manager(with: topLevelBookmarks)
        let results = sut.search(by: "favorite")

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[safe: 0]?.title, "Favorite folder")
        XCTAssert(results[safe: 0]?.isFolder == true)
        XCTAssertEqual(results[safe: 1]?.title, "Favorite bookmark")
        XCTAssert(results[safe: 1]?.isFolder == false)
    }

    @MainActor
    func testWhenASearchIsDoneThenItMatchesWithLowercaseResults() {
        let (sut, _) = LocalBookmarkManager.manager {
            Bookmark(id: "1", url: "www.favorite.com", title: "Favorite bookmark", isFavorite: true)
            Bookmark(id: "2", url: "www.favoritetwo.com", title: "favorite bookmark", isFavorite: true)
        }

        let resultsWhtCapitalizedQuery = sut.search(by: "Favorite")
        let resultsWithNotCapitalizedQuery = sut.search(by: "favorite")

        XCTAssertTrue(resultsWhtCapitalizedQuery.count == 2)
        XCTAssertTrue(resultsWithNotCapitalizedQuery.count == 2)
    }

    @MainActor
    func testSearchIgnoresAccents() {
        let (sut, _) = LocalBookmarkManager.manager {
            Bookmark(id: "1", url: "www.coffee.com", title: "Mi café favorito", isFavorite: true)
            Bookmark(id: "1", url: "www.coffee.com", title: "Mi cafe favorito", isFavorite: true)
        }

        let resultsWithoutAccent = sut.search(by: "cafe")
        let resultsWithAccent = sut.search(by: "café")

        XCTAssertTrue(resultsWithoutAccent.count == 2)
        XCTAssertTrue(resultsWithAccent.count == 2)
    }

    @MainActor
    func testWhenASearchIsDoneWithoutAccenttsThenItMatchesBookmarksWithoutAccent() {
        let (sut, _) = LocalBookmarkManager.manager {
            Bookmark(id: "1", url: "www.coffee.com", title: "Mi café favorito", isFavorite: true)
        }

        let results = sut.search(by: "cafe")

        XCTAssertTrue(results.count == 1)
    }

    @MainActor
    func testWhenBookmarkHasASymbolThenItsIgnoredWhenSearching() {
        let (sut, _) = LocalBookmarkManager.manager {
            Bookmark(id: "1", url: "www.test.com", title: "Site • Login", isFavorite: true)
        }

        let results = sut.search(by: "site login")

        XCTAssertTrue(results.count == 1)
    }

    @MainActor
    func testSearchQueryHasASymbolThenItsIgnoredWhenSearching() {
        let (sut, _) = LocalBookmarkManager.manager {
            Bookmark(id: "1", url: "www.test.com", title: "Site Login", isFavorite: true)
        }

        let results = sut.search(by: "site • login")

        XCTAssertTrue(results.count == 1)
    }

    @BookmarksBuilder
    private func topLevelBookmarks() -> [BookmarksBuilderItem] {
        folder(id: "2", "This is a folder") {
            folder(id: "1", "This is a sub-folder") {
                Bookmark(id: "3", url: "www.ddg.com", title: "This is a bookmark", isFavorite: false)
            }
        }
        folder(id: "5", "Favorite folder") {
            Bookmark(id: "4", url: "www.favorite.com", title: "Favorite bookmark", isFavorite: true)
        }
    }
}

fileprivate extension LocalBookmarkManager {

    static var context: NSManagedObjectContext!

    static var aManager: (LocalBookmarkManager, BookmarkStoreMock) {
        manager(with: {})
    }

    @MainActor
    private static func makeManager(@BookmarksBuilder with bookmarks: () -> [BookmarksBuilderItem]) -> (LocalBookmarkManager, BookmarkStoreMock) {
        let bookmarkStoreMock = BookmarkStoreMock(contextProvider: { Self.context }, bookmarks: bookmarks().build())
        let faviconManagerMock = FaviconManagerMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconManagement: faviconManagerMock)

        return (bookmarkManager, bookmarkStoreMock)
    }

    @MainActor(unsafe)
    static func manager(loadBookmarks: Bool = true, @BookmarksBuilder with bookmarks: () -> [BookmarksBuilderItem]) -> (LocalBookmarkManager, BookmarkStoreMock) {
        let (bookmarkManager, bookmarkStoreMock) = makeManager(with: bookmarks)
        if loadBookmarks {
            bookmarkManager.loadBookmarks()
            while bookmarkManager.list == nil {
                RunLoop.main.run(until: Date() + 0.001)
            }
        }
        return (bookmarkManager, bookmarkStoreMock)
    }

    @MainActor
    static func manager(loadBookmarks: Bool = true, @BookmarksBuilder with bookmarks: () -> [BookmarksBuilderItem]) async -> (LocalBookmarkManager, BookmarkStoreMock) {
        let (bookmarkManager, bookmarkStoreMock) = makeManager(with: bookmarks)
        if loadBookmarks {
            bookmarkManager.loadBookmarks()
            while bookmarkManager.list == nil {
                try? await Task.sleep(interval: 0.001)
            }
        }
        return (bookmarkManager, bookmarkStoreMock)
    }

}

fileprivate extension Bookmark {

    static var aBookmark: Bookmark = Bookmark(id: UUID().uuidString,
                                              url: URL.duckDuckGo.absoluteString,
                                              title: "Title",
                                              isFavorite: false)
    convenience init(_ url: URL, isFavorite: Bool = false, parentId: String? = nil) {
        self.init(id: UUID().uuidString, url: url.absoluteString, title: url.absoluteString.dropping(prefix: url.navigationalScheme?.separated() ?? ""), isFavorite: isFavorite)
    }
}
fileprivate extension BookmarkFolder {
    convenience init(_ title: String) {
        self.init(id: UUID().uuidString, title: title)
    }
}

fileprivate extension BaseBookmarkEntity {

    func matchesBookmark(withTitle title: String, url: URL, isFavorite: Bool, parent: String? = nil) -> Bool {
        guard let bookmark = self as? Bookmark else { return false }
        return bookmark.title == title && bookmark.url == url.absoluteString && bookmark.isFavorite == isFavorite && bookmark.parentFolderUUID == parent
    }

    func matchesBookmark(withTitle title: String, url: URL, isFavorite: Bool, parent: BookmarkFolder? = nil) -> Bool {
        matchesBookmark(withTitle: title, url: url, isFavorite: isFavorite, parent: parent?.id)
    }

    func matches(_ entity: BaseBookmarkEntity) -> Bool {
        switch self {
        case let bookmark as Bookmark:
            return matchesBookmark(withTitle: bookmark.title, url: URL(string: bookmark.url)!, isFavorite: bookmark.isFavorite, parent: bookmark.parentFolderUUID)
        case let folder as BookmarkFolder:
            return matchesFolder(withTitle: folder.title, parent: folder.parentFolderUUID)
        default:
            fatalError("Unexpected entity type \(entity)")
        }
    }

    func matchesFolder(withTitle title: String, parent: String? = nil) -> Bool {
        guard self.isFolder else { return false }
        return self.title == title && self.parentFolderUUID == parent
    }

    func matchesFolder(withTitle title: String, parent: BookmarkFolder? = nil) -> Bool {
        matchesFolder(withTitle: title, parent: parent?.id)
    }

    func matches(_ folder: BookmarkFolder) -> Bool {
        matchesFolder(withTitle: folder.title, parent: folder.parentFolderUUID)
    }

}

protocol BookmarksBuilderItem {
    func build(withParentId parentId: String?) -> BaseBookmarkEntity
}
extension BookmarksBuilderItem {
    func build() -> BaseBookmarkEntity {
        build(withParentId: nil)
    }
}
extension Bookmark: BookmarksBuilderItem {
    func build(withParentId parentId: String?) -> BaseBookmarkEntity {
        Bookmark(id: id, url: url, title: title, isFavorite: isFavorite, parentFolderUUID: parentId, faviconManagement: faviconManagement)
    }
}
extension BookmarkFolder: BookmarksBuilderItem {
    func build(withParentId parentId: String?) -> BaseBookmarkEntity {
        BookmarkFolder(id: id, title: title, parentFolderUUID: parentId, children: children)
    }
}
private typealias BookmarksBuilder = ArrayBuilder<BookmarksBuilderItem>
private indirect enum BookmarksBuilderItemMock: BookmarksBuilderItem {
    case bookmark(id: String = UUID().uuidString, title: String, url: URL, isFavorite: Bool = false)
    case folder(id: String = UUID().uuidString, title: String, items: [BookmarksBuilderItem])

    func build(withParentId parentId: String? = nil) -> BaseBookmarkEntity {
        switch self {
        case let .bookmark(id: id, title: title, url: url, isFavorite: isFavorite):
            Bookmark(id: id, url: url.absoluteString, title: title, isFavorite: isFavorite, parentFolderUUID: parentId)
        case let .folder(id: id, title: title, items: items):
            BookmarkFolder(id: id, title: title, parentFolderUUID: parentId, children: items.build(withParentId: id))
        }
    }
}
private extension LocalBookmarkManagerTests {
    func bookmark(_ id: String, _ url: URL, isFavorite: Bool = false) -> BookmarksBuilderItem {
        return BookmarksBuilderItemMock.bookmark(id: id, title: url.absoluteString.dropping(prefix: url.navigationalScheme?.separated() ?? ""), url: url, isFavorite: isFavorite)
    }
    func bookmark(_ url: URL, isFavorite: Bool = false) -> BookmarksBuilderItem {
        return BookmarksBuilderItemMock.bookmark(title: url.absoluteString.dropping(prefix: url.navigationalScheme?.separated() ?? ""), url: url, isFavorite: isFavorite)
    }
    func folder(id: String = UUID().uuidString, _ title: String, @BookmarksBuilder items: () -> [BookmarksBuilderItem]) -> BookmarksBuilderItem {
        BookmarksBuilderItemMock.folder(id: id, title: title, items: items())
    }
    func folder(id: String = UUID().uuidString, _ title: String) -> BookmarksBuilderItem {
        BookmarksBuilderItemMock.folder(id: id, title: title, items: [])
    }
    func assertEqual(_ lhs: [(entity: BaseBookmarkEntity, index: Int?)]?, _ rhs: [(entity: BaseBookmarkEntity, index: Int?)]?, file: StaticString = #file, line: UInt = #line) {
        if lhs == nil, rhs == nil { return }
        var overviewPrinted = false
        func fail(_ message: String) {
            if !overviewPrinted {
                overviewPrinted = true
                XCTFail("\(lhs.map { "\($0)" } ?? "<nil>")\n  is not equal to\n\(rhs.map { "\($0)" } ?? "<nil>")", file: file, line: line)
            }
            XCTFail(message, file: file, line: line)
        }
        guard let lhs else { return fail("<nil> is not equal to \(rhs!)") }
        guard let rhs else { return fail("\(lhs) is not equal to <nil>") }
        for idx in 0..<max(lhs.endIndex, rhs.endIndex) {
            guard let lhsItem = lhs[safe: idx] else {
                fail("#\(idx): <nil> is not equal to \(rhs[idx])")
                continue
            }
            guard let rhsItem = rhs[safe: idx] else {
                fail("#\(idx): \(lhsItem) is not equal to <nil>")
                continue
            }
            switch (lhsItem.entity.matches(rhsItem.entity), lhsItem.index == rhsItem.index) {
            case (true, true): continue
            case (true, false): fail("#\(idx): index \(lhsItem.index.map(String.init) ?? "<nil>") != \(rhsItem.index.map(String.init) ?? "<nil>")")
            case (false, true): fail("#\(idx): \(lhsItem.entity) != \(rhsItem.entity)")
            case (false, false): fail("#\(idx): \(lhsItem.entity) at \(lhsItem.index.map(String.init) ?? "<nil>") != \(rhsItem.entity) at \(rhsItem.index.map(String.init) ?? "<nil>")")
            }
        }
    }
}

extension [BookmarksBuilderItem] {
    func build(withParentId parentId: String? = nil) -> [BaseBookmarkEntity] {
        self.map { $0.build() }
    }
}

private extension WebsiteInfo {

    @MainActor
    init?(url: URL, title: String) {
        let tab = Tab(content: .url(url, credential: nil, source: .ui))
        tab.title = title
        self.init(tab)
    }

}
