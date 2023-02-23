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

}

fileprivate extension LocalBookmarkManager {

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
