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

    private var currentSelectionState: BookmarkManagementSidebarViewController.SelectionState = .empty
    private var searchQuery = ""
    private(set) var visibleBookmarks = [BaseBookmarkEntity]()

    var isSearching: Bool {
        !searchQuery.isBlank
    }

    init(bookmarkManager: BookmarkManager) {
        self.bookmarkManager = bookmarkManager
    }

    var contentState: BookmarksContentState {
        if bookmarkManager.list?.topLevelEntities.isEmpty ?? true {
            return .empty(emptyState: .noBookmarks)
        } else if !searchQuery.isEmpty && visibleBookmarks.isEmpty {
            return .empty(emptyState: .noSearchResults)
        }

        return .nonEmpty
    }

    func update(selection: BookmarkManagementSidebarViewController.SelectionState, searchQuery: String = "") {
        self.currentSelectionState = selection
        self.searchQuery = searchQuery
        self.visibleBookmarks = fetchVisibleBookmarks(for: currentSelectionState, searchQuery: searchQuery)
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

    func fetchEntityAndParent(at row: Int) -> (entity: BaseBookmarkEntity?, parentFolder: BookmarkFolder?) {
        switch currentSelectionState {
        case .folder(let bookmarkFolder):
            return (visibleBookmarks[safe: row], bookmarkFolder)
        default:
            return (visibleBookmarks[safe: row], nil)
        }
    }

    func searchForParent(bookmark: Bookmark) -> BookmarkFolder? {
        guard let parentID = bookmark.parentFolderUUID else {
            return nil
        }

        return bookmarkManager.getBookmarkFolder(withId: parentID)
    }

    // MARK: - Drag and drop

    func validateDrop(pasteboardItems: [NSPasteboardItem]?,
                      proposedRow row: Int,
                      proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if let proposedDestination = fetchEntity(at: row), proposedDestination.isFolder {
            if let bookmarks = PasteboardBookmark.pasteboardBookmarks(with: pasteboardItems) {
                return validateDrop(for: bookmarks, destination: proposedDestination)
            }

            if let folders = PasteboardFolder.pasteboardFolders(with: pasteboardItems) {
                return validateDrop(for: folders, destination: proposedDestination)
            }

            return .none
        } else {
            // We only want to allow dropping in the same level when not searching
            if dropOperation == .above && searchQuery.isBlank {
                return .move
            } else {
                return .none
            }
        }
    }

    private func validateDrop(for draggedBookmarks: Set<PasteboardBookmark>, destination: BaseBookmarkEntity) -> NSDragOperation {
        guard destination is BookmarkFolder else {
            return .none
        }

        return .move
    }

    private func validateDrop(for draggedFolders: Set<PasteboardFolder>, destination: BaseBookmarkEntity) -> NSDragOperation {
        guard let destinationFolder = destination as? BookmarkFolder else {
            return .none
        }

        for folderID in draggedFolders.map(\.id) where !bookmarkManager.canMoveObjectWithUUID(objectUUID: folderID, to: destinationFolder) {
            return .none
        }

        let tryingToDragOntoSameFolder = draggedFolders.contains { folder in
            return folder.id == destination.id
        }

        if tryingToDragOntoSameFolder {
            return .none
        }

        return .move
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
