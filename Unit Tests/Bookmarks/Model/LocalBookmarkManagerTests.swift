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

import Foundation

import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class LocalBookmarkManagerTests: XCTestCase {

    enum BookmarkManagerError: Error {
        case somethingReallyBad
    }

    func testWhenBookmarksAreNotLoadedYet_ThenManagerIgnoresBookmarkingRequests() {
        let bookmarkStoreMock = BookmarkStoreMock()
        let faviconServiceMock = FaviconServiceMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconService: faviconServiceMock)

        XCTAssertNil(bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Test", favicon: nil, isFavorite: false))
        XCTAssertNil(bookmarkManager.updateUrl(of: Bookmark.aBookmark, to: URL.duckDuckGoAutocomplete))
    }

    func testWhenBookmarksAreLoaded_ThenTheManagerHoldsAllLoadedBookmarks() {
        let bookmarkStoreMock = BookmarkStoreMock()
        let faviconServiceMock = FaviconServiceMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconService: faviconServiceMock)

        bookmarkStoreMock.bookmarks = [Bookmark.aBookmark]
        bookmarkManager.loadBookmarks()

        XCTAssert(bookmarkManager.isUrlBookmarked(url: Bookmark.aBookmark.url))
        XCTAssertNotNil(bookmarkManager.getBookmark(for: Bookmark.aBookmark.url))
        XCTAssert(bookmarkStoreMock.loadAllCalled)
        XCTAssert(bookmarkManager.list!.bookmarks().count > 0)
    }

    func testWhenLoadFails_ThenTheManagerHoldsBookmarksAreNil() {
        let bookmarkStoreMock = BookmarkStoreMock()
        let faviconServiceMock = FaviconServiceMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconService: faviconServiceMock)

        bookmarkStoreMock.bookmarks = nil
        bookmarkStoreMock.loadError = BookmarkManagerError.somethingReallyBad
        bookmarkManager.loadBookmarks()

        XCTAssertNil(bookmarkManager.list?.bookmarks())
        XCTAssert(bookmarkStoreMock.loadAllCalled)
    }

    func testWhenBookmarkIsCreated_ThenManagerSavesItToStore() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager

        let objectId = NSManagedObjectID()
        bookmarkStoreMock.managedObjectId = objectId
        let bookmark = bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Title", favicon: nil, isFavorite: false)!

        XCTAssert(bookmarkManager.isUrlBookmarked(url: bookmark.url))
        XCTAssert(bookmarkManager.getBookmark(for: bookmark.url)?.managedObjectId == objectId)
        XCTAssert(bookmarkStoreMock.saveCalled)
    }

    func testWhenBookmarkIsCreatedAndStoringFails_ThenManagerRemovesItFromList() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager

        bookmarkStoreMock.saveSuccess = false
        let bookmark = bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Title", favicon: nil, isFavorite: false)!

        XCTAssertFalse(bookmarkManager.isUrlBookmarked(url: bookmark.url))
        XCTAssert(bookmarkStoreMock.saveCalled)
    }

    func testWhenUrlIsAlreadyBookmarked_ThenManagerReturnsNil() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager

        let objectId = NSManagedObjectID()
        bookmarkStoreMock.managedObjectId = objectId
        _ = bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Title", favicon: nil, isFavorite: false)!

        XCTAssertNil(bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Title", favicon: nil, isFavorite: false))
    }

    func testWhenBookmarkIsRemoved_ThenManagerRemovesItFromStore() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager

        let objectId = NSManagedObjectID()
        bookmarkStoreMock.managedObjectId = objectId
        let bookmark = bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Title", favicon: nil, isFavorite: false)!

        bookmarkManager.remove(bookmark: bookmark)

        XCTAssertFalse(bookmarkManager.isUrlBookmarked(url: bookmark.url))
        XCTAssert(bookmarkStoreMock.saveCalled)
        XCTAssert(bookmarkStoreMock.removeCalled)
    }

    func testWhenRemovalFails_ThenManagerPutsBookmarkBackToList() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager

        let objectId = NSManagedObjectID()
        bookmarkStoreMock.managedObjectId = objectId
        let bookmark = bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Title", favicon: nil, isFavorite: false)!

        bookmarkStoreMock.removeSuccess = false
        bookmarkStoreMock.removeError = BookmarkManagerError.somethingReallyBad
        bookmarkManager.remove(bookmark: bookmark)

        XCTAssert(bookmarkManager.isUrlBookmarked(url: bookmark.url))
        XCTAssert(bookmarkStoreMock.saveCalled)
        XCTAssert(bookmarkStoreMock.removeCalled)
    }

    func testWhenBookmarkNoLongerExist_ThenManagerIgnoresAttemtToRemoval() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager

        bookmarkManager.remove(bookmark: Bookmark.aBookmark)

        XCTAssertFalse(bookmarkManager.isUrlBookmarked(url: Bookmark.aBookmark.url))
        XCTAssertFalse(bookmarkStoreMock.removeCalled)
    }

    func testWhenBookmarkNoLongerExist_ThenManagerIgnoresAttemtToUpdate() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager

        bookmarkManager.update(bookmark: Bookmark.aBookmark)
        let updateUrlResult = bookmarkManager.updateUrl(of: Bookmark.aBookmark, to: URL.duckDuckGoAutocomplete)

        XCTAssertFalse(bookmarkManager.isUrlBookmarked(url: Bookmark.aBookmark.url))
        XCTAssertFalse(bookmarkStoreMock.updateCalled)
        XCTAssertNil(updateUrlResult)
    }

    func testWhenBookmarkIsUpdated_ThenManagerUpdatesItInStore() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager

        let objectId = NSManagedObjectID()
        bookmarkStoreMock.managedObjectId = objectId
        var bookmark = bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Title", favicon: nil, isFavorite: false)!

        bookmark.isFavorite = !bookmark.isFavorite
        bookmarkManager.update(bookmark: bookmark)

        XCTAssert(bookmarkManager.isUrlBookmarked(url: bookmark.url))
        XCTAssert(bookmarkStoreMock.updateCalled)
    }

    func testWhenBookmarkUrlIsUpdated_ThenManagerUpdatesItAlsoInStore() {
        let (bookmarkManager, bookmarkStoreMock) = LocalBookmarkManager.aManager

        let objectId = NSManagedObjectID()
        bookmarkStoreMock.managedObjectId = objectId
        var bookmark = bookmarkManager.makeBookmark(for: URL.duckDuckGo, title: "Title", favicon: nil, isFavorite: false)!

        bookmark.isFavorite = !bookmark.isFavorite

        let newURL = URL.duckDuckGoAutocomplete
        let newBookmark = bookmarkManager.updateUrl(of: bookmark, to: newURL)

        XCTAssertFalse(bookmarkManager.isUrlBookmarked(url: bookmark.url))
        XCTAssert(bookmarkManager.isUrlBookmarked(url: newBookmark!.url))
        XCTAssert(bookmarkManager.isUrlBookmarked(url: newURL))
        XCTAssert(bookmarkStoreMock.updateCalled)
    }

    func testWhenNewFaviconIsCached_ThenManagerUpdatesItAlsoInStore() {
        let bookmarkStoreMock = BookmarkStoreMock()
        let faviconServiceMock = FaviconServiceMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconService: faviconServiceMock)

        bookmarkStoreMock.bookmarks = [Bookmark.aBookmark]
        bookmarkManager.loadBookmarks()

        let newFavicon = NSImage(named: "HomeFavicon")!
        faviconServiceMock.cachedFaviconsPublisher.send((URL.duckDuckGo.host!, newFavicon))

        XCTAssert(bookmarkStoreMock.updateCalled)
        XCTAssert(bookmarkManager.getBookmark(for: URL.duckDuckGo)?.favicon == newFavicon)
    }

}

fileprivate extension LocalBookmarkManager {

    static var aManager: (LocalBookmarkManager, BookmarkStoreMock) {
        let bookmarkStoreMock = BookmarkStoreMock()
        let faviconServiceMock = FaviconServiceMock()
        let bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconService: faviconServiceMock)

        bookmarkStoreMock.bookmarks = []
        bookmarkManager.loadBookmarks()

        return (bookmarkManager, bookmarkStoreMock)
    }

}

fileprivate extension Bookmark {

    static var aBookmark: Bookmark = Bookmark(url: URL.duckDuckGo, title: "Title", favicon: nil, isFavorite: false, managedObjectId: nil)

}
