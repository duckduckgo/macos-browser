//
//  BookmarkListTests.swift
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

final class BookmarkListTests: XCTestCase {

    func testWhenBookmarkIsInserted_ThenItIsPartOfTheList() throws {
        var bookmarkList = BookmarkList()

        let bookmark = Bookmark.aBookmark
        bookmarkList.insert(bookmark)

        let result = try XCTUnwrap(bookmarkList[bookmark.url])
        XCTAssert(bookmarkList.bookmarks().count == 1)
        XCTAssert((bookmarkList.bookmarks()).first == bookmark.identifiableBookmark)
        XCTAssertEqual(result.id, bookmark.id)
        XCTAssertEqual(result.title, bookmark.title)
        XCTAssertEqual(result.url, bookmark.url)
        XCTAssertEqual(result.isFavorite, bookmark.isFavorite)
        XCTAssertEqual(result.parentFolderUUID, bookmark.parentFolderUUID)
    }

    func testWhenBookmarkIsAlreadyPartOfTheListInserted_ThenItCantBeInserted() {
        var bookmarkList = BookmarkList()

        let bookmark = Bookmark.aBookmark
        bookmarkList.insert(bookmark)
        bookmarkList.insert(bookmark)

        XCTAssert(bookmarkList.bookmarks().count == 1)
        XCTAssert(bookmarkList.bookmarks().first == bookmark.identifiableBookmark)
    }

    func testWhenBookmarkIsRemoved_ThenItIsNoLongerInList() {
        var bookmarkList = BookmarkList()

        let bookmark = Bookmark.aBookmark
        bookmarkList.insert(bookmark)

        bookmarkList.remove(bookmark)

        XCTAssertFalse(bookmarkList.bookmarks().contains(bookmark.identifiableBookmark))
        XCTAssertNil(bookmarkList[bookmark.url])
    }

    func testWhenBookmarkIsUpdatedInTheList_ThenListContainsChangedVersion() {
        var bookmarkList = BookmarkList()

        let bookmark = Bookmark.aBookmark
        bookmarkList.insert(bookmark)

        let newIsFavoriteValue = !bookmark.isFavorite
        bookmark.isFavorite = newIsFavoriteValue
        bookmarkList.update(with: bookmark)

        XCTAssert(bookmarkList[bookmark.url]?.isFavorite == newIsFavoriteValue)
    }

    func testWhenUpdateIsCalledWithUnknownBookmark_ThenTheListRemainsUnchanged() {
        var bookmarkList = BookmarkList()

        let bookmark = Bookmark.aBookmark
        bookmarkList.insert(bookmark)

        let unknownBookmark = Bookmark(id: UUID().uuidString,
                                       url: URL.duckDuckGoAutocomplete.absoluteString,
                                       title: "Unknown title",
                                       isFavorite: true)

        bookmarkList.update(with: unknownBookmark)
        let updateUrlResult = bookmarkList.updateUrl(of: unknownBookmark, to: URL.duckDuckGo.absoluteString)

        XCTAssert(bookmarkList[bookmark.url]?.isFavorite == bookmark.isFavorite)
        XCTAssert(bookmarkList[bookmark.url]?.title == bookmark.title)
        XCTAssert(bookmarkList.bookmarks().count == 1)
        XCTAssert(bookmarkList.bookmarks().first == bookmark.identifiableBookmark)
        XCTAssertNotNil(bookmarkList[bookmark.url])
        XCTAssertNil(bookmarkList[unknownBookmark.url])
        XCTAssertNil(updateUrlResult)
    }

    func testWhenBookmarkUrlIsUpdated_ThenJustTheBookmarkUrlIsUpdated() throws {
        var bookmarkList = BookmarkList()

        let bookmarks = [
            Bookmark(id: UUID().uuidString, url: "wikipedia.org", title: "Title", isFavorite: true),
            Bookmark(id: UUID().uuidString, url: URL.duckDuckGo.absoluteString, title: "Title", isFavorite: true),
            Bookmark(id: UUID().uuidString, url: "apple.com", title: "Title", isFavorite: true)
        ]
        bookmarks.forEach { bookmarkList.insert($0) }
        let bookmarkToReplace = bookmarks[2]

        let newBookmark = try XCTUnwrap(bookmarkList.updateUrl(of: bookmarkToReplace, to: URL.duckDuckGoAutocomplete.absoluteString))

        let result = try XCTUnwrap(bookmarkList[newBookmark.url])
        XCTAssert(bookmarkList.bookmarks().count == bookmarks.count)
        XCTAssertNil(bookmarkList[bookmarkToReplace.url])
        XCTAssertEqual(result.title, "Title")
        XCTAssertEqual(result.url, URL.duckDuckGoAutocomplete.absoluteString)
        XCTAssertTrue(result.isFavorite)
    }

