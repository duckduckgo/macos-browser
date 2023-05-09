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
import Combine
import Common

protocol BookmarkManager: AnyObject {

    func isUrlBookmarked(url: URL) -> Bool
    func isUrlFavorited(url: URL) -> Bool
    func isHostInBookmarks(host: String) -> Bool
    func getBookmark(for url: URL) -> Bookmark?
    func getBookmark(forUrl url: String) -> Bookmark?
    @discardableResult func makeBookmark(for url: URL, title: String, isFavorite: Bool) -> Bookmark?
    @discardableResult func makeBookmark(for url: URL, title: String, isFavorite: Bool, index: Int?, parent: BookmarkFolder?) -> Bookmark?
    @discardableResult func makeFolder(for title: String, parent: BookmarkFolder?) -> BookmarkFolder
    func remove(bookmark: Bookmark)
    func remove(folder: BookmarkFolder)
    func remove(objectsWithUUIDs uuids: [String])
    func update(bookmark: Bookmark)
    func update(folder: BookmarkFolder)
    @discardableResult func updateUrl(of bookmark: Bookmark, to newUrl: URL) -> Bookmark?
    func add(bookmark: Bookmark, to parent: BookmarkFolder?, completion: @escaping (Error?) -> Void)
    func add(objectsWithUUIDs uuids: [String], to parent: BookmarkFolder?, completion: @escaping (Error?) -> Void)
    func update(objectsWithUUIDs uuids: [String], update: @escaping (BaseBookmarkEntity) -> Void, completion: @escaping (Error?) -> Void)
    func canMoveObjectWithUUID(objectUUID uuid: String, to parent: BookmarkFolder) -> Bool
    func move(objectUUIDs: [String], toIndex: Int?, withinParentFolder: ParentFolderType, completion: @escaping (Error?) -> Void)
    func moveFavorites(with objectUUIDs: [String], toIndex: Int?, completion: @escaping (Error?) -> Void)
    func importBookmarks(_ bookmarks: ImportedBookmarks, source: BookmarkImportSource) -> BookmarkImportResult

    // Wrapper definition in a protocol is not supported yet
    var listPublisher: Published<BookmarkList?>.Publisher { get }
    var list: BookmarkList? { get }

}

final class LocalBookmarkManager: BookmarkManager {

    static let shared = LocalBookmarkManager()

    private init() {}

    init(bookmarkStore: BookmarkStore, faviconManagement: FaviconManagement) {
        self.bookmarkStore = bookmarkStore
        self.faviconManagement = faviconManagement
    }

    @Published private(set) var list: BookmarkList?
    var listPublisher: Published<BookmarkList?>.Publisher { $list }

    private lazy var bookmarkStore: BookmarkStore = LocalBookmarkStore(bookmarkDatabase: BookmarkDatabase.shared)
    private lazy var faviconManagement: FaviconManagement = FaviconManager.shared

    // MARK: - Bookmarks

    func loadBookmarks() {
        bookmarkStore.loadAll(type: .topLevelEntities) { [weak self] (topLevelEntities, error) in
            guard error == nil, let topLevelEntities = topLevelEntities else {
                os_log("LocalBookmarkManager: Failed to fetch entities.", type: .error)
                return
            }

            self?.bookmarkStore.loadAll(type: .bookmarks) { [weak self] (bookmarks, error) in
                guard error == nil, let bookmarks = bookmarks else {
                    os_log("LocalBookmarkManager: Failed to fetch bookmarks.", type: .error)
                    return
                }

                self?.bookmarkStore.loadAll(type: .favorites) { [weak self] (favorites, error) in
                    guard error == nil, let favorites = favorites else {
                        os_log("LocalBookmarkManager: Failed to fetch favorites.", type: .error)
                        return
                    }

                    self?.list = BookmarkList(entities: bookmarks, topLevelEntities: topLevelEntities, favorites: favorites)
                }
            }
        }
    }

    func isUrlBookmarked(url: URL) -> Bool {
        return list?[url.absoluteString] != nil
    }

    func isUrlFavorited(url: URL) -> Bool {
        return list?[url.absoluteString]?.isFavorite == true
    }

    func isHostInBookmarks(host: String) -> Bool {
        return list?.allBookmarkURLsOrdered.contains(where: { bookmark in
            if let url = bookmark.urlObject {
                return url.host == host
            }
            return false
        }) ?? false
    }

    func getBookmark(for url: URL) -> Bookmark? {
        return list?[url.absoluteString]
    }

    func getBookmark(forUrl url: String) -> Bookmark? {
        return list?[url]
    }

    @discardableResult func makeBookmark(for url: URL, title: String, isFavorite: Bool) -> Bookmark? {
        makeBookmark(for: url, title: title, isFavorite: isFavorite, index: nil, parent: nil)
    }

    @discardableResult func makeBookmark(for url: URL, title: String, isFavorite: Bool, index: Int? = nil, parent: BookmarkFolder? = nil) -> Bookmark? {
        guard list != nil else { return nil }

        guard !isUrlBookmarked(url: url) else {
            os_log("LocalBookmarkManager: Url is already bookmarked", type: .error)
            return nil
        }

        let id = UUID().uuidString
        let bookmark = Bookmark(id: id, url: url.absoluteString, title: title, isFavorite: isFavorite, parentFolderUUID: parent?.id)

        list?.insert(bookmark)
        bookmarkStore.save(bookmark: bookmark, parent: parent, index: index) { [weak self] success, _  in
            guard success else {
                self?.list?.remove(bookmark)
                return
            }

            self?.loadBookmarks()
        }

        return bookmark
    }

