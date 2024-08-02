//
//  BookmarkManagementDetailViewModelTests.swift
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

final class BookmarkManagementDetailViewModelTests: XCTestCase {

    // MARK: - Empty selection state tests

    func testWhenNoSearchAndEmptySelection_thenTotalRowsReturnTopEntitiesCount() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .empty, searchQuery: "")

        XCTAssertEqual(sut.totalRows(), 3)
        XCTAssertFalse(bookmarkManager.wasSearchByQueryCalled)
    }

    func testWhenSearchAndEmptySelection_thenTotalRowsReturnTopEntitiesSearchCount() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkTwo]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .empty, searchQuery: "some")

        XCTAssertEqual(sut.totalRows(), 1)
        XCTAssertTrue(bookmarkManager.wasSearchByQueryCalled)
    }

    func testWhenNoSearchAndEmptySelection_thenIndexIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .empty, searchQuery: "")

        XCTAssertEqual(sut.index(for: bookmarkOne), 0)
        XCTAssertEqual(sut.index(for: bookmarkTwo), 1)
        XCTAssertEqual(sut.index(for: bookmarkThree), 2)
    }

    func testWhenSearchAndEmptySelection_thenIndexIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkTwo]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .empty, searchQuery: "some")

        XCTAssertEqual(sut.index(for: bookmarkTwo), 0)
        XCTAssertNil(sut.index(for: bookmarkOne))
        XCTAssertNil(sut.index(for: bookmarkThree))
    }

    func testWhenNoSearchAndEmptySelection_thenFetchEntityIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .empty, searchQuery: "")

        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkOne)
        XCTAssertEqual(sut.fetchEntity(at: 1), bookmarkTwo)
        XCTAssertEqual(sut.fetchEntity(at: 2), bookmarkThree)
    }

    func testWhenSearchAndEmptySelection_thenFetchEntityIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkTwo]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .empty, searchQuery: "some")

        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkTwo)
        XCTAssertNil(sut.fetchEntity(at: 1))
    }

    func testWhenNoSearchAndEmptySelection_thenFetchEntityAndParentIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .empty, searchQuery: "")

        XCTAssertEqual(sut.fetchEntityAndParent(at: 0).entity, bookmarkOne)
        XCTAssertNil(sut.fetchEntityAndParent(at: 0).parentFolder)
        XCTAssertEqual(sut.fetchEntityAndParent(at: 1).entity, bookmarkTwo)
        XCTAssertNil(sut.fetchEntityAndParent(at: 1).parentFolder)
        XCTAssertEqual(sut.fetchEntityAndParent(at: 2).entity, bookmarkThree)
        XCTAssertNil(sut.fetchEntityAndParent(at: 2).parentFolder)
    }

    func testWhenSearchAndEmptySelection_thenFecthEntityAndParentIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkTwo]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .empty, searchQuery: "some")

        XCTAssertEqual(sut.fetchEntityAndParent(at: 0).entity, bookmarkTwo)
        XCTAssertNil(sut.fetchEntityAndParent(at: 0).parentFolder)
        XCTAssertNil(sut.fetchEntityAndParent(at: 1).entity)
        XCTAssertNil(sut.fetchEntityAndParent(at: 1).parentFolder)
        XCTAssertNil(sut.fetchEntityAndParent(at: 2).entity)
        XCTAssertNil(sut.fetchEntityAndParent(at: 2).parentFolder)
    }

    // MARK: - Folder selection state tests

    func testWhenNoSearchAndFolderSelection_thenTotalRowsReturnFolderAndChildrenCount() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let children = [Bookmark(id: "4", url: "www.test4.com", title: "Bookmark #4", isFavorite: false),
                        Bookmark(id: "5", url: "www.test5.com", title: "Bookmark #5", isFavorite: false)]
        let folder = createFolder(with: children)
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree, folder])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .folder(folder), searchQuery: "")

        XCTAssertEqual(sut.totalRows(), 2)
        XCTAssertFalse(bookmarkManager.wasSearchByQueryCalled)
    }

    func testWhenSearchAndFolderSelection_thenTotalRowsReturnFolderAndChildrenSearchCount() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let children = [Bookmark(id: "4", url: "www.test4.com", title: "Bookmark #4", isFavorite: false),
                        Bookmark(id: "5", url: "www.test5.com", title: "Bookmark #5", isFavorite: false)]
        let folder = createFolder(with: children)
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree, folder])
        bookmarkManager.bookmarksReturnedForSearch = folder.children

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .folder(folder), searchQuery: "some")

        XCTAssertEqual(sut.totalRows(), 2)
        XCTAssertTrue(bookmarkManager.wasSearchByQueryCalled)
    }

    func testWhenNoSearchAndFolderSelection_thenIndexIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkFour = Bookmark(id: "4", url: "www.test4.com", title: "Bookmark #4", isFavorite: false)
        let bookmarkFive = Bookmark(id: "5", url: "www.test5.com", title: "Bookmark #5", isFavorite: false)
        let children = [bookmarkFour, bookmarkFive]
        let folder = createFolder(with: children)
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree, folder])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .folder(folder), searchQuery: "")

        XCTAssertEqual(sut.index(for: bookmarkFour), 0)
        XCTAssertEqual(sut.index(for: bookmarkFive), 1)
        XCTAssertNil(sut.index(for: bookmarkOne))
        XCTAssertNil(sut.index(for: bookmarkTwo))
        XCTAssertNil(sut.index(for: bookmarkThree))
    }

    func testWhenSearchAndFolderSelection_thenIndexIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkFour = Bookmark(id: "4", url: "www.test4.com", title: "Bookmark #4", isFavorite: false)
        let bookmarkFive = Bookmark(id: "5", url: "www.test5.com", title: "Bookmark #5", isFavorite: false)
        let children = [bookmarkFour, bookmarkFive]
        let folder = createFolder(with: children)
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree, folder])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkOne, bookmarkFive]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .folder(folder), searchQuery: "some")

        XCTAssertEqual(sut.index(for: bookmarkOne), 0)
        XCTAssertEqual(sut.index(for: bookmarkFive), 1)
        XCTAssertNil(sut.index(for: bookmarkTwo))
        XCTAssertNil(sut.index(for: bookmarkThree))
        XCTAssertNil(sut.index(for: bookmarkFour))
    }

    func testWhenNoSearchAndFolderSelection_thenFetchEntityIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkFour = Bookmark(id: "4", url: "www.test4.com", title: "Bookmark #4", isFavorite: false)
        let bookmarkFive = Bookmark(id: "5", url: "www.test5.com", title: "Bookmark #5", isFavorite: false)
        let children = [bookmarkFour, bookmarkFive]
        let folder = createFolder(with: children)
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree, folder])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .folder(folder), searchQuery: "")

        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkFour)
        XCTAssertEqual(sut.fetchEntity(at: 1), bookmarkFive)
        XCTAssertNil(sut.fetchEntity(at: 2))
    }

    func testWhenSearchAndFolderSelection_thenFetchEntityIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkFour = Bookmark(id: "4", url: "www.test4.com", title: "Bookmark #4", isFavorite: false)
        let bookmarkFive = Bookmark(id: "5", url: "www.test5.com", title: "Bookmark #5", isFavorite: false)
        let children = [bookmarkFour, bookmarkFive]
        let folder = createFolder(with: children)
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree, folder])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkOne, bookmarkFive]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .folder(folder), searchQuery: "some")

        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkOne)
        XCTAssertEqual(sut.fetchEntity(at: 1), bookmarkFive)
        XCTAssertNil(sut.fetchEntity(at: 2))
    }

    func testWhenNoSearchAndFolderSelection_thenFetchEntityAndParentIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkFour = Bookmark(id: "4", url: "www.test4.com", title: "Bookmark #4", isFavorite: false)
        let bookmarkFive = Bookmark(id: "5", url: "www.test5.com", title: "Bookmark #5", isFavorite: false)
        let children = [bookmarkFour, bookmarkFive]
        let folder = createFolder(with: children)
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree, folder])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .folder(folder), searchQuery: "")

        XCTAssertEqual(sut.fetchEntityAndParent(at: 0).entity, bookmarkFour)
        XCTAssertEqual(sut.fetchEntityAndParent(at: 0).parentFolder, folder)
        XCTAssertEqual(sut.fetchEntityAndParent(at: 1).entity, bookmarkFive)
        XCTAssertEqual(sut.fetchEntityAndParent(at: 1).parentFolder, folder)
        XCTAssertNil(sut.fetchEntityAndParent(at: 2).entity)
        XCTAssertNotNil(sut.fetchEntityAndParent(at: 2).parentFolder)
    }

    func testWhenSearchAndFolderSelection_thenFetchEntityAndParentIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkFour = Bookmark(id: "4", url: "www.test4.com", title: "Bookmark #4", isFavorite: false)
        let bookmarkFive = Bookmark(id: "5", url: "www.test5.com", title: "Bookmark #5", isFavorite: false)
        let children = [bookmarkFour, bookmarkFive]
        let folder = createFolder(with: children)
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree, folder])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkOne, bookmarkFive]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .folder(folder), searchQuery: "some")

        XCTAssertEqual(sut.fetchEntityAndParent(at: 0).entity, bookmarkOne)
        XCTAssertEqual(sut.fetchEntityAndParent(at: 0).parentFolder, folder)
        XCTAssertEqual(sut.fetchEntityAndParent(at: 1).entity, bookmarkFive)
        XCTAssertEqual(sut.fetchEntityAndParent(at: 1).parentFolder, folder)
        XCTAssertNil(sut.fetchEntityAndParent(at: 2).entity)
        XCTAssertNotNil(sut.fetchEntityAndParent(at: 2).parentFolder)
    }

    // MARK: - Favorites selection state tests

    func testWhenNoSearchAndFavoritesSelection_thenTotalRowsReturnTotalFavoritesCount() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree], favorites: [bookmarkTwo])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .favorites, searchQuery: "")

        XCTAssertEqual(sut.totalRows(), 1)
        XCTAssertFalse(bookmarkManager.wasSearchByQueryCalled)
    }

    func testWhenSearchAndFavoritesSelection_thenTotalRowsReturnFavoritesSearchCount() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree], favorites: [bookmarkOne, bookmarkTwo])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkOne, bookmarkTwo]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .favorites, searchQuery: "some")

        XCTAssertEqual(sut.totalRows(), 2)
        XCTAssertTrue(bookmarkManager.wasSearchByQueryCalled)
    }

    func testWhenNoSearchAndFavoritesSelection_thenIndexIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree], favorites: [bookmarkTwo])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .favorites, searchQuery: "")

        XCTAssertEqual(sut.index(for: bookmarkTwo), 0)
        XCTAssertNil(sut.index(for: bookmarkOne))
        XCTAssertNil(sut.index(for: bookmarkThree))
    }

    func testWhenSearchAndFavoritesSelection_thenIndexIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree], favorites: [bookmarkOne, bookmarkTwo])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkOne, bookmarkTwo]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .favorites, searchQuery: "some")

        XCTAssertEqual(sut.index(for: bookmarkOne), 0)
        XCTAssertEqual(sut.index(for: bookmarkTwo), 1)
        XCTAssertNil(sut.index(for: bookmarkThree))
    }

    func testWhenNoSearchAndFavoritesSelection_thenFetchEntityIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree], favorites: [bookmarkTwo])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .favorites, searchQuery: "")

        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkTwo)
        XCTAssertNil(sut.fetchEntity(at: 1))
    }

    func testWhenSearchAndFavoritesSelection_thenFetchEntityIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree], favorites: [bookmarkOne, bookmarkTwo])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkOne, bookmarkTwo]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .favorites, searchQuery: "some")

        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkOne)
        XCTAssertEqual(sut.fetchEntity(at: 1), bookmarkTwo)
        XCTAssertNil(sut.fetchEntity(at: 2))
    }

    func testWhenNoSearchAndFavoritesSelection_thenFetchEntityAndParentIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree], favorites: [bookmarkTwo])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .favorites, searchQuery: "")

        XCTAssertEqual(sut.fetchEntityAndParent(at: 0).entity, bookmarkTwo)
        XCTAssertNil(sut.fetchEntityAndParent(at: 0).parentFolder)
        XCTAssertNil(sut.fetchEntityAndParent(at: 1).entity)
        XCTAssertNil(sut.fetchEntityAndParent(at: 1).parentFolder)
    }

    func testWhenSearchAndFavoritesSelection_thenFetchEntityAndParentIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree], favorites: [bookmarkOne, bookmarkTwo])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkOne, bookmarkTwo]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .favorites, searchQuery: "some")

        XCTAssertEqual(sut.fetchEntityAndParent(at: 0).entity, bookmarkOne)
        XCTAssertNil(sut.fetchEntityAndParent(at: 0).parentFolder)
        XCTAssertEqual(sut.fetchEntityAndParent(at: 1).entity, bookmarkTwo)
        XCTAssertNil(sut.fetchEntityAndParent(at: 1).parentFolder)
    }

    // MARK: - Other tests

    func testWhenSearchQueryIsEmptyAndResultsAreNotEmpty_thenShouldShowNoSearchResultsStateIsFalse() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])
        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)

        sut.update(selection: .empty, searchQuery: "")

        XCTAssertFalse(sut.shouldShowNoSearchResultsState)
    }

    func testWhenSearchQueryIsNotEmptyAndResultsAreNotEmpty_thenShouldShowNoSearchResultsStateIsFalse() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkOne, bookmarkTwo]
        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)

        sut.update(selection: .empty, searchQuery: "some")

        XCTAssertFalse(sut.shouldShowNoSearchResultsState)
    }

    func testWhenSearchQueryIsEmptyAndResultsAreEmpty_thenShouldShowNoSearchResultsStateIsFalse() {
        let bookmarkManager = MockBookmarkManager()
        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)

        sut.update(selection: .empty, searchQuery: "")

        XCTAssertFalse(sut.shouldShowNoSearchResultsState)
    }

    func testWhenSearchQueryIsNotEmptyAndResultsAreEmpty_thenShouldShowNoSearchResultsStateIsTrue() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])
        bookmarkManager.bookmarksReturnedForSearch = []
        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)

        sut.update(selection: .empty, searchQuery: "some")

        XCTAssertTrue(sut.shouldShowNoSearchResultsState)
    }

    // MARK: - Drag and drop validation tests

    func testWhenSearchQueryIsNotBlankAndProposedDestinationIsRoot_thenWeDoNotAllowDrop() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])
        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkOne, bookmarkTwo, bookmarkThree]
        sut.update(selection: .empty, searchQuery: "some")

        // We pick a row where the result is nil
        let result = sut.validateDrop(pasteboardItems: nil, proposedRow: 3, proposedDropOperation: .above)

        XCTAssertEqual(result, .none)
    }

    func testWhenSearchQueryIsBlankAndProposedDestinationIsRoot_thenWeAllowDrop() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])
        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .empty, searchQuery: "")

        // We pick a row where the result is nil
        let result = sut.validateDrop(pasteboardItems: nil, proposedRow: 3, proposedDropOperation: .above)

        XCTAssertEqual(result, .move)
    }

    func testWhenDraggingBookmarkToFolderInSearch_thenWeAllowDrop() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkFour = Bookmark(id: "4", url: "www.test4.com", title: "Bookmark #4", isFavorite: false)
        let bookmarkFive = Bookmark(id: "5", url: "www.test5.com", title: "Bookmark #5", isFavorite: false)
        let children = [bookmarkFour, bookmarkFive]
        let folder = createFolder(with: children)
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree, folder])
        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        bookmarkManager.bookmarksReturnedForSearch = [folder]
        sut.update(selection: .empty, searchQuery: "some")
        let pasteboardItems = createPasteboardItems(for: bookmarkOne)

        // Zero is the position of the folder returned in the search
        let result = sut.validateDrop(pasteboardItems: pasteboardItems, proposedRow: 0, proposedDropOperation: .on)

        XCTAssertEqual(result, .move)
    }

    func testWhenDraggingBookmarkToFolderWhenNotSearching_thenWeAllowDrop() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkFour = Bookmark(id: "4", url: "www.test4.com", title: "Bookmark #4", isFavorite: false)
        let bookmarkFive = Bookmark(id: "5", url: "www.test5.com", title: "Bookmark #5", isFavorite: false)
        let children = [bookmarkFour, bookmarkFive]
        let folder = createFolder(with: children)
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree, folder])
        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .empty, searchQuery: "")
        let pasteboardItems = createPasteboardItems(for: bookmarkOne)

        // Three is the position of the folder
        let result = sut.validateDrop(pasteboardItems: pasteboardItems, proposedRow: 3, proposedDropOperation: .on)

        XCTAssertEqual(result, .move)
    }

    func testWhenDraggingBookmarkToBookmark_thenWeDoNotAllowDrop() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])
        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager)
        sut.update(selection: .empty, searchQuery: "")
        let pasteboardItems = createPasteboardItems(for: bookmarkOne)

        // We try to move bookmarkOne on bookmarkTwo
        let result = sut.validateDrop(pasteboardItems: pasteboardItems, proposedRow: 1, proposedDropOperation: .on)

        XCTAssertEqual(result, .none)
    }

    // MARK: - Helper functions

    private func createPasteboardItems(for bookmark: Bookmark) -> [NSPasteboardItem] {
        let pastedBookmark = BookmarkPasteboardWriter(bookmark: bookmark)
        let pasteboardWritedType = BookmarkPasteboardWriter.bookmarkUTIInternalType
        let propertyList = pastedBookmark.pasteboardPropertyList(forType: pasteboardWritedType)!

        return [NSPasteboardItem(pasteboardPropertyList: propertyList, ofType: pasteboardWritedType)!]
    }

    private func createBookmarkManager(with bookmarks: [BaseBookmarkEntity], favorites: [BaseBookmarkEntity] = []) -> MockBookmarkManager {
        let bookmarkManager = MockBookmarkManager()
        bookmarkManager.list = BookmarkList(entities: bookmarks, topLevelEntities: bookmarks, favorites: favorites)
        return bookmarkManager
    }

    private func createBookmarks() -> (Bookmark, Bookmark, Bookmark) {
        let bookmarkOne = Bookmark(id: "1", url: "www.test1.com", title: "Bookmark #1", isFavorite: false)
        let bookmarkTwo = Bookmark(id: "2", url: "www.test2.com", title: "Bookmark #2", isFavorite: true)
        let bookmarkThree = Bookmark(id: "3", url: "www.test3.com", title: "Bookmark #3", isFavorite: false)
        return (bookmarkOne, bookmarkTwo, bookmarkThree)
    }

    private func createFolder(with children: [Bookmark]) -> BookmarkFolder {
        return BookmarkFolder(id: "6", title: "Folder", children: children)
    }
}