    func testWhenBookmarkUrlIsUpdatedToAlreadyBookmarkedUrl_ThenUpdatingMustFail() {
        var bookmarkList = BookmarkList()

        let firstUrl = URL(string: "http://wikipedia.org")!
        let bookmarks = [
            Bookmark(id: UUID().uuidString, url: firstUrl.absoluteString, title: "Title", isFavorite: true),
            Bookmark(id: UUID().uuidString, url: URL.duckDuckGo.absoluteString, title: "Title", isFavorite: true)
        ]

        bookmarks.forEach { bookmarkList.insert($0) }

        let bookmarkToReplace = bookmarks[1]
        let newBookmark = bookmarkList.updateUrl(of: bookmarkToReplace, to: firstUrl.absoluteString)

        XCTAssert(bookmarkList.bookmarks().count == bookmarks.count)
        XCTAssertNotNil(bookmarkList[firstUrl.absoluteString])
        XCTAssertEqual(bookmarkList[firstUrl.absoluteString]?.url, firstUrl.absoluteString)
        XCTAssertNotNil(bookmarkList[bookmarkToReplace.url])
        XCTAssertEqual(bookmarkList[bookmarkToReplace.url]?.url, URL.duckDuckGo.absoluteString)
        XCTAssertNil(newBookmark)
    }

    func testWhenBookmarkURLTitleAndIsFavoriteIsUpdated_ThenURLTitleAndIsFavoriteIsUpdated() throws {
        // GIVEN
        var bookmarkList = BookmarkList()
        let bookmarks = [
            Bookmark(id: UUID().uuidString, url: "wikipedia.org", title: "Wikipedia", isFavorite: true),
            Bookmark(id: UUID().uuidString, url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: true),
            Bookmark(id: UUID().uuidString, url: "apple.com", title: "Apple", isFavorite: true)
        ]
        bookmarks.forEach { bookmarkList.insert($0) }
        let bookmarkToReplace = bookmarks[2]
        XCTAssertEqual(bookmarkList.bookmarks().count, bookmarks.count)
        XCTAssertEqual(bookmarkList["wikipedia.org"]?.url, "wikipedia.org")
        XCTAssertEqual(bookmarkList["wikipedia.org"]?.title, "Wikipedia")
        XCTAssertEqual(bookmarkList["wikipedia.org"]?.isFavorite, true)
        XCTAssertEqual(bookmarkList[URL.duckDuckGo.absoluteString]?.url, URL.duckDuckGo.absoluteString)
        XCTAssertEqual(bookmarkList[URL.duckDuckGo.absoluteString]?.title, "DDG")
        XCTAssertEqual(bookmarkList[URL.duckDuckGo.absoluteString]?.isFavorite, true)
        XCTAssertEqual(bookmarkList["apple.com"]?.url, "apple.com")
        XCTAssertEqual(bookmarkList["apple.com"]?.title, "Apple")
        XCTAssertEqual(bookmarkList["apple.com"]?.isFavorite, true)

        // WHEN
        let newBookmark = try XCTUnwrap(bookmarkList.update(bookmark: bookmarkToReplace, newURL: "www.example.com", newTitle: "Example", newIsFavorite: false))

        // THEN
        let result = try XCTUnwrap(bookmarkList[newBookmark.url])
        XCTAssertEqual(bookmarkList.bookmarks().count, bookmarks.count)
        XCTAssertNil(bookmarkList[bookmarkToReplace.url])
        XCTAssertEqual(bookmarkList["wikipedia.org"]?.url, "wikipedia.org")
        XCTAssertEqual(bookmarkList["wikipedia.org"]?.title, "Wikipedia")
        XCTAssertEqual(bookmarkList["wikipedia.org"]?.isFavorite, true)
        XCTAssertEqual(bookmarkList[URL.duckDuckGo.absoluteString]?.url, URL.duckDuckGo.absoluteString)
        XCTAssertEqual(bookmarkList[URL.duckDuckGo.absoluteString]?.title, "DDG")
        XCTAssertEqual(bookmarkList[URL.duckDuckGo.absoluteString]?.isFavorite, true)
        XCTAssertEqual(result.url, "www.example.com")
        XCTAssertEqual(result.title, "Example")
        XCTAssertEqual(result.isFavorite, false)
    }