    func remove(bookmark: Bookmark) {
        guard list != nil else { return }
        guard let latestBookmark = getBookmark(forUrl: bookmark.url) else {
            os_log("LocalBookmarkManager: Attempt to remove already removed bookmark", type: .error)
            return
        }

        list?.remove(latestBookmark)
        bookmarkStore.remove(objectsWithUUIDs: [bookmark.id]) { [weak self] success, _ in
            if !success {
                self?.list?.insert(bookmark)
            }

            self?.loadBookmarks()
        }
    }

    func remove(folder: BookmarkFolder) {
        bookmarkStore.remove(objectsWithUUIDs: [folder.id]) { [weak self] _, _ in
            self?.loadBookmarks()
        }
    }

    func remove(objectsWithUUIDs uuids: [String]) {
        bookmarkStore.remove(objectsWithUUIDs: uuids) { [weak self] _, _ in
            self?.loadBookmarks()
        }
    }

    func update(bookmark: Bookmark) {
        guard list != nil else { return }
        guard getBookmark(forUrl: bookmark.url) != nil else {
            os_log("LocalBookmarkManager: Failed to update bookmark - not in the list.", type: .error)
            return
        }

        list?.update(with: bookmark)
        bookmarkStore.update(bookmark: bookmark)
        loadBookmarks()
    }

    func update(folder: BookmarkFolder) {
        bookmarkStore.update(folder: folder)
        loadBookmarks()
    }

    func updateUrl(of bookmark: Bookmark, to newUrl: URL) -> Bookmark? {
        guard list != nil else { return nil }
        guard getBookmark(forUrl: bookmark.url) != nil else {
            os_log("LocalBookmarkManager: Failed to update bookmark url - not in the list.", type: .error)
            return nil
        }

        guard let newBookmark = list?.updateUrl(of: bookmark, to: newUrl.absoluteString) else {
            os_log("LocalBookmarkManager: Failed to update URL of bookmark.", type: .error)
            return nil
        }

        bookmarkStore.update(bookmark: newBookmark)
        loadBookmarks()

        return newBookmark
    }

    // MARK: - Folders

    @discardableResult func makeFolder(for title: String, parent: BookmarkFolder?) -> BookmarkFolder {
        let folder = BookmarkFolder(id: UUID().uuidString, title: title, parentFolderUUID: parent?.id, children: [])

        bookmarkStore.save(folder: folder, parent: parent) { [weak self] success, _  in
            guard success else {
                return
            }

            self?.loadBookmarks()
        }

        return folder
    }

    func add(bookmark: Bookmark, to parent: BookmarkFolder?, completion: @escaping (Error?) -> Void) {
        add(objectsWithUUIDs: [bookmark.id], to: parent, completion: completion)
    }

    func add(objectsWithUUIDs uuids: [String], to parent: BookmarkFolder?, completion: @escaping (Error?) -> Void) {
        bookmarkStore.add(objectsWithUUIDs: uuids, to: parent) { [weak self] error in
            self?.loadBookmarks()
            completion(error)
        }
    }

    func update(objectsWithUUIDs uuids: [String], update: @escaping (BaseBookmarkEntity) -> Void, completion: @escaping (Error?) -> Void) {
        bookmarkStore.update(objectsWithUUIDs: uuids, update: update) { [weak self] error in
            self?.loadBookmarks()
            completion(error)
        }
    }

    func canMoveObjectWithUUID(objectUUID uuid: String, to parent: BookmarkFolder) -> Bool {
        return bookmarkStore.canMoveObjectWithUUID(objectUUID: uuid, to: parent)
    }

    func move(objectUUIDs: [String], toIndex index: Int?, withinParentFolder parent: ParentFolderType, completion: @escaping (Error?) -> Void) {
        bookmarkStore.move(objectUUIDs: objectUUIDs, toIndex: index, withinParentFolder: parent) { [weak self] error in
            self?.loadBookmarks()
            completion(error)
        }
    }

    func moveFavorites(with objectUUIDs: [String], toIndex index: Int?, completion: @escaping (Error?) -> Void) {
        bookmarkStore.moveFavorites(with: objectUUIDs, toIndex: index) { [weak self] error in
            self?.loadBookmarks()
            completion(error)
        }
    }

    // MARK: - Favicons

    private func favicon(for host: String?) -> NSImage? {
        if let host = host {
            return faviconManagement.getCachedFavicon(for: host, sizeCategory: .small)?.image
        }

        return nil
    }

    // MARK: - Import

    func importBookmarks(_ bookmarks: ImportedBookmarks, source: BookmarkImportSource) -> BookmarkImportResult {
        let results = bookmarkStore.importBookmarks(bookmarks, source: source)
        self.loadBookmarks()

        return results
    }

    // MARK: - Debugging

    func resetBookmarks() {
        guard let store = bookmarkStore as? LocalBookmarkStore else {
            return
        }

        store.resetBookmarks()
        loadBookmarks()
    }

}
