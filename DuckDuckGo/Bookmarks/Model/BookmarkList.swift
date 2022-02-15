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
import os.log

struct BookmarkList {

    var topLevelEntities: [BaseBookmarkEntity] = []

    private(set) var allBookmarkURLsOrdered: [URL]
    private var favoriteBookmarkURLsOrdered: [URL]
    private var itemsDict: [URL: Bookmark]

    var totalBookmarks: Int {
        return allBookmarkURLsOrdered.count
    }

    var favoriteBookmarks: [Bookmark] {
        return favoriteBookmarkURLsOrdered.compactMap {
            itemsDict[$0]
        }
    }

    init(entities: [BaseBookmarkEntity] = [], topLevelEntities: [BaseBookmarkEntity] = []) {
        let bookmarks = entities.compactMap { $0 as? Bookmark }
        let keysOrdered = bookmarks.compactMap { $0.url }
        var favoriteKeysOrdered = [URL]()

        var itemsDict = [URL: Bookmark]()
        for bookmark in bookmarks {
            itemsDict[bookmark.url] = bookmark

            if bookmark.isFavorite {
                favoriteKeysOrdered.append(bookmark.url)
            }
        }
        
        // Reverse the order of favorites, such that new favorites appear at the top.
        // This will be improved later with the filtering/sorting additions.
        self.favoriteBookmarkURLsOrdered = favoriteKeysOrdered.reversed()
        self.allBookmarkURLsOrdered = keysOrdered
        self.itemsDict = itemsDict
        self.topLevelEntities = topLevelEntities
    }

    mutating func insert(_ bookmark: Bookmark) {
        guard itemsDict[bookmark.url] == nil else {
            os_log("BookmarkList: Adding failed, the item already is in the bookmark list", type: .error)
            return
        }

        allBookmarkURLsOrdered.insert(bookmark.url, at: 0)
        itemsDict[bookmark.url] = bookmark
    }

    subscript(url: URL) -> Bookmark? {
        return itemsDict[url]
    }

    mutating func remove(_ bookmark: Bookmark) {
        allBookmarkURLsOrdered.removeAll { $0 == bookmark.url }
        itemsDict.removeValue(forKey: bookmark.url)
    }

    mutating func update(with bookmark: Bookmark) {
        guard !bookmark.isFolder else { return }

        guard itemsDict[bookmark.url] != nil else {
            os_log("BookmarkList: Update failed, no such item in bookmark list")
            return
        }

        itemsDict[bookmark.url] = bookmark
    }

    mutating func updateUrl(of bookmark: Bookmark, to newUrl: URL) -> Bookmark? {
        guard !bookmark.isFolder else { return nil }

        guard itemsDict[newUrl] == nil else {
            os_log("BookmarkList: Update failed, new url already in bookmark list")
            return nil
        }
        guard itemsDict[bookmark.url] != nil, let index = allBookmarkURLsOrdered.firstIndex(of: bookmark.url) else {
            os_log("BookmarkList: Update failed, no such item in bookmark list")
            return nil
        }

        allBookmarkURLsOrdered.remove(at: index)
        allBookmarkURLsOrdered.insert(newUrl, at: index)

        itemsDict[bookmark.url] = nil
        let newBookmark = Bookmark(from: bookmark, with: newUrl)
        itemsDict[newUrl] = newBookmark
        return newBookmark
    }

    func bookmarks() -> [Bookmark] {
        allBookmarkURLsOrdered
            .map { itemsDict[$0] }
            .compactMap { $0 }
    }

}
