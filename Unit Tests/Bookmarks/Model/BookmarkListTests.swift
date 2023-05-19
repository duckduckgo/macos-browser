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

    func testWhenBookmarkIsInserted_ThenItIsPartOfTheList() {
        var bookmarkList = BookmarkList()

        let bookmark = Bookmark.aBookmark
        bookmarkList.insert(bookmark)

        XCTAssert(bookmarkList.bookmarks().count == 1)
        XCTAssert((bookmarkList.bookmarks()).first == bookmark.identifiableBookmark)
        XCTAssertNotNil(bookmarkList[bookmark.url])
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

        let unknownBookmark = Bookmark(id: UUID(),
                                       url: URL.duckDuckGoAutocomplete,
                                       title: "Unknown title",
                                       isFavorite: true)

        bookmarkList.update(with: unknownBookmark)
        let updateUrlResult = bookmarkList.updateUrl(of: unknownBookmark, to: URL.duckDuckGo)

        XCTAssert(bookmarkList[bookmark.url]?.isFavorite == bookmark.isFavorite)
        XCTAssert(bookmarkList[bookmark.url]?.title == bookmark.title)
        XCTAssert(bookmarkList.bookmarks().count == 1)
        XCTAssert(bookmarkList.bookmarks().first == bookmark.identifiableBookmark)
        XCTAssertNotNil(bookmarkList[bookmark.url])
        XCTAssertNil(bookmarkList[unknownBookmark.url])
        XCTAssertNil(updateUrlResult)
    }

    func testWhenBookmarkUrlIsUpdated_ThenJustTheBookmarkUrlIsUpdated() {
        var bookmarkList = BookmarkList()

        let bookmarks = [
            Bookmark(id: UUID(), url: URL(string: "wikipedia.org")!, title: "Title", isFavorite: true),
            Bookmark(id: UUID(), url: URL.duckDuckGo, title: "Title", isFavorite: true),
            Bookmark(id: UUID(), url: URL(string: "apple.com")!, title: "Title", isFavorite: true)
        ]
        bookmarks.forEach { bookmarkList.insert($0) }
        let bookmarkToReplace = bookmarks[2]

        let newBookmark = bookmarkList.updateUrl(of: bookmarkToReplace, to: URL.duckDuckGoAutocomplete)

        XCTAssert(bookmarkList.bookmarks().count == bookmarks.count)
        XCTAssertNil(bookmarkList[bookmarkToReplace.url])
        XCTAssertNotNil(bookmarkList[newBookmark!.url])
    }

    func testWhenBookmarkUrlIsUpdatedToAlreadyBookmarkedUrl_ThenUpdatingMustFail() {
        var bookmarkList = BookmarkList()

        let firstUrl = URL(string: "wikipedia.org")!
        let bookmarks = [
            Bookmark(id: UUID(), url: firstUrl, title: "Title", isFavorite: true),
            Bookmark(id: UUID(), url: URL.duckDuckGo, title: "Title", isFavorite: true)
        ]

        bookmarks.forEach { bookmarkList.insert($0) }

        let bookmarkToReplace = bookmarks[1]
        let newBookmark = bookmarkList.updateUrl(of: bookmarkToReplace, to: firstUrl)

        XCTAssert(bookmarkList.bookmarks().count == bookmarks.count)
        XCTAssertNotNil(bookmarkList[firstUrl])
        XCTAssertNotNil(bookmarkList[bookmarkToReplace.url])
        XCTAssertNil(newBookmark)
    }

}

fileprivate extension Bookmark {

    static var aBookmark: Bookmark = Bookmark(id: UUID(),
                                              url: URL.duckDuckGo,
                                              title: "Title",
                                              isFavorite: false,
                                              faviconManagement: FaviconManagerMock())

    var identifiableBookmark: BookmarkList.IdentifiableBookmark {
        return BookmarkList.IdentifiableBookmark(from: self)
    }

}
