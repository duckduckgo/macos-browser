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

class MockBookmarkManager: BookmarkManager {
    func cleanUpBookmarksDatabase() {}

    func updateBookmarkDatabaseCleanupSchedule(shouldEnable: Bool) {}

    func isUrlFavorited(url: URL) -> Bool {
        return false
    }

    func isUrlBookmarked(url: URL) -> Bool {
        return false
    }

    func isHostInBookmarks(host: String) -> Bool {
        return false
    }

    func getBookmark(for url: URL) -> DuckDuckGo_Privacy_Browser.Bookmark? {
        return nil
    }

    func getBookmark(forUrl url: String) -> DuckDuckGo_Privacy_Browser.Bookmark? {
        return nil
    }

    func makeBookmark(for url: URL, title: String, isFavorite: Bool) -> DuckDuckGo_Privacy_Browser.Bookmark? {
        return nil
    }

    func makeBookmark(for url: URL, title: String, isFavorite: Bool, index: Int?, parent: DuckDuckGo_Privacy_Browser.BookmarkFolder?) -> DuckDuckGo_Privacy_Browser.Bookmark? {
        return nil
    }

    func makeFolder(for title: String, parent: DuckDuckGo_Privacy_Browser.BookmarkFolder?) -> DuckDuckGo_Privacy_Browser.BookmarkFolder {
        return BookmarkFolder(id: "", title: "")
    }

    func remove(bookmark: DuckDuckGo_Privacy_Browser.Bookmark) {}

    func remove(folder: DuckDuckGo_Privacy_Browser.BookmarkFolder) {}

    func remove(objectsWithUUIDs uuids: [String]) {}

    func update(bookmark: DuckDuckGo_Privacy_Browser.Bookmark) {}

    func update(folder: DuckDuckGo_Privacy_Browser.BookmarkFolder) {}

    func updateUrl(of bookmark: DuckDuckGo_Privacy_Browser.Bookmark, to newUrl: URL) -> DuckDuckGo_Privacy_Browser.Bookmark? {
        return nil
    }

    func add(bookmark: DuckDuckGo_Privacy_Browser.Bookmark, to parent: DuckDuckGo_Privacy_Browser.BookmarkFolder?, completion: @escaping (Error?) -> Void) {}

    func add(objectsWithUUIDs uuids: [String], to parent: DuckDuckGo_Privacy_Browser.BookmarkFolder?, completion: @escaping (Error?) -> Void) {}

    func update(objectsWithUUIDs uuids: [String], update: @escaping (DuckDuckGo_Privacy_Browser.BaseBookmarkEntity) -> Void, completion: @escaping (Error?) -> Void) {}

    func canMoveObjectWithUUID(objectUUID uuid: String, to parent: DuckDuckGo_Privacy_Browser.BookmarkFolder) -> Bool {
        return false
    }

    func move(objectUUIDs: [String], toIndex: Int?, withinParentFolder: DuckDuckGo_Privacy_Browser.ParentFolderType, completion: @escaping (Error?) -> Void) {}

    func moveFavorites(with objectUUIDs: [String], toIndex: Int?, completion: @escaping (Error?) -> Void) {}

    func importBookmarks(_ bookmarks: DuckDuckGo_Privacy_Browser.ImportedBookmarks, source: DuckDuckGo_Privacy_Browser.BookmarkImportSource) -> DuckDuckGo_Privacy_Browser.BookmarkImportResult {
        BookmarkImportResult(successful: 0, duplicates: 0, failed: 0)
    }

    @Published var list: BookmarkList?

    var listPublisher: Published<BookmarkList?>.Publisher { $list }
}
