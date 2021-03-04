//
//  BookmarkManager.swift
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

import Cocoa
import os.log
import Combine

protocol BookmarkManager: AnyObject {

    func isUrlBookmarked(url: URL) -> Bool
    func getBookmark(for url: URL) -> Bookmark?
    @discardableResult func makeBookmark(for url: URL, title: String, favicon: NSImage?) -> Bookmark?
    func remove(bookmark: Bookmark)
    func update(bookmark: Bookmark)

    // Wrapper definition in a protocol is not supported yet
    var listPublisher: Published<BookmarkList>.Publisher { get }

}

class LocalBookmarkManager: BookmarkManager {

    static let shared = LocalBookmarkManager()

    private init() {}

    init(bookmarkStore: BookmarkStore) {
        self.bookmarkStore = bookmarkStore
    }

    @Published private(set) var list = BookmarkList()
    var listPublisher: Published<BookmarkList>.Publisher { $list }

    private lazy var bookmarkStore: BookmarkStore = LocalBookmarkStore()

    func loadBookmarks() {
        bookmarkStore.loadAll { [weak self] (bookmarks, error) in
            guard error == nil, let bookmarks = bookmarks else {
                os_log("LocalBookmarkManager: Failed to fetch bookmarks.", type: .error)
                return
            }

            self?.list.reinit(with: bookmarks)
        }
    }

    func isUrlBookmarked(url: URL) -> Bool {
        return list[url] != nil
    }

    func getBookmark(for url: URL) -> Bookmark? {
        return list[url]
    }

    func findBookmarks(with predicate: String) -> Future<[Bookmark], Never> {
        Future { [bookmarks=list.bookmarks()] promise in
            DispatchQueue.global().async {
                let filtered = bookmarks.filter {
                    let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

                    return $0.title.range(of: predicate, options: options, locale: .current) != nil
                        || $0.url.absoluteString.range(of: predicate, options: options, locale: .current) != nil
                }
                promise(.success(filtered))
            }
        }
    }

    @discardableResult func makeBookmark(for url: URL, title: String, favicon: NSImage?) -> Bookmark? {
        guard !isUrlBookmarked(url: url) else {
            os_log("LocalBookmarkManager: Url is already bookmarked", type: .error)
            return nil
        }
        favicon?.size = NSSize.faviconSize
        let bookmark = Bookmark(url: url, title: title, favicon: favicon, isFavorite: false)

        list.insert(bookmark)
        bookmarkStore.save(bookmark: bookmark) { [weak self] success, objectId, _  in
            guard success, let objectId = objectId else {
                self?.list.remove(bookmark)
                return
            }

            // Set the managed object id of created bookmark
            self?.set(objectId: objectId, for: bookmark)
        }
        return bookmark
    }

    func remove(bookmark: Bookmark) {
        guard let latestBookmark = getBookmark(for: bookmark.url) else {
            os_log("LocalBookmarkManager: Attempt to remove already removed bookmark", type: .error)
            return
        }

        list.remove(latestBookmark)
        bookmarkStore.remove(bookmark: latestBookmark) { [weak self] success, _ in
            if !success {
                self?.list.insert(bookmark)
            }
        }
    }

    func update(bookmark: Bookmark) {
        guard let latestBookmark = getBookmark(for: bookmark.url) else {
            os_log("LocalBookmarkManager: Failed to update bookmark - not in the list.", type: .error)
            return
        }

        var bookmark = bookmark
        bookmark.managedObjectId = latestBookmark.managedObjectId

        list.update(with: bookmark)
        bookmarkStore.update(bookmark: bookmark)
    }

    private func set(objectId: NSManagedObjectID, for bookmark: Bookmark) {
        guard var latestBookmark = getBookmark(for: bookmark.url) else {
            // The bookmark was removed in the meantime
            return
        }

        latestBookmark.managedObjectId = objectId
        list.update(with: latestBookmark)

        if bookmark.isFavorite != latestBookmark.isFavorite ||
            bookmark.title != latestBookmark.title ||
            bookmark.favicon != latestBookmark.favicon {
            // Save recent changes to the bookmark (While objectId was unknown, nothing is persisted)
            bookmarkStore.update(bookmark: latestBookmark)
        }
    }

}
