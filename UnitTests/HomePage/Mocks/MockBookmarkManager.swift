//
//  MockBookmarkManager.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
@testable import DuckDuckGo_Privacy_Browser
@testable import BrowserServicesKit

class MockBookmarkManager: BookmarkManager, URLFavoriteStatusProviding {
    var bookmarksReturnedForSearch = [BaseBookmarkEntity]()
    var wasSearchByQueryCalled = false

    init(bookmarksReturnedForSearch: [BaseBookmarkEntity] = [BaseBookmarkEntity](), wasSearchByQueryCalled: Bool = false, isUrlBookmarked: Bool = false, removeBookmarkCalled: Bool = false, removeFolderCalled: Bool = false, removeObjectsCalled: [String]? = nil, updateBookmarkCalled: Bookmark? = nil, moveObjectsCalled: MoveArgs? = nil, list: BookmarkList? = nil, sortMode: BookmarksSortMode = .manual) {
        self.bookmarksReturnedForSearch = bookmarksReturnedForSearch
        self.wasSearchByQueryCalled = wasSearchByQueryCalled
        self.isUrlBookmarked = isUrlBookmarked
        self.removeBookmarkCalled = removeBookmarkCalled
        self.removeFolderCalled = removeFolderCalled
        self.removeObjectsCalled = removeObjectsCalled
        self.updateBookmarkCalled = updateBookmarkCalled
        self.moveObjectsCalled = moveObjectsCalled
        self.list = list
        self.sortMode = sortMode
    }

    func isUrlFavorited(url: URL) -> Bool {
        return false
    }

    var isUrlBookmarked = false
    func isUrlBookmarked(url: URL) -> Bool {
        return isUrlBookmarked
    }

    var isAnyUrlVariantBookmarked = false
    func isAnyUrlVariantBookmarked(url: URL) -> Bool {
        return isAnyUrlVariantBookmarked
    }

    func allHosts() -> Set<String> {
        return []
    }

    func getBookmark(for url: URL) -> DuckDuckGo_Privacy_Browser.Bookmark? {
        return nil
    }

    func getBookmark(forUrl url: String) -> DuckDuckGo_Privacy_Browser.Bookmark? {
        return nil
    }

    func getBookmark(forVariantUrl url: URL) -> DuckDuckGo_Privacy_Browser.Bookmark? {
        return nil
    }

    func getBookmarkFolder(withId id: String) -> DuckDuckGo_Privacy_Browser.BookmarkFolder? {
        return nil
    }

    func makeBookmark(for url: URL, title: String, isFavorite: Bool, index: Int?, parent: BookmarkFolder?) -> DuckDuckGo_Privacy_Browser.Bookmark? {
        return nil
    }

    func makeBookmarks(for websitesInfo: [DuckDuckGo_Privacy_Browser.WebsiteInfo], inNewFolderNamed folderName: String, withinParentFolder parent: DuckDuckGo_Privacy_Browser.ParentFolderType) {}

    func makeFolder(named title: String, parent: BookmarkFolder?, completion: @escaping (Result<BookmarkFolder, Error>) -> Void) {}

    var removeBookmarkCalled = false
    func remove(bookmark: DuckDuckGo_Privacy_Browser.Bookmark, undoManager: UndoManager?) {
        removeBookmarkCalled = true
    }

    var removeFolderCalled = false
    func remove(folder: DuckDuckGo_Privacy_Browser.BookmarkFolder, undoManager: UndoManager?) {
        removeFolderCalled = true
    }

    var removeObjectsCalled: [String]?
    func remove(objectsWithUUIDs uuids: [String], undoManager: UndoManager?) {
        removeObjectsCalled = uuids
    }

    var updateBookmarkCalled: Bookmark?
    func update(bookmark: DuckDuckGo_Privacy_Browser.Bookmark) {
        updateBookmarkCalled = bookmark
    }

    func update(bookmark: DuckDuckGo_Privacy_Browser.Bookmark, withURL url: URL, title: String, isFavorite: Bool) {}

    func update(folder: DuckDuckGo_Privacy_Browser.BookmarkFolder) {}

    func update(folder: DuckDuckGo_Privacy_Browser.BookmarkFolder, andMoveToParent parent: DuckDuckGo_Privacy_Browser.ParentFolderType) {}

    func updateUrl(of bookmark: DuckDuckGo_Privacy_Browser.Bookmark, to newUrl: URL) -> DuckDuckGo_Privacy_Browser.Bookmark? {
        return nil
    }

    func add(bookmark: DuckDuckGo_Privacy_Browser.Bookmark, to parent: DuckDuckGo_Privacy_Browser.BookmarkFolder?, completion: @escaping (Error?) -> Void) {}

    func add(objectsWithUUIDs uuids: [String], to parent: DuckDuckGo_Privacy_Browser.BookmarkFolder?, completion: @escaping (Error?) -> Void) {}

    func update(objectsWithUUIDs uuids: [String], update: @escaping (DuckDuckGo_Privacy_Browser.BaseBookmarkEntity) -> Void, completion: @escaping (Error?) -> Void) {}

    func canMoveObjectWithUUID(objectUUID uuid: String, to parent: DuckDuckGo_Privacy_Browser.BookmarkFolder) -> Bool {
        return false
    }

    struct MoveArgs: Equatable {
        var objectUUIDs: [String] = []
        var toIndex: Int?
        var withinParentFolder: DuckDuckGo_Privacy_Browser.ParentFolderType
    }
    var moveObjectsCalled: MoveArgs?
    func move(objectUUIDs: [String], toIndex: Int?, withinParentFolder: DuckDuckGo_Privacy_Browser.ParentFolderType, completion: @escaping (Error?) -> Void) {
        moveObjectsCalled = .init(objectUUIDs: objectUUIDs, toIndex: toIndex, withinParentFolder: withinParentFolder)
    }

    func moveFavorites(with objectUUIDs: [String], toIndex: Int?, completion: @escaping (Error?) -> Void) {}

    func importBookmarks(_ bookmarks: DuckDuckGo_Privacy_Browser.ImportedBookmarks, source: DuckDuckGo_Privacy_Browser.BookmarkImportSource) -> BrowserServicesKit.BookmarksImportSummary {
        BookmarksImportSummary(successful: 0, duplicates: 0, failed: 0)
    }

    func handleFavoritesAfterDisablingSync() {}

    @Published var list: BookmarkList?

    var listPublisher: Published<BookmarkList?>.Publisher { $list }

    func requestSync() {
    }

    func search(by query: String) -> [BaseBookmarkEntity] {
        wasSearchByQueryCalled = true
        return bookmarksReturnedForSearch
    }

    var sortModePublisher: Published<BookmarksSortMode>.Publisher { $sortMode }

    @Published var sortMode: BookmarksSortMode = .manual

    func restore(_ entities: [RestorableBookmarkEntity], undoManager: UndoManager) {}

}
