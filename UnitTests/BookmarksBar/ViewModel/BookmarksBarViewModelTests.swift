//
//  BookmarksBarViewModelTests.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

class BookmarksBarViewModelTests: XCTestCase {

    @MainActor
    func testWhenClippingTheLastBarItem_AndNoItemsCanBeClipped_ThenNoItemsAreClipped() {
        let manager = createMockBookmarksManager()
        let bookmarksBarViewModel = BookmarksBarViewModel(bookmarkManager: manager, tabCollectionViewModel: .mock())

        let clipped = bookmarksBarViewModel.clipLastBarItem()

        XCTAssertFalse(clipped)
        XCTAssert(bookmarksBarViewModel.clippedItems.isEmpty)
    }

    @MainActor
    func testWhenClippingTheLastBarItem_AndItemsCanBeClipped_ThenItemsAreClipped() {
        let bookmarks = [Bookmark.mock]
        let storeMock = BookmarkStoreMock(bookmarks: bookmarks)

        let manager = createMockBookmarksManager(mockBookmarkStore: storeMock)
        let bookmarksBarViewModel = BookmarksBarViewModel(bookmarkManager: manager, tabCollectionViewModel: .mock())
        bookmarksBarViewModel.update(from: bookmarks, containerWidth: 200)

        let clipped = bookmarksBarViewModel.clipLastBarItem()

        XCTAssertTrue(clipped)
        XCTAssertEqual(bookmarksBarViewModel.clippedItems.count, 1)
    }

    @MainActor
    func testWhenTheBarHasClippedItems_ThenClippedItemsCanBeRestored() {
        let bookmarks = [Bookmark.mock]
        let storeMock = BookmarkStoreMock(bookmarks: bookmarks)

        let manager = createMockBookmarksManager(mockBookmarkStore: storeMock)
        let bookmarksBarViewModel = BookmarksBarViewModel(bookmarkManager: manager, tabCollectionViewModel: .mock())
        bookmarksBarViewModel.update(from: bookmarks, containerWidth: 200)

        let clipped = bookmarksBarViewModel.clipLastBarItem()

        XCTAssert(clipped)
        XCTAssertEqual(bookmarksBarViewModel.clippedItems.count, 1)

        let restored = bookmarksBarViewModel.restoreLastClippedItem()

        XCTAssert(restored)
        XCTAssert(bookmarksBarViewModel.clippedItems.isEmpty)
    }

    @MainActor
    func testWhenUpdatingFromBookmarkEntities_AndTheContainerCannotFitAnyBookmarks_ThenBookmarksAreImmediatelyClipped() {
        let bookmarks = [Bookmark.mock]
        let storeMock = BookmarkStoreMock(bookmarks: bookmarks)

        let manager = createMockBookmarksManager(mockBookmarkStore: storeMock)
        let bookmarksBarViewModel = BookmarksBarViewModel(bookmarkManager: manager, tabCollectionViewModel: .mock())
        bookmarksBarViewModel.update(from: bookmarks, containerWidth: 0)

        XCTAssertEqual(bookmarksBarViewModel.clippedItems.count, 1)
    }

    @MainActor
    func testWhenUpdatingFromBookmarkEntities_AndTheContainerCanFitAllBookmarks_ThenNoBookmarksAreClipped() {
        let bookmarks = [Bookmark.mock]
        let storeMock = BookmarkStoreMock(bookmarks: bookmarks)

        let manager = createMockBookmarksManager(mockBookmarkStore: storeMock)
        let bookmarksBarViewModel = BookmarksBarViewModel(bookmarkManager: manager, tabCollectionViewModel: .mock())
        bookmarksBarViewModel.update(from: bookmarks, containerWidth: 200)

        XCTAssert(bookmarksBarViewModel.clippedItems.isEmpty)
    }

    // MARK: - Bookmarks Delegate

    @MainActor
    func testWhenItemFiresClickedActionThenDelegateReceivesClickItemActionAndPreventClickIsFalse() {
        // GIVEN
        let sut = BookmarksBarViewModel(bookmarkManager: createMockBookmarksManager(), tabCollectionViewModel: .mock())
        let collectionViewItem = BookmarksBarCollectionViewItem()
        let delegateMock = BookmarksBarViewModelDelegateMock()
        sut.delegate = delegateMock
        XCTAssertFalse(delegateMock.didCallClickAction)
        XCTAssertNil(delegateMock.capturedItem)

        // WHEN
        sut.bookmarksBarCollectionViewItemClicked(collectionViewItem)

        // THEN
        XCTAssertTrue(delegateMock.didCallClickAction)
        XCTAssertEqual(delegateMock.capturedItem, collectionViewItem)

    }

    @MainActor
    private func createMockBookmarksManager(mockBookmarkStore: BookmarkStoreMock = BookmarkStoreMock()) -> BookmarkManager {
        let mockFaviconManager = FaviconManagerMock()
        return LocalBookmarkManager(bookmarkStore: mockBookmarkStore, faviconManagement: mockFaviconManager)
    }

}

fileprivate extension TabCollectionViewModel {

    static func mock() -> TabCollectionViewModel {
        let tabCollection = TabCollection()
        let pinnedTabsManager = PinnedTabsManager()
        return TabCollectionViewModel(tabCollection: tabCollection, pinnedTabsManager: pinnedTabsManager)
    }

}

// MARK: - BookmarksBarViewModelDelegateMock

final class BookmarksBarViewModelDelegateMock: BookmarksBarViewModelDelegate {

    private(set) var didCallClickAction = false
    private(set) var capturedItem: BookmarksBarCollectionViewItem?

    func didClick(_ item: DuckDuckGo_Privacy_Browser.BookmarksBarCollectionViewItem) {
        didCallClickAction = true
        capturedItem = item
    }

    func bookmarksBarViewModelWidthForContainer() -> CGFloat {
        0
    }

    func bookmarksBarViewModelReloadedData() {}
    func mouseDidHover(over item: Any) {}
    func dragging(over item: BookmarksBarCollectionViewItem?, updatedWith info: (any NSDraggingInfo)?) {}
    func showDialog(_ dialog: any DuckDuckGo_Privacy_Browser.ModalView) {}

}
