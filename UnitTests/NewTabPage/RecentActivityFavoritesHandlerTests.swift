//
//  RecentActivityFavoritesHandlerTests.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class RecentActivityFavoritesHandlerTests: XCTestCase {
    var bookmarkStoreMock: BookmarkStoreMock!
    var handler: LocalBookmarkManager!

    @MainActor func makeHandler() {
        handler = LocalBookmarkManager(bookmarkStore: bookmarkStoreMock, faviconManagement: FaviconManagerMock())
        handler.loadBookmarks()
    }

    func testWhenURLIsBookmarkedThenBookmarkIsReturned() async throws {
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [
            Bookmark(id: "1", url: "https://example.com", title: "Example", isFavorite: false)
        ])
        await makeHandler()

        let url = try XCTUnwrap("https://example.com".url)

        XCTAssertNotNil(handler.getBookmark(for: url))
    }

    func testWhenURLIsNotBookmarkedThenBookmarkIsReturned() async throws {
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [])
        await makeHandler()

        let url = try XCTUnwrap("https://example.com".url)

        XCTAssertNil(handler.getBookmark(for: url))
    }

    func testWhenURLIsFavoritedThenFavoriteIsReturned() async throws {
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [
            Bookmark(id: "1", url: "https://example.com", title: "Example", isFavorite: true)
        ])
        await makeHandler()

        let url = try XCTUnwrap("https://example.com".url)

        XCTAssertNotNil(handler.getFavorite(for: url))
    }

    func testWhenURLIsNotFavoritedThenFavoriteIsReturned() async throws {
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [
            Bookmark(id: "1", url: "https://example.com", title: "Example", isFavorite: false)
        ])
        await makeHandler()

        let url = try XCTUnwrap("https://example.com".url)

        XCTAssertNil(handler.getFavorite(for: url))
    }

    func testWhenURLIsNotFavoritedThenMarkAsFavoriteSetsFavoriteFlag() async throws {
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [
            Bookmark(id: "1", url: "https://example.com", title: "Example", isFavorite: false)
        ])
        await makeHandler()

        let url = try XCTUnwrap("https://example.com".url)
        let bookmark = try XCTUnwrap(handler.getBookmark(for: url))

        handler.markAsFavorite(bookmark)
        XCTAssertTrue(bookmark.isFavorite)
    }

    func testWhenURLIsFavoritedThenMarkAsFavoriteHasNoEffect() async throws {
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [
            Bookmark(id: "1", url: "https://example.com", title: "Example", isFavorite: true)
        ])
        await makeHandler()

        let url = try XCTUnwrap("https://example.com".url)
        let bookmark = try XCTUnwrap(handler.getBookmark(for: url))

        handler.markAsFavorite(bookmark)
        XCTAssertTrue(bookmark.isFavorite)
    }

    func testWhenURLIsFavoritedThenUnmarkAsFavoriteClearsFavoriteFlag() async throws {
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [
            Bookmark(id: "1", url: "https://example.com", title: "Example", isFavorite: true)
        ])
        await makeHandler()

        let url = try XCTUnwrap("https://example.com".url)
        let bookmark = try XCTUnwrap(handler.getBookmark(for: url))

        handler.unmarkAsFavorite(bookmark)
        XCTAssertFalse(bookmark.isFavorite)
    }

    func testWhenURLIsNotFavoritedThenUnmarkAsFavoriteHasNoEffect() async throws {
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [
            Bookmark(id: "1", url: "https://example.com", title: "Example", isFavorite: false)
        ])
        await makeHandler()

        let url = try XCTUnwrap("https://example.com".url)
        let bookmark = try XCTUnwrap(handler.getBookmark(for: url))

        handler.unmarkAsFavorite(bookmark)
        XCTAssertFalse(bookmark.isFavorite)
    }

    func testThatAddNewFavoriteCreatesNewFavorite() async throws {
        bookmarkStoreMock = BookmarkStoreMock(bookmarks: [])
        await makeHandler()

        let url = try XCTUnwrap("https://example.com".url)

        handler.addNewFavorite(for: url)
        let bookmark = try XCTUnwrap(handler.getBookmark(for: url))
        XCTAssertTrue(bookmark.isFavorite)
        XCTAssertEqual(bookmark.urlObject, url)
    }
}