    func testWhenBookmarkIsInserted_ThenLowercasedItemsDictContainsLowercasedKey() {
        var bookmarkList = BookmarkList()

        let bookmark = Bookmark.aCaseSensitiveBookmark
        bookmarkList.insert(bookmark)

        let lowercasedKey = bookmark.url.lowercased()
        let items = bookmarkList.lowercasedItemsDict[lowercasedKey]

        XCTAssertNotNil(items)
        XCTAssertEqual(items?.count, 1)
        XCTAssertEqual(items?.first?.id, bookmark.id)
    }

    func testWhenBookmarkIsRemoved_ThenLowercasedItemsDictDoesNotContainBookmark() {
        var bookmarkList = BookmarkList()

        let bookmark = Bookmark.aCaseSensitiveBookmark
        bookmarkList.insert(bookmark)

        bookmarkList.remove(bookmark)

        let lowercasedKey = bookmark.url.lowercased()
        let items = bookmarkList.lowercasedItemsDict[lowercasedKey]

        XCTAssertNil(items)
    }

    func testWhenBookmarkUrlIsUpdated_ThenLowercasedItemsDictReflectsUpdatedUrl() throws {
        var bookmarkList = BookmarkList()

        let bookmark = Bookmark.aCaseSensitiveBookmark
        bookmarkList.insert(bookmark)

        let newURL = "www.example.com"
        let updatedBookmark = try XCTUnwrap(bookmarkList.updateUrl(of: bookmark, to: newURL))

        let originalKey = bookmark.url.lowercased()
        let newKey = newURL.lowercased()

        XCTAssertEqual(bookmarkList.lowercasedItemsDict[originalKey], [])
        XCTAssertNotNil(bookmarkList.lowercasedItemsDict[newKey])

        let items = bookmarkList.lowercasedItemsDict[newKey]
        XCTAssertEqual(items?.count, 1)
        XCTAssertEqual(items?.first?.id, updatedBookmark.id)
        XCTAssertEqual(items?.first?.url, updatedBookmark.url)
    }

    func testWhenBookmarkIsUpdatedWithNewTitleAndFavoriteStatus_ThenLowercasedItemsDictPreservesKey() {
        var bookmarkList = BookmarkList()

        let bookmark = Bookmark.aCaseSensitiveBookmark
        bookmarkList.insert(bookmark)

        let newTitle = "Updated Title"
        let newIsFavorite = !bookmark.isFavorite
        let updatedBookmark = bookmarkList.update(bookmark: bookmark, newURL: bookmark.url, newTitle: newTitle, newIsFavorite: newIsFavorite)

        let lowercasedKey = bookmark.url.lowercased()
        let items = bookmarkList.lowercasedItemsDict[lowercasedKey]

        XCTAssertNotNil(items)
        XCTAssertEqual(items?.count, 1)
        XCTAssertEqual(items?.first?.id, updatedBookmark?.id)
        XCTAssertEqual(items?.first?.title, newTitle)
        XCTAssertEqual(items?.first?.isFavorite, newIsFavorite)
    }

    func testWhenMultipleBookmarksWithSameURLDifferentCasesAreInserted_ThenLowercasedItemsDictContainsOneOfThem() {
        var bookmarkList = BookmarkList()

        let bookmark1 = Bookmark(id: UUID().uuidString, url: "www.Example.com", title: "Example 1", isFavorite: true)
        let bookmark2 = Bookmark(id: UUID().uuidString, url: "www.example.COM", title: "Example 2", isFavorite: false)

        bookmarkList.insert(bookmark1)
        bookmarkList.insert(bookmark2)

        let lowercasedKey = "www.example.com"
        let items = bookmarkList.lowercasedItemsDict[lowercasedKey]

        XCTAssertNotNil(items)
        XCTAssert(items?.contains(where: { $0.id == bookmark1.id || $0.id == bookmark2.id}) ?? false)
    }

}

fileprivate extension Bookmark {

    @MainActor(unsafe)
    static var aBookmark: Bookmark = Bookmark(id: UUID().uuidString,
                                              url: URL.duckDuckGo.absoluteString,
                                              title: "Title",
                                              isFavorite: false,
                                              faviconManagement: FaviconManagerMock())

    @MainActor(unsafe)
    static var aCaseSensitiveBookmark: Bookmark = Bookmark(id: UUID().uuidString,
                                              url: "www.DuckDuckGo.com",
                                              title: "Title",
                                              isFavorite: false,
                                              faviconManagement: FaviconManagerMock())

    var identifiableBookmark: BookmarkList.IdentifiableBookmark {
        return BookmarkList.IdentifiableBookmark(from: self)
    }

}
