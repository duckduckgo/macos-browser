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
import PixelKitTestingUtilities
@testable import DuckDuckGo_Privacy_Browser
@testable import PixelKit

final class BookmarkManagementDetailViewModelTests: XCTestCase {
    private let testUserDefault = UserDefaults(suiteName: #function)!
    private let metrics = BookmarksSearchAndSortMetrics()

    // MARK: - Empty selection state tests

    func testWhenNoSearchAndEmptySelection_thenTotalRowsReturnTopEntitiesCount() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .empty, searchQuery: "")

        XCTAssertEqual(sut.totalRows(), 3)
        XCTAssertFalse(bookmarkManager.wasSearchByQueryCalled)
    }

    func testWhenSearchAndEmptySelection_thenTotalRowsReturnTopEntitiesSearchCount() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkTwo]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .empty, searchQuery: "some")

        XCTAssertEqual(sut.totalRows(), 1)
        XCTAssertTrue(bookmarkManager.wasSearchByQueryCalled)
    }

    func testWhenNoSearchAndEmptySelection_thenIndexIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .empty, searchQuery: "")

        XCTAssertEqual(sut.index(for: bookmarkOne), 0)
        XCTAssertEqual(sut.index(for: bookmarkTwo), 1)
        XCTAssertEqual(sut.index(for: bookmarkThree), 2)
    }

    func testWhenSearchAndEmptySelection_thenIndexIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkTwo]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .empty, searchQuery: "some")

        XCTAssertEqual(sut.index(for: bookmarkTwo), 0)
        XCTAssertNil(sut.index(for: bookmarkOne))
        XCTAssertNil(sut.index(for: bookmarkThree))
    }

    func testWhenNoSearchAndEmptySelection_thenFetchEntityIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .empty, searchQuery: "")

        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkOne)
        XCTAssertEqual(sut.fetchEntity(at: 1), bookmarkTwo)
        XCTAssertEqual(sut.fetchEntity(at: 2), bookmarkThree)
    }

    func testWhenSearchAndEmptySelection_thenFetchEntityIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkTwo]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .empty, searchQuery: "some")

        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkTwo)
        XCTAssertNil(sut.fetchEntity(at: 1))
    }

    func testWhenNoSearchAndEmptySelection_thenFetchEntityAndParentIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .empty, searchQuery: "")

        XCTAssertNil(sut.fetchParent())
        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkOne)
        XCTAssertEqual(sut.fetchEntity(at: 1), bookmarkTwo)
        XCTAssertEqual(sut.fetchEntity(at: 2), bookmarkThree)
    }

    func testWhenSearchAndEmptySelection_thenFecthEntityAndParentIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkTwo]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .empty, searchQuery: "some")

        XCTAssertNil(sut.fetchParent())
        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkTwo)
        XCTAssertNil(sut.fetchEntity(at: 1))
        XCTAssertNil(sut.fetchEntity(at: 2))
    }

    // MARK: - Folder selection state tests

    func testWhenNoSearchAndFolderSelection_thenTotalRowsReturnFolderAndChildrenCount() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let children = [Bookmark(id: "4", url: "https://www.test4.com", title: "Bookmark #4", isFavorite: false),
                        Bookmark(id: "5", url: "https://www.test5.com", title: "Bookmark #5", isFavorite: false)]
        let folder = createFolder(with: children)
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree, folder])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .folder(folder), searchQuery: "")

        XCTAssertEqual(sut.totalRows(), 2)
        XCTAssertFalse(bookmarkManager.wasSearchByQueryCalled)
    }

    func testWhenSearchAndFolderSelection_thenTotalRowsReturnFolderAndChildrenSearchCount() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let children = [Bookmark(id: "4", url: "https://www.test4.com", title: "Bookmark #4", isFavorite: false),
                        Bookmark(id: "5", url: "https://www.test5.com", title: "Bookmark #5", isFavorite: false)]
        let folder = createFolder(with: children)
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree, folder])
        bookmarkManager.bookmarksReturnedForSearch = folder.children

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .folder(folder), searchQuery: "some")

        XCTAssertEqual(sut.totalRows(), 2)
        XCTAssertTrue(bookmarkManager.wasSearchByQueryCalled)
    }

    func testWhenNoSearchAndFolderSelection_thenIndexIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkFour = Bookmark(id: "4", url: "https://www.test4.com", title: "Bookmark #4", isFavorite: false)
        let bookmarkFive = Bookmark(id: "5", url: "https://www.test5.com", title: "Bookmark #5", isFavorite: false)
        let children = [bookmarkFour, bookmarkFive]
        let folder = createFolder(with: children)
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree, folder])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .folder(folder), searchQuery: "")

        XCTAssertEqual(sut.index(for: bookmarkFour), 0)
        XCTAssertEqual(sut.index(for: bookmarkFive), 1)
        XCTAssertNil(sut.index(for: bookmarkOne))
        XCTAssertNil(sut.index(for: bookmarkTwo))
        XCTAssertNil(sut.index(for: bookmarkThree))
    }

    func testWhenSearchAndFolderSelection_thenIndexIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkFour = Bookmark(id: "4", url: "https://www.test4.com", title: "Bookmark #4", isFavorite: false)
        let bookmarkFive = Bookmark(id: "5", url: "https://www.test5.com", title: "Bookmark #5", isFavorite: false)
        let children = [bookmarkFour, bookmarkFive]
        let folder = createFolder(with: children)
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree, folder])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkOne, bookmarkFive]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .folder(folder), searchQuery: "some")

        XCTAssertEqual(sut.index(for: bookmarkOne), 0)
        XCTAssertEqual(sut.index(for: bookmarkFive), 1)
        XCTAssertNil(sut.index(for: bookmarkTwo))
        XCTAssertNil(sut.index(for: bookmarkThree))
        XCTAssertNil(sut.index(for: bookmarkFour))
    }

    func testWhenNoSearchAndFolderSelection_thenFetchEntityIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkFour = Bookmark(id: "4", url: "https://www.test4.com", title: "Bookmark #4", isFavorite: false)
        let bookmarkFive = Bookmark(id: "5", url: "https://www.test5.com", title: "Bookmark #5", isFavorite: false)
        let children = [bookmarkFour, bookmarkFive]
        let folder = createFolder(with: children)
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree, folder])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .folder(folder), searchQuery: "")

        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkFour)
        XCTAssertEqual(sut.fetchEntity(at: 1), bookmarkFive)
        XCTAssertNil(sut.fetchEntity(at: 2))
    }

    func testWhenSearchAndFolderSelection_thenFetchEntityIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkFour = Bookmark(id: "4", url: "https://www.test4.com", title: "Bookmark #4", isFavorite: false)
        let bookmarkFive = Bookmark(id: "5", url: "https://www.test5.com", title: "Bookmark #5", isFavorite: false)
        let children = [bookmarkFour, bookmarkFive]
        let folder = createFolder(with: children)
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree, folder])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkOne, bookmarkFive]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .folder(folder), searchQuery: "some")

        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkOne)
        XCTAssertEqual(sut.fetchEntity(at: 1), bookmarkFive)
        XCTAssertNil(sut.fetchEntity(at: 2))
    }

    func testWhenNoSearchAndFolderSelection_thenFetchEntityAndParentIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkFour = Bookmark(id: "4", url: "https://www.test4.com", title: "Bookmark #4", isFavorite: false)
        let bookmarkFive = Bookmark(id: "5", url: "https://www.test5.com", title: "Bookmark #5", isFavorite: false)
        let children = [bookmarkFour, bookmarkFive]
        let folder = createFolder(with: children)
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree, folder])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .folder(folder), searchQuery: "")

        XCTAssertEqual(sut.fetchParent(), folder)
        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkFour)
        XCTAssertEqual(sut.fetchEntity(at: 1), bookmarkFive)
        XCTAssertNil(sut.fetchEntity(at: 2))
    }

    func testWhenSearchAndFolderSelection_thenFetchEntityAndParentIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkFour = Bookmark(id: "4", url: "https://www.test4.com", title: "Bookmark #4", isFavorite: false)
        let bookmarkFive = Bookmark(id: "5", url: "https://www.test5.com", title: "Bookmark #5", isFavorite: false)
        let children = [bookmarkFour, bookmarkFive]
        let folder = createFolder(with: children)
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree, folder])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkOne, bookmarkFive]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .folder(folder), searchQuery: "some")

        XCTAssertEqual(sut.fetchParent(), folder)
        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkOne)
        XCTAssertEqual(sut.fetchEntity(at: 1), bookmarkFive)
        XCTAssertNil(sut.fetchEntity(at: 2))
    }

    // MARK: - Favorites selection state tests

    func testWhenNoSearchAndFavoritesSelection_thenTotalRowsReturnTotalFavoritesCount() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree], favorites: [bookmarkTwo])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .favorites, searchQuery: "")

        XCTAssertEqual(sut.totalRows(), 1)
        XCTAssertFalse(bookmarkManager.wasSearchByQueryCalled)
    }

    func testWhenSearchAndFavoritesSelection_thenTotalRowsReturnFavoritesSearchCount() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree], favorites: [bookmarkOne, bookmarkTwo])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkOne, bookmarkTwo]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .favorites, searchQuery: "some")

        XCTAssertEqual(sut.totalRows(), 2)
        XCTAssertTrue(bookmarkManager.wasSearchByQueryCalled)
    }

    func testWhenNoSearchAndFavoritesSelection_thenIndexIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree], favorites: [bookmarkTwo])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .favorites, searchQuery: "")

        XCTAssertEqual(sut.index(for: bookmarkTwo), 0)
        XCTAssertNil(sut.index(for: bookmarkOne))
        XCTAssertNil(sut.index(for: bookmarkThree))
    }

    func testWhenSearchAndFavoritesSelection_thenIndexIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree], favorites: [bookmarkOne, bookmarkTwo])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkOne, bookmarkTwo]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .favorites, searchQuery: "some")

        XCTAssertEqual(sut.index(for: bookmarkOne), 0)
        XCTAssertEqual(sut.index(for: bookmarkTwo), 1)
        XCTAssertNil(sut.index(for: bookmarkThree))
    }

    func testWhenNoSearchAndFavoritesSelection_thenFetchEntityIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree], favorites: [bookmarkTwo])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .favorites, searchQuery: "")

        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkTwo)
        XCTAssertNil(sut.fetchEntity(at: 1))
    }

    func testWhenSearchAndFavoritesSelection_thenFetchEntityIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree], favorites: [bookmarkOne, bookmarkTwo])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkOne, bookmarkTwo]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .favorites, searchQuery: "some")

        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkOne)
        XCTAssertEqual(sut.fetchEntity(at: 1), bookmarkTwo)
        XCTAssertNil(sut.fetchEntity(at: 2))
    }

    func testWhenNoSearchAndFavoritesSelection_thenFetchEntityAndParentIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree], favorites: [bookmarkTwo])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .favorites, searchQuery: "")

        XCTAssertNil(sut.fetchParent())
        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkTwo)
        XCTAssertNil(sut.fetchEntity(at: 1))
    }

    func testWhenSearchAndFavoritesSelection_thenFetchEntityAndParentIsCorrect() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree], favorites: [bookmarkOne, bookmarkTwo])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkOne, bookmarkTwo]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .favorites, searchQuery: "some")

        XCTAssertNil(sut.fetchParent())
        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkOne)
        XCTAssertEqual(sut.fetchEntity(at: 1), bookmarkTwo)
    }

    // MARK: - Content state tests

    func testWhenSearchQueryIsEmptyAndResultsAreNotEmpty_thenContentStateIsNonEmpty() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])
        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)

        sut.update(selection: .empty, searchQuery: "")

        XCTAssertEqual(sut.contentState, .nonEmpty)
    }

    func testWhenSearchQueryIsNotEmptyAndResultsAreNotEmpty_thenContentStateIsNonEmpty() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkOne, bookmarkTwo]
        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)

        sut.update(selection: .empty, searchQuery: "some")

        XCTAssertEqual(sut.contentState, .nonEmpty)
    }

    func testWhenBookmarksAreEmptyAndSearchQueryIsNot_thenContentStateIsEmptyForBookmarks() {
        let bookmarkManager = MockBookmarkManager()
        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)

        sut.update(selection: .empty, searchQuery: "some")

        XCTAssertEqual(sut.contentState, .empty(emptyState: .noBookmarks))
    }

    func testWhenBookmarksAreNotEmptyAndSearchResultsAreEmpty_thenContentStateIsEmptyForSearchResults() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])
        bookmarkManager.bookmarksReturnedForSearch = []
        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)

        sut.update(selection: .empty, searchQuery: "some")

        XCTAssertEqual(sut.contentState, .empty(emptyState: .noSearchResults))
    }

    // MARK: - Drag and drop validation tests

    func testWhenSearchQueryIsNotBlankAndProposedDestinationIsRoot_thenWeDoNotAllowDrop() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])
        let dragDropManager = BookmarkDragDropManager(bookmarkManager: bookmarkManager)
        let viewController = BookmarkManagementDetailViewController(bookmarkManager: bookmarkManager, dragDropManager: dragDropManager)
        let sut = viewController.managementDetailViewModel
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkOne, bookmarkTwo, bookmarkThree]
        sut.update(selection: .empty, searchQuery: "some")

        // We pick a row where the result is nil
        let pasteboard = NSPasteboard.test()
        pasteboard.clearContents()
        let result = viewController.tableView(NSTableView(), validateDrop: MockDraggingInfo(draggingPasteboard: pasteboard), proposedRow: 3, proposedDropOperation: .above)

        XCTAssertEqual(result, .none)
    }

    func testWhenSearchQueryIsBlankAndProposedDestinationIsRoot_thenWeAllowDrop() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])
        let dragDropManager = BookmarkDragDropManager(bookmarkManager: bookmarkManager)
        let viewController = BookmarkManagementDetailViewController(bookmarkManager: bookmarkManager, dragDropManager: dragDropManager)
        let sut = viewController.managementDetailViewModel
        sut.update(selection: .empty, searchQuery: "")

        // We pick a row where the result is nil
        let pasteboard = NSPasteboard.test()
        pasteboard.clearContents()
        let result = viewController.tableView(NSTableView(), validateDrop: MockDraggingInfo(draggingPasteboard: pasteboard), proposedRow: 3, proposedDropOperation: .above)

        XCTAssertEqual(result, .none)
    }

    func testWhenDraggingBookmarkToFolderInSearch_thenWeAllowDrop() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkFour = Bookmark(id: "4", url: "https://www.test4.com", title: "Bookmark #4", isFavorite: false)
        let bookmarkFive = Bookmark(id: "5", url: "https://www.test5.com", title: "Bookmark #5", isFavorite: false)
        let children = [bookmarkFour, bookmarkFive]
        let folder = createFolder(with: children)
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree, folder])
        let dragDropManager = BookmarkDragDropManager(bookmarkManager: bookmarkManager)
        let viewController = BookmarkManagementDetailViewController(bookmarkManager: bookmarkManager, dragDropManager: dragDropManager)
        let sut = viewController.managementDetailViewModel
        bookmarkManager.bookmarksReturnedForSearch = [folder]
        sut.update(selection: .empty, searchQuery: "some")
        let pasteboard = NSPasteboard.test()
        pasteboard.writeObjects([bookmarkOne.pasteboardWriter])
        let draggingInfo = MockDraggingInfo(draggingPasteboard: pasteboard)

        // Zero is the position of the folder returned in the search
        let result = viewController.tableView(NSTableView(), validateDrop: draggingInfo, proposedRow: 0, proposedDropOperation: .on)

        XCTAssertEqual(result, .move)
    }

    func testWhenDraggingBookmarkToFolderWhenNotSearching_thenWeAllowDrop() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkFour = Bookmark(id: "4", url: "https://www.test4.com", title: "Bookmark #4", isFavorite: false)
        let bookmarkFive = Bookmark(id: "5", url: "https://www.test5.com", title: "Bookmark #5", isFavorite: false)
        let children = [bookmarkFour, bookmarkFive]
        let folder = createFolder(with: children)
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree, folder])
        let dragDropManager = BookmarkDragDropManager(bookmarkManager: bookmarkManager)
        let viewController = BookmarkManagementDetailViewController(bookmarkManager: bookmarkManager, dragDropManager: dragDropManager)
        let sut = viewController.managementDetailViewModel
        sut.update(selection: .empty, searchQuery: "")
        let pasteboard = NSPasteboard.test()
        pasteboard.writeObjects([bookmarkOne.pasteboardWriter])
        let draggingInfo = MockDraggingInfo(draggingPasteboard: pasteboard)

        // Three is the position of the folder
        let result = viewController.tableView(NSTableView(), validateDrop: draggingInfo, proposedRow: 3, proposedDropOperation: .on)

        XCTAssertEqual(result, .move)
    }

    func testWhenDraggingBookmarkToBookmark_thenWeDoNotAllowDrop() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkOne, bookmarkTwo, bookmarkThree])
        let dragDropManager = BookmarkDragDropManager(bookmarkManager: bookmarkManager)
        let viewController = BookmarkManagementDetailViewController(bookmarkManager: bookmarkManager, dragDropManager: dragDropManager)
        let sut = viewController.managementDetailViewModel
        sut.update(selection: .empty, searchQuery: "")
        let pasteboard = NSPasteboard.test()
        pasteboard.writeObjects([bookmarkOne.pasteboardWriter])
        let draggingInfo = MockDraggingInfo(draggingPasteboard: pasteboard)

        // We try to move bookmarkOne on bookmarkTwo
        let result = viewController.tableView(NSTableView(), validateDrop: draggingInfo, proposedRow: 1, proposedDropOperation: .on)

        XCTAssertEqual(result, .none)
    }

    // MARK: - Sort tests

    func testWhenSortModeIsManualAndInSearch_thenBookmarksAreInTheSameOrderAsReturnedFromManager() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkTwo, bookmarkOne, bookmarkThree])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkTwo, bookmarkOne, bookmarkThree]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .empty, mode: .manual, searchQuery: "some")

        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkTwo)
        XCTAssertEqual(sut.fetchEntity(at: 1), bookmarkOne)
        XCTAssertEqual(sut.fetchEntity(at: 2), bookmarkThree)
    }

    func testWhenSortModeIsManualAndNotInSearch_thenBookmarksAreInTheSameOrderAsReturnedFromManager() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkTwo, bookmarkOne, bookmarkThree])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .empty, mode: .manual, searchQuery: "")

        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkTwo)
        XCTAssertEqual(sut.fetchEntity(at: 1), bookmarkOne)
        XCTAssertEqual(sut.fetchEntity(at: 2), bookmarkThree)
    }

    func testWhenSortModeIsNameAscendingAndInSearch_thenBookmarksAreReturnedByTitleAscending() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkTwo, bookmarkOne, bookmarkThree])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkTwo, bookmarkOne, bookmarkThree]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .empty, mode: .nameAscending, searchQuery: "")

        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkOne)
        XCTAssertEqual(sut.fetchEntity(at: 1), bookmarkTwo)
        XCTAssertEqual(sut.fetchEntity(at: 2), bookmarkThree)
    }

    func testWhenSortModeIsNameAscendingAndNotInSearch_thenBookmarksAreReturnedByTitleAscending() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkTwo, bookmarkOne, bookmarkThree])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .empty, mode: .nameAscending, searchQuery: "")

        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkOne)
        XCTAssertEqual(sut.fetchEntity(at: 1), bookmarkTwo)
        XCTAssertEqual(sut.fetchEntity(at: 2), bookmarkThree)
    }

    func testWhenSortModeIsNameDescendingAndInSearch_thenBookmarksAreReturnedByTitleAscending() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkTwo, bookmarkOne, bookmarkThree])
        bookmarkManager.bookmarksReturnedForSearch = [bookmarkTwo, bookmarkOne, bookmarkThree]

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .empty, mode: .nameDescending, searchQuery: "some")

        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkThree)
        XCTAssertEqual(sut.fetchEntity(at: 1), bookmarkTwo)
        XCTAssertEqual(sut.fetchEntity(at: 2), bookmarkOne)
    }

    func testWhenSortModeIsNameDescendingAndNotInSearch_thenBookmarksAreReturnedByTitleAscending() {
        let (bookmarkOne, bookmarkTwo, bookmarkThree) = createBookmarks()
        let bookmarkManager = createBookmarkManager(with: [bookmarkTwo, bookmarkOne, bookmarkThree])

        let sut = BookmarkManagementDetailViewModel(bookmarkManager: bookmarkManager, metrics: metrics)
        sut.update(selection: .empty, mode: .nameDescending, searchQuery: "")

        XCTAssertEqual(sut.fetchEntity(at: 0), bookmarkThree)
        XCTAssertEqual(sut.fetchEntity(at: 1), bookmarkTwo)
        XCTAssertEqual(sut.fetchEntity(at: 2), bookmarkOne)
    }

    // MARK: - Metrics tests

    func testWhenOnSortButtonTapped_thenSortButtonClickedPixelIsFired() async throws {
        let expectedPixel = GeneralPixel.bookmarksSortButtonClicked(origin: "manager")
        let sut = BookmarkManagementDetailViewModel(bookmarkManager: MockBookmarkManager(), metrics: metrics)

        try await verify(expectedPixel: expectedPixel, for: { sut.onSortButtonTapped() })
    }

    func testWhenUpdateHappensAndSearchQueryIsNotEmpty_thenSearchExecutedIsFired() async throws{
        let expectedPixel = GeneralPixel.bookmarksSearchExecuted(origin: "manager")
        let sut = BookmarkManagementDetailViewModel(bookmarkManager: MockBookmarkManager(), metrics: metrics)

        try await verify(expectedPixel: expectedPixel, for: { sut.update(selection: .empty, searchQuery: "some") })
    }

    func testWhenUpdateHappensAndSearchQueryIsEmpty_thenSearchExecutedIsNotFired() async throws {
        let notExpectedPixel = GeneralPixel.bookmarksSearchExecuted(origin: "manager")
        let sut = BookmarkManagementDetailViewModel(bookmarkManager: MockBookmarkManager(), metrics: metrics)

        try await verifyNotFired(pixel: notExpectedPixel, for: { sut.update(selection: .empty) })
    }

    func testWhenOnBookmarksTappedAndSearchQueryIsEmpty_thenSearchResultClickedIsNotFired() async throws {
        let notExpectedPixel = GeneralPixel.bookmarksSearchResultClicked(origin: "manager")
        let sut = BookmarkManagementDetailViewModel(bookmarkManager: MockBookmarkManager(), metrics: metrics)

        try await verifyNotFired(pixel: notExpectedPixel, for: {
            sut.update(selection: .empty)
            sut.onBookmarkTapped()
        })
    }

    func testWhenOnBookmarksTappedAndSearchQueryIsNotEmpty_thenSearchResultClickedIsFired() async throws {
        let expectedPixel = GeneralPixel.bookmarksSearchResultClicked(origin: "manager")
        let sut = BookmarkManagementDetailViewModel(bookmarkManager: MockBookmarkManager(), metrics: metrics)

        try await verify(expectedPixel: expectedPixel, for: {
            sut.update(selection: .empty, searchQuery: "some")
            sut.onBookmarkTapped()
        })
    }

    // MARK: - Helper functions

    private func createBookmarkManager(with bookmarks: [BaseBookmarkEntity], favorites: [BaseBookmarkEntity] = []) -> MockBookmarkManager {
        let bookmarkManager = MockBookmarkManager()
        bookmarkManager.list = BookmarkList(entities: bookmarks, topLevelEntities: bookmarks, favorites: favorites)
        return bookmarkManager
    }

    private func createBookmarks() -> (Bookmark, Bookmark, Bookmark) {
        let bookmarkOne = Bookmark(id: "1", url: "https://www.test1.com", title: "Bookmark #1", isFavorite: false)
        let bookmarkTwo = Bookmark(id: "2", url: "https://www.test2.com", title: "Bookmark #2", isFavorite: true)
        let bookmarkThree = Bookmark(id: "3", url: "https://www.test3.com", title: "Bookmark #3", isFavorite: false)
        return (bookmarkOne, bookmarkTwo, bookmarkThree)
    }

    private func createFolder(with children: [Bookmark]) -> BookmarkFolder {
        return BookmarkFolder(id: "6", title: "Folder", children: children)
    }

    // MARK: - Pixel testing helper methods

    private func verify(expectedPixel: GeneralPixel, for code: () -> Void) async throws {
        let pixelExpectation = expectation(description: "Pixel fired")
        try await verify(pixel: expectedPixel, for: code, expectation: pixelExpectation) {
            await fulfillment(of: [pixelExpectation], timeout: 1.0)
        }
    }

    private func verifyNotFired(pixel: GeneralPixel, for code: () -> Void) async throws {
        let pixelExpectation = expectation(description: "Pixel not fired")
        try await verify(pixel: pixel, for: code, expectation: pixelExpectation) {
            let result = await XCTWaiter().fulfillment(of: [pixelExpectation], timeout: 1)

            if result == .timedOut {
                pixelExpectation.fulfill()
            } else {
                XCTFail("Pixel was fired")
            }
        }
    }

    private func verify(pixel: GeneralPixel,
                        for code: () -> Void,
                        expectation: XCTestExpectation,
                        verification: () async -> Void) async throws {
        let pixelKit = createPixelKit(pixelNamePrefix: pixel.name, pixelExpectation: expectation)

        PixelKit.setSharedForTesting(pixelKit: pixelKit)

        code()
        await verification()

        cleanUp(pixelKit: pixelKit)
    }

    private func createPixelKit(pixelNamePrefix: String, pixelExpectation: XCTestExpectation) -> PixelKit {
        return PixelKit(dryRun: false,
                        appVersion: "1.0.0",
                        defaultHeaders: [:],
                        defaults: testUserDefault) { pixelName, _, _, _, _, _ in
            if pixelName.hasPrefix(pixelNamePrefix) {
                pixelExpectation.fulfill()
            }
        }
    }

    private func cleanUp(pixelKit: PixelKit) {
        PixelKit.tearDown()
        pixelKit.clearFrequencyHistoryForAllPixels()
    }
}
