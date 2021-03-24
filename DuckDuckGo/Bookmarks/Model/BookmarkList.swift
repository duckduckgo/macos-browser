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

    private var keysOrdered: [URL]
    private var itemsDict: [URL: Bookmark]

    init(bookmarks: [Bookmark] = []) {
        let keysOrdered = bookmarks.map { $0.url }

        var itemsDict = [URL: Bookmark]()
        bookmarks.forEach { itemsDict[$0.url] = $0 }

        self.keysOrdered = keysOrdered
        self.itemsDict = itemsDict
    }

    mutating func insert(_ bookmark: Bookmark) {
        guard itemsDict[bookmark.url] == nil else {
            os_log("BookmarkList: Adding failed, the item already is in the bookmark list", type: .error)
            return
        }

        keysOrdered.insert(bookmark.url, at: 0)
        itemsDict[bookmark.url] = bookmark
    }

    subscript(url: URL) -> Bookmark? {
        return itemsDict[url]
    }

    mutating func remove(_ bookmark: Bookmark) {
        keysOrdered.removeAll { $0 == bookmark.url }
        itemsDict.removeValue(forKey: bookmark.url)
    }

    mutating func update(with bookmark: Bookmark) {
        guard itemsDict[bookmark.url] != nil else {
            os_log("BookmarkList: Update failed, no such item in bookmark list")
            return
        }

        itemsDict[bookmark.url] = bookmark
    }

    mutating func updateUrl(of bookmark: Bookmark, to newUrl: URL) -> Bookmark? {
        guard itemsDict[newUrl] == nil else {
            os_log("BookmarkList: Update failed, new url already in bookmark list")
            return nil
        }
        guard itemsDict[bookmark.url] != nil, let index = keysOrdered.firstIndex(of: bookmark.url) else {
            os_log("BookmarkList: Update failed, no such item in bookmark list")
            return nil
        }

        keysOrdered.remove(at: index)
        keysOrdered.insert(newUrl, at: index)

        itemsDict[bookmark.url] = nil
        let newBookmark = Bookmark(from: bookmark, with: newUrl)
        itemsDict[newUrl] = newBookmark
        return newBookmark
    }

    func bookmarks() -> [Bookmark] {
        keysOrdered
            .map { itemsDict[$0] }
            .compactMap { $0 }
    }

}
