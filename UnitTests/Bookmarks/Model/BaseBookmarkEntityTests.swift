//
//  BaseBookmarkEntityTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

final class BaseBookmarkEntityTests: XCTestCase {

    // MARK: - Folders

    func testTwoBookmarkFolderWithSamePropertiesReturnTrueWhenIsEqualCalled() {
        // GIVEN
        let parentFolder = BookmarkFolder(id: "Parent", title: "Parent")
        let lhs = BookmarkFolder(id: "1", title: "Child", parentFolderUUID: parentFolder.id, children: [])
        let rhs = BookmarkFolder(id: "1", title: "Child", parentFolderUUID: parentFolder.id, children: [])

        // WHEN
        let result = lhs == rhs

        // THEN
        XCTAssertTrue(result)
    }

    func testTwoBookmarkFolderWithDifferentIdReturnFalseWhenIsEqualCalled() {
        // GIVEN
        let parentFolder = BookmarkFolder(id: "Parent", title: "Parent")
        let lhs = BookmarkFolder(id: "1", title: "Child", parentFolderUUID: parentFolder.id, children: [])
        let rhs = BookmarkFolder(id: "2", title: "Child", parentFolderUUID: parentFolder.id, children: [])

        // WHEN
        let result = lhs == rhs

        // THEN
        XCTAssertFalse(result)
    }

    func testTwoBookmarkFolderWithDifferentTitleReturnFalseWhenIsEqualCalled() {
        // GIVEN
        let parentFolder = BookmarkFolder(id: "Parent", title: "Parent")
        let lhs = BookmarkFolder(id: "1", title: "Child", parentFolderUUID: parentFolder.id, children: [])
        let rhs = BookmarkFolder(id: "1", title: "Child 1", parentFolderUUID: parentFolder.id, children: [])

        // WHEN
        let result = lhs == rhs

        // THEN
        XCTAssertFalse(result)
    }

    func testTwoBookmarkFolderWithDifferentParentReturnFalseWhenIsEqualCalled() {
        // GIVEN
        let parentFolder = BookmarkFolder(id: "Parent", title: "Parent")
        let lhs = BookmarkFolder(id: "1", title: "Child", parentFolderUUID: parentFolder.id, children: [])
        let rhs = BookmarkFolder(id: "1", title: "Child", parentFolderUUID: #function, children: [])

        // WHEN
        let result = lhs == rhs

        // THEN
        XCTAssertFalse(result)
    }

    func testTwoBookmarkParentFolderWithSameSubfoldersReturnTrueWhenIsEqualCalled() {
        // GIVEN
        let folder1 = BookmarkFolder(id: "1", title: "Child", parentFolderUUID: "Parent", children: [])
        let folder2 = BookmarkFolder(id: "2", title: "Child", parentFolderUUID: "Parent", children: [])
        let lhs = BookmarkFolder(id: "1-Parent", title: "Parent", children: [folder1, folder2])
        let rhs = BookmarkFolder(id: "1-Parent", title: "Parent", children: [folder1, folder2])

        // WHEN
        let result = lhs == rhs

        // THEN
        XCTAssertTrue(result)
    }

    func testTwoBookmarkParentFolderWithDifferentSubfoldersReturnFalseWhenIsEqualCalled() {
        // GIVEN
        let folder1 = BookmarkFolder(id: "1", title: "Child", parentFolderUUID: "Parent", children: [])
        let folder2 = BookmarkFolder(id: "2", title: "Child", parentFolderUUID: "Parent", children: [])
        let lhs = BookmarkFolder(id: "1-Parent", title: "Parent", children: [folder1, folder2])
        let rhs = BookmarkFolder(id: "1-Parent", title: "Parent", children: [folder1, folder2, BookmarkFolder(id: "3", title: "")])

        // WHEN
        let result = lhs == rhs

        // THEN
        XCTAssertFalse(result)
    }

    func testTwoBookmarkParentFolderWithSameBookmarksReturnTrueWhenIsEqualCalled() {
        // GIVEN
        let bookmark1 = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: true, parentFolderUUID: "1-Parent")
        let bookmark2 = Bookmark(id: "2", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: true, parentFolderUUID: "1-Parent")
        let lhs = BookmarkFolder(id: "1-Parent", title: "Parent", children: [bookmark1, bookmark2])
        let rhs = BookmarkFolder(id: "1-Parent", title: "Parent", children: [bookmark1, bookmark2])

        // WHEN
        let result = lhs == rhs

        // THEN
        XCTAssertTrue(result)
    }

    func testTwoBookmarkParentFolderWithDifferentBookmarksReturnFalseWhenIsEqualCalled() {
        // GIVEN
        let bookmark1 = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: true, parentFolderUUID: "1-Parent")
        let bookmark2 = Bookmark(id: "2", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: true, parentFolderUUID: "1-Parent")
        let lhs = BookmarkFolder(id: "1-Parent", title: "Parent", children: [bookmark1, bookmark2])
        let rhs = BookmarkFolder(id: "1-Parent", title: "Parent", children: [bookmark1, bookmark2, BookmarkFolder(id: "4", title: "New")])

        // WHEN
        let result = lhs == rhs

