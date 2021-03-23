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
    @discardableResult func makeBookmark(for url: URL, title: String, favicon: NSImage?, isFavorite: Bool) -> Bookmark?
    func remove(bookmark: Bookmark)
    func update(bookmark: Bookmark)
    @discardableResult func updateUrl(of bookmark: Bookmark, to newUrl: URL) -> Bookmark?

    // Wrapper definition in a protocol is not supported yet
    var listPublisher: Published<BookmarkList>.Publisher { get }

}

final class LocalBookmarkManager: BookmarkManager {

    static let shared = LocalBookmarkManager()

    private init() {
        subscribeToCachedFavicons()
    }

    init(bookmarkStore: BookmarkStore, faviconService: FaviconService) {
        self.bookmarkStore = bookmarkStore
        self.faviconService = faviconService

        subscribeToCachedFavicons()
    }

    @Published private(set) var list = BookmarkList()
    var listPublisher: Published<BookmarkList>.Publisher { $list }

    private lazy var bookmarkStore: BookmarkStore = LocalBookmarkStore()
    private lazy var faviconService: FaviconService = LocalFaviconService.shared

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

    @discardableResult func makeBookmark(for url: URL, title: String, favicon: NSImage?, isFavorite: Bool) -> Bookmark? {
        guard !isUrlBookmarked(url: url) else {
            os_log("LocalBookmarkManager: Url is already bookmarked", type: .error)
            return nil
        }

        let bookmark = Bookmark(url: url, title: title, favicon: favicon, isFavorite: isFavorite)

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

    func updateUrl(of bookmark: Bookmark, to newUrl: URL) -> Bookmark? {
        guard let latestBookmark = getBookmark(for: bookmark.url) else {
            os_log("LocalBookmarkManager: Failed to update bookmark - not in the list.", type: .error)
            return nil
        }

        let managedObjectId = latestBookmark.managedObjectId

        guard var newBookmark = list.updateUrl(of: bookmark, to: newUrl) else {
            os_log("LocalBookmarkManager: Failed to update URL of bookmark.", type: .error)
            return nil
        }
        newBookmark.managedObjectId = managedObjectId
        bookmarkStore.update(bookmark: newBookmark)
        return newBookmark
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

    // MARK: - Favicons

    private var faviconCancellable: AnyCancellable?

    private func subscribeToCachedFavicons() {
        faviconCancellable = faviconService.cachedFaviconsPublisher
            .sink(receiveValue: { [weak self] (host, favicon) in
                self?.update(favicon: favicon, for: host)
            })
    }

    private func update(favicon: NSImage, for host: String) {
        guard let bookmarks = list.bookmarks() else { return }

        bookmarks
            .filter { $0.url.host == host &&
                $0.favicon?.size.isSmaller(than: favicon.size) ?? true
            }
            .forEach {
                var bookmark = $0
                bookmark.favicon = favicon
                update(bookmark: bookmark)
            }
    }

}
