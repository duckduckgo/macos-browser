//
//  BookmarkList.swift
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
import BrowserServicesKit
import Common
import Suggestions
import os.log

struct BookmarkList {

    struct IdentifiableBookmark: Equatable, Suggestions.Bookmark {
        let id: String
        let url: String
        let urlObject: URL?
        let title: String
        let isFavorite: Bool

        init(from bookmark: Bookmark) {
            self.id = bookmark.id
            self.url = bookmark.url
            self.urlObject = URL(string: bookmark.url)
            self.title = bookmark.title
            self.isFavorite = bookmark.isFavorite
        }
    }

    var topLevelEntities: [BaseBookmarkEntity] = []

    private(set) var allBookmarkURLsOrdered: [IdentifiableBookmark]
    private var favoriteBookmarksOrdered: [IdentifiableBookmark]
    private var itemsDict: [String: [Bookmark]] {
        didSet {
            updateLowercasedItemsDict()
        }
    }

    // Copy of itemsDict used for efficient lookups of variant URLs
    private(set) var lowercasedItemsDict: [String: [Bookmark]] = [:]

    var totalBookmarks: Int {
        return allBookmarkURLsOrdered.count
    }

    var favoriteBookmarks: [Bookmark] {
        let bookmarks: [Bookmark] = favoriteBookmarksOrdered.compactMap { favoriteBookmark in
            guard let array = itemsDict[favoriteBookmark.url] else {
                return nil
            }

            return array.first(where: { $0.id == favoriteBookmark.id })
        }

        return bookmarks
    }

    init(entities: [BaseBookmarkEntity] = [], topLevelEntities: [BaseBookmarkEntity] = [], favorites: [BaseBookmarkEntity] = []) {
        let bookmarks = entities.compactMap { $0 as? Bookmark }
        let keysOrdered = bookmarks.compactMap { IdentifiableBookmark(from: $0) }

        var itemsDict = [String: [Bookmark]]()

        for bookmark in bookmarks {
            itemsDict[bookmark.url] = (itemsDict[bookmark.url] ?? []) + [bookmark]
        }

        self.favoriteBookmarksOrdered = favorites.compactMap({$0 as? Bookmark}).map(IdentifiableBookmark.init(from:))
        self.allBookmarkURLsOrdered = keysOrdered
        self.itemsDict = itemsDict
        self.topLevelEntities = topLevelEntities
        updateLowercasedItemsDict()
    }

    mutating func insert(_ bookmark: Bookmark) {
        guard itemsDict[bookmark.url] == nil else {
            Logger.bookmarks.error("BookmarkList: Adding failed, the item already is in the bookmark list")
            return
        }

        allBookmarkURLsOrdered.insert(IdentifiableBookmark(from: bookmark), at: 0)
        itemsDict[bookmark.url] = (itemsDict[bookmark.url] ?? []) + [bookmark]
    }

    subscript(url: String) -> Bookmark? {
        return itemsDict[url]?.first
    }

    mutating func remove(_ bookmark: Bookmark) {
        allBookmarkURLsOrdered.removeAll { $0.id == bookmark.id }

        let existingBookmarks = itemsDict[bookmark.url] ?? []
        let updatedBookmarks = existingBookmarks.filter { $0.id != bookmark.id }

        if updatedBookmarks.isEmpty {
            itemsDict[bookmark.url] = nil
        } else {
            itemsDict[bookmark.url] = updatedBookmarks
        }
    }

    mutating func update(with newBookmark: Bookmark) {
        guard !newBookmark.isFolder else { return }

        guard itemsDict[newBookmark.url] != nil else {
            Logger.bookmarks.debug("BookmarkList: Update failed, no such item in bookmark list")
            return
        }

        guard var updatedBookmarks = itemsDict[newBookmark.url] else {
            assertionFailure("Tried to update a bookmark that didn't exist in the BookmarkList")
            return
        }

        if let index = updatedBookmarks.firstIndex(where: { $0.id == newBookmark.id }) {
            updatedBookmarks[index] = newBookmark
            itemsDict[newBookmark.url] = updatedBookmarks
        } else {
            assertionFailure("Tried to update a bookmark that didn't exist in the BookmarkList")
        }
    }

    mutating func update(bookmark: Bookmark, newURL: String, newTitle: String, newIsFavorite: Bool) -> Bookmark? {
        guard !bookmark.isFolder else { return nil }

        let newBookmark = Bookmark(from: bookmark, withNewUrl: newURL, title: newTitle, isFavorite: newIsFavorite)
        return updateBookmarkList(newBookmark: newBookmark, oldBookmark: bookmark)
    }

    mutating func updateUrl(of bookmark: Bookmark, to newURL: String) -> Bookmark? {
        guard !bookmark.isFolder else { return nil }

        guard itemsDict[newURL] == nil else {
            Logger.bookmarks.debug("BookmarkList: Update failed, new url already in bookmark list")
            return nil
        }

        let newBookmark = Bookmark(from: bookmark, with: newURL)
        return updateBookmarkList(newBookmark: newBookmark, oldBookmark: bookmark)
    }

    func bookmarks() -> [IdentifiableBookmark] {
        return allBookmarkURLsOrdered
    }

    private mutating func updateLowercasedItemsDict() {
        lowercasedItemsDict = itemsDict.reduce(into: [:]) { result, entry in
            let lowercasedKey = entry.key.lowercased()
            if result[lowercasedKey] == nil {
                result[lowercasedKey] = entry.value
            }
        }
    }

}

private extension BookmarkList {

    mutating private func updateBookmarkList(newBookmark: Bookmark, oldBookmark bookmark: Bookmark) -> Bookmark? {
        guard itemsDict[bookmark.url] != nil, let index = allBookmarkURLsOrdered.firstIndex(of: IdentifiableBookmark(from: bookmark)) else {
            Logger.bookmarks.debug("BookmarkList: Update failed, no such item in bookmark list")
            return nil
        }

        let newIdentifiableBookmark = IdentifiableBookmark(from: newBookmark)

        allBookmarkURLsOrdered.remove(at: index)
        allBookmarkURLsOrdered.insert(newIdentifiableBookmark, at: index)

        let existingBookmarks = itemsDict[bookmark.url] ?? []
        let updatedBookmarks = existingBookmarks.filter { $0.id != bookmark.id }

        itemsDict[bookmark.url] = updatedBookmarks
        itemsDict[newBookmark.url] = (itemsDict[newBookmark.url] ?? []) + [newBookmark]

        return newBookmark
    }
}
