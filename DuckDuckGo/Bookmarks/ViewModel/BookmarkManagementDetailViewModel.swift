//
//  BookmarkManagementDetailViewModel.swift
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

import Foundation

enum BookmarksContentState: Equatable {
    case empty(emptyState: BookmarksEmptyStateContent)
    case nonEmpty
}

final class BookmarkManagementDetailViewModel {

    private let bookmarkManager: BookmarkManager
    private let bookmarksSearchAndSortMetrics: BookmarksSearchAndSortMetrics

    private var currentSelectionState: BookmarkManagementSidebarViewController.SelectionState = .empty
    private var searchQuery = ""
    private(set) var visibleBookmarks = [BaseBookmarkEntity]()
    private var mode: BookmarksSortMode

    var isSearching: Bool {
        !searchQuery.isBlank
    }

    init(bookmarkManager: BookmarkManager, metrics: BookmarksSearchAndSortMetrics, mode: BookmarksSortMode = .manual) {
        self.bookmarkManager = bookmarkManager
        self.bookmarksSearchAndSortMetrics = metrics
        self.mode = mode
    }

    var contentState: BookmarksContentState {
        if bookmarkManager.list?.topLevelEntities.isEmpty ?? true {
            return .empty(emptyState: .noBookmarks)
        } else if !searchQuery.isEmpty && visibleBookmarks.isEmpty {
            return .empty(emptyState: .noSearchResults)
        }

        return .nonEmpty
    }

    func update(selection: BookmarkManagementSidebarViewController.SelectionState,
                mode: BookmarksSortMode = .manual,
                searchQuery: String = "") {
        self.currentSelectionState = selection
        self.searchQuery = searchQuery
        self.mode = mode
        self.visibleBookmarks = fetchVisibleBookmarks(for: currentSelectionState, searchQuery: searchQuery)
            .sorted(by: mode)

        if !searchQuery.isBlank {
            bookmarksSearchAndSortMetrics.fireSearchExecuted(origin: .manager)
        }
    }

    func totalRows() -> Int {
        return visibleBookmarks.count
    }

    func index(for entity: Bookmark) -> Int? {
        return visibleBookmarks.firstIndex(of: entity)
    }

    func fetchEntity(at row: Int) -> BaseBookmarkEntity? {
        return visibleBookmarks[safe: row]
    }

    func fetchParent() -> BookmarkFolder? {
        switch currentSelectionState {
        case .folder(let bookmarkFolder):
            return bookmarkFolder
        default:
            return nil
        }
    }

    func searchForParent(bookmark: Bookmark) -> BookmarkFolder? {
        guard let parentID = bookmark.parentFolderUUID else {
            return nil
        }

        return bookmarkManager.getBookmarkFolder(withId: parentID)
    }

    // MARK: - Metrics

    func onSortButtonTapped() {
        bookmarksSearchAndSortMetrics.fireSortButtonClicked(origin: .manager)
    }

    func onBookmarkTapped() {
        if !searchQuery.isBlank {
            bookmarksSearchAndSortMetrics.fireSearchResultClicked(origin: .manager)
        }
    }

    // MARK: - Private

    private func fetchVisibleBookmarks(for selectionState: BookmarkManagementSidebarViewController.SelectionState, searchQuery: String) -> [BaseBookmarkEntity] {
        if searchQuery.isBlank {
            return bookmarksForEmptySearch(selectionState)
        } else {
            return searchBookmarks(query: searchQuery)
        }
    }

    private func bookmarksForEmptySearch(_ selectionState: BookmarkManagementSidebarViewController.SelectionState) -> [BaseBookmarkEntity] {
        switch selectionState {
        case .empty:
            return bookmarkManager.list?.topLevelEntities ?? []
        case .folder(let bookmarkFolder):
            return bookmarkFolder.children
        case .favorites:
            return bookmarkManager.list?.favoriteBookmarks ?? []
        }
    }

    private func searchBookmarks(query: String) -> [BaseBookmarkEntity] {
        return bookmarkManager.search(by: query)
    }
}
