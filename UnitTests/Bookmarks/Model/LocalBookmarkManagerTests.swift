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

import Combine
import Foundation

import XCTest
@testable import DuckDuckGo_Privacy_Browser

@MainActor
final class LocalBookmarkManagerTests: XCTestCase {

    enum BookmarkManagerError: Error {
        case somethingReallyBad
    }

    func testWhenBookmarksAreNotLoadedYet_ThenManagerIgnoresBookmarkingRequests() {
        let bookmarkStoreMock = BookmarkStoreMock()
        let faviconManagerMock = FaviconManagerMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconManagement: faviconManagerMock)

        XCTAssertNil(bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Test", isFavorite: false))
        XCTAssertNil(bookmarkManager.updateUrl(of: Bookmark.aBookmark, to: URL.duckDuckGoAutocomplete))
    }

    func testWhenBookmarksAreLoaded_ThenTheManagerHoldsAllLoadedBookmarks() {
        let bookmarkStoreMock = BookmarkStoreMock()
        let faviconManagerMock = FaviconManagerMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconManagement: faviconManagerMock)

        bookmarkStoreMock.bookmarks = [Bookmark.aBookmark]
        bookmarkManager.loadBookmarks()

        XCTAssert(bookmarkManager.isUrlBookmarked(url: Bookmark.aBookmark.urlObject!))
        XCTAssertNotNil(bookmarkManager.getBookmark(for: Bookmark.aBookmark.urlObject!))
        XCTAssert(bookmarkStoreMock.loadAllCalled)
        XCTAssert(bookmarkManager.list!.bookmarks().count > 0)
    }

    func testWhenLoadFails_ThenTheManagerHoldsBookmarksAreNil() {
        let bookmarkStoreMock = BookmarkStoreMock()
        let faviconManagerMock = FaviconManagerMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconManagement: faviconManagerMock)

        bookmarkStoreMock.bookmarks = nil
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

    func testWhenBookmarkIsRemoved_ThenManagerRemovesItFromStore() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager
        let bookmark = bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Title", isFavorite: false)!

        bookmarkManager.remove(bookmark: bookmark)

        XCTAssertFalse(bookmarkManager.isUrlBookmarked(url: bookmark.urlObject!))
        XCTAssert(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssert(bookmarkStoreMock.removeCalled)
    }

    func testWhenRemovalFails_ThenManagerPutsBookmarkBackToList() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager
        let bookmark = bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Title", isFavorite: false)!

        bookmarkStoreMock.removeSuccess = false
        bookmarkStoreMock.removeError = BookmarkManagerError.somethingReallyBad
        bookmarkManager.remove(bookmark: bookmark)

        XCTAssert(bookmarkManager.isUrlBookmarked(url: bookmark.urlObject!))
        XCTAssert(bookmarkStoreMock.saveBookmarkCalled)
        XCTAssert(bookmarkStoreMock.removeCalled)
    }

    func testWhenBookmarkNoLongerExist_ThenManagerIgnoresAttemptToRemoval() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager

        bookmarkManager.remove(bookmark: Bookmark.aBookmark)

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
        let newBookmark = bookmarkManager.updateUrl(of: bookmark, to: newURL)

        XCTAssertFalse(bookmarkManager.isUrlBookmarked(url: bookmark.urlObject!))
        XCTAssert(bookmarkManager.isUrlBookmarked(url: newBookmark!.urlObject!))
        XCTAssert(bookmarkManager.isUrlBookmarked(url: newURL))
        XCTAssert(bookmarkStoreMock.updateBookmarkCalled)
    }

    func testWhenBookmarkFolderIsUpdatedAndMoved_ThenManagerUpdatesItAlsoInStore() throws {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager
        let parent = BookmarkFolder(id: "1", title: "Parent")
        let folder = BookmarkFolder(id: "2", title: "Child")
        var bookmarkList: BookmarkList?
        let cancellable = bookmarkManager.listPublisher
            .dropFirst()
            .sink { list in
            bookmarkList = list
        }

        bookmarkManager.update(folder: folder, andMoveToParent: .parent(uuid: parent.id))

        withExtendedLifetime(cancellable) {}
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
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager
        let folder = BookmarkFolder(id: "1", title: "Test")
        bookmarkStoreMock.bookmarkFolder = folder

        // WHEN
        let result = bookmarkManager.getBookmarkFolder(withId: #function)

        // THEN
        XCTAssertEqual(result, folder)
    }

    func testWhenGetBookmarkFolderIsCalledAndFolderDoesNotExistInStoreThenBookmarkStoreReturnsNil() throws {
        // GIVEN
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager
        bookmarkStoreMock.bookmarkFolder = nil

        // WHEN
        let result = bookmarkManager.getBookmarkFolder(withId: #function)

        // THEN
        XCTAssertNil(result)
    }

    // MARK: - Save Multiple Bookmarks at once

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

    func testWhenASearchIsDoneThenCorrectResultsAreReturnedAndIntheRightOrder() {
        let bookmarkStore = BookmarkStoreMock(bookmarks: topLevelBookmarks())
        let sut = LocalBookmarkManager(bookmarkStore: bookmarkStore, faviconManagement: FaviconManagerMock())

        sut.loadBookmarks()

        let results = sut.search(by: "folder")

        XCTAssertTrue(results.count == 3)
        XCTAssertEqual(results[0].title, "This is a folder")
        XCTAssertEqual(results[1].title, "Favorite folder")
        XCTAssertEqual(results[2].title, "This is a sub-folder")
    }

    func testWhenASearchIsDoneThenFoldersAndBookmarksAreReturned() {
        let bookmarkStore = BookmarkStoreMock(bookmarks: topLevelBookmarks())
        let sut = LocalBookmarkManager(bookmarkStore: bookmarkStore, faviconManagement: FaviconManagerMock())

        sut.loadBookmarks()

        let results = sut.search(by: "favorite")

        XCTAssertTrue(results.count == 2)
        XCTAssertEqual(results[0].title, "Favorite folder")
        XCTAssertTrue(results[0].isFolder)
        XCTAssertEqual(results[1].title, "Favorite bookmark")
        XCTAssertFalse(results[1].isFolder)
    }

    private func topLevelBookmarks() -> [BaseBookmarkEntity] {
        let topBookmark = Bookmark(id: "4", url: "www.favorite.com", title: "Favorite bookmark", isFavorite: true)
        let favoriteFolder = BookmarkFolder(id: "5", title: "Favorite folder", children: [topBookmark])
        let bookmark = Bookmark(id: "3", url: "www.ddg.com", title: "This is a bookmark", isFavorite: false)
        let subFolder = BookmarkFolder(id: "1", title: "This is a sub-folder", children: [bookmark])
        let parent = BookmarkFolder(id: "2", title: "This is a folder", children: [subFolder])

        return [parent, favoriteFolder]
    }
}

fileprivate extension LocalBookmarkManager {

    @MainActor(unsafe)
    static var aManager: (LocalBookmarkManager, BookmarkStoreMock) {
        let bookmarkStoreMock = BookmarkStoreMock()
        let faviconManagerMock = FaviconManagerMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconManagement: faviconManagerMock)

        bookmarkStoreMock.bookmarks = []
        bookmarkManager.loadBookmarks()

        return (bookmarkManager, bookmarkStoreMock)
    }

}

fileprivate extension Bookmark {

    static var aBookmark: Bookmark = Bookmark(id: UUID().uuidString,
                                              url: URL.duckDuckGo.absoluteString,
                                              title: "Title",
                                              isFavorite: false)

}

private extension WebsiteInfo {

    @MainActor
    init?(url: URL, title: String) {
        let tab = Tab(content: .url(url, credential: nil, source: .ui))
        tab.title = title
        self.init(tab)
    }

}