        // THEN
        XCTAssertFalse(result)
    }

    // MARK: - Bookmarks

    func testTwoBookmarkWithSamePropertiesReturnTrueWhenIsEqualCalled() {
        // GIVEN
        let parentFolder = BookmarkFolder(id: "Parent", title: "Parent")
        let lhs = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: true, parentFolderUUID: parentFolder.id)
        let rhs = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: true, parentFolderUUID: parentFolder.id)

        // WHEN
        let result = lhs == rhs

        // THEN
        XCTAssertTrue(result)
    }

    func testTwoBookmarkWithDifferentIdReturnFalseWhenIsEqualCalled() {
        // GIVEN
        let lhs = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: true, parentFolderUUID: "z")
        let rhs = Bookmark(id: "2", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: true, parentFolderUUID: "z")

        // WHEN
        let result = lhs == rhs

        // THEN
        XCTAssertFalse(result)
    }

    func testTwoBookmarkWithDifferentURLReturnFalseWhenIsEqualCalled() {
        // GIVEN
        let lhs = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: true, parentFolderUUID: "z")
        let rhs = Bookmark(id: "1", url: URL.devMode, title: "DDG", isFavorite: true, parentFolderUUID: "z")

        // WHEN
        let result = lhs == rhs

        // THEN
        XCTAssertFalse(result)
    }

    func testTwoBookmarkWithDifferentTitleReturnFalseWhenIsEqualCalled() {
        // GIVEN
        let lhs = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: true, parentFolderUUID: "z")
        let rhs = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DDG 2", isFavorite: true, parentFolderUUID: "z")

        // WHEN
        let result = lhs == rhs

        // THEN
        XCTAssertFalse(result)
    }

    func testTwoBookmarkWithDifferentIsFavoriteReturnFalseWhenIsEqualCalled() {
        // GIVEN
        let lhs = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: true, parentFolderUUID: "z")
        let rhs = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: false, parentFolderUUID: "z")

        // WHEN
        let result = lhs == rhs

        // THEN
        XCTAssertFalse(result)
    }

    func testTwoBookmarkWithDifferentParentFolderReturnFalseWhenIsEqualCalled() {
        // GIVEN
        let lhs = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: true, parentFolderUUID: "z")
        let rhs = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: false, parentFolderUUID: "z-a")

        // WHEN
        let result = lhs == rhs

        // THEN
        XCTAssertFalse(result)
    }

    func testTwoBookmarkFoldersAddedToRootFolderReturnTrueWhenLeftParentIsBookmarksRootAndRightIsNil() {
        // GIVEN
        let lhs = BookmarkFolder(id: "1", title: "A", parentFolderUUID: "bookmarks_root", children: [])
        let rhs = BookmarkFolder(id: "1", title: "A", parentFolderUUID: nil, children: [])

        // WHEN
        let result = lhs == rhs

        // THEN
        XCTAssertTrue(result)
    }

    func testTwoBookmarkFoldersAddedToRootFolderReturnTrueWhenLeftParentIsNilAndRightParentIsRootBookmarks() {
        // GIVEN
        let lhs = BookmarkFolder(id: "1", title: "A", parentFolderUUID: nil, children: [])
        let rhs = BookmarkFolder(id: "1", title: "A", parentFolderUUID: "bookmarks_root", children: [])

        // WHEN
        let result = lhs == rhs

        // THEN
        XCTAssertTrue(result)
    }

    // MARK: - Base Entity

    func testDifferentBookmarkEntitiesReturnFalseWhenIsEqualCalled() {
        // GIVEN
        let lhs = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "DDG", isFavorite: true)
        let rhs = BookmarkFolder(id: "1", title: "DDG")

        // WHEN
        let result = lhs == rhs

        // THEN
        XCTAssertFalse(result)
    }

    func testWhenSortingByManualModeThenBookmarksAreReturnedInOriginalOrder() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "Test 3", isFavorite: true)
        let folder = BookmarkFolder(id: "2", title: "Test 1")
        let bookmarkTwo = Bookmark(id: "3", url: URL.duckDuckGo.absoluteString, title: "Test 2", isFavorite: false)

        // WHEN
        let sut = [bookmark, folder, bookmarkTwo].sorted(by: .manual)

        // THEN
        XCTAssertEqual(sut[0], bookmark)
        XCTAssertEqual(sut[1], folder)
        XCTAssertEqual(sut[2], bookmarkTwo)
    }

    func testWhenSortingByNameAscThenBookmarksAreReturnedByAscendingTitle() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "Test 3", isFavorite: true)
        let folder = BookmarkFolder(id: "2", title: "Test 1")
        let bookmarkTwo = Bookmark(id: "3", url: URL.duckDuckGo.absoluteString, title: "Test 2", isFavorite: false)

        // WHEN
        let sut = [bookmark, folder, bookmarkTwo].sorted(by: .nameAscending)

        // THEN
        XCTAssertEqual(sut[0], folder)
        XCTAssertEqual(sut[1], bookmarkTwo)
        XCTAssertEqual(sut[2], bookmark)
    }

    func testWhenSortingByNameDescThenBookmarksAreReturnedByDescendingTitle() {
        // GIVEN
        let bookmark = Bookmark(id: "1", url: URL.duckDuckGo.absoluteString, title: "Test 3", isFavorite: true)
        let folder = BookmarkFolder(id: "2", title: "Test 1")
        let bookmarkTwo = Bookmark(id: "3", url: URL.duckDuckGo.absoluteString, title: "Test 2", isFavorite: false)

        // WHEN
        let sut = [bookmark, folder, bookmarkTwo].sorted(by: .nameDescending)

        // THEN
        XCTAssertEqual(sut[0], bookmark)
        XCTAssertEqual(sut[1], bookmarkTwo)
        XCTAssertEqual(sut[2], folder)
    }

}
