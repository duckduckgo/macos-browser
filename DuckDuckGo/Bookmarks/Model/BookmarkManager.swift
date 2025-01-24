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

import Bookmarks
import Cocoa
import Combine
import Common
import os.log
import BrowserServicesKit

protocol BookmarkManager: AnyObject {

    func isUrlBookmarked(url: URL) -> Bool
    func isAnyUrlVariantBookmarked(url: URL) -> Bool
    func isUrlFavorited(url: URL) -> Bool
    func allHosts() -> Set<String>
    func getBookmark(for url: URL) -> Bookmark?
    func getBookmark(forUrl url: String) -> Bookmark?
    func getBookmark(forVariantUrl variantURL: URL) -> Bookmark?
    func getBookmarkFolder(withId id: String) -> BookmarkFolder?
    @discardableResult func makeBookmark(for url: URL, title: String, isFavorite: Bool, index: Int?, parent: BookmarkFolder?) -> Bookmark?
    func makeBookmarks(for websitesInfo: [WebsiteInfo], inNewFolderNamed folderName: String, withinParentFolder parent: ParentFolderType)
    func makeFolder(named title: String, parent: BookmarkFolder?, completion: @escaping (Result<BookmarkFolder, Error>) -> Void)
    func remove(bookmark: Bookmark, undoManager: UndoManager?)
    func remove(folder: BookmarkFolder, undoManager: UndoManager?)
    func remove(objectsWithUUIDs uuids: [String], undoManager: UndoManager?)
    func restore(_ entities: [RestorableBookmarkEntity], undoManager: UndoManager)
    func update(bookmark: Bookmark)
    func update(bookmark: Bookmark, withURL url: URL, title: String, isFavorite: Bool)
    func update(folder: BookmarkFolder)
    func update(folder: BookmarkFolder, andMoveToParent parent: ParentFolderType)
    @discardableResult func updateUrl(of bookmark: Bookmark, to newUrl: URL) -> Bookmark?
    func add(bookmark: Bookmark, to parent: BookmarkFolder?, completion: @escaping (Error?) -> Void)
    func add(objectsWithUUIDs uuids: [String], to parent: BookmarkFolder?, completion: @escaping (Error?) -> Void)
    func update(objectsWithUUIDs uuids: [String], update: @escaping (BaseBookmarkEntity) -> Void, completion: @escaping (Error?) -> Void)
    func canMoveObjectWithUUID(objectUUID uuid: String, to parent: BookmarkFolder) -> Bool
    func move(objectUUIDs: [String], toIndex: Int?, withinParentFolder: ParentFolderType, completion: @escaping (Error?) -> Void)
    func moveFavorites(with objectUUIDs: [String], toIndex: Int?, completion: @escaping (Error?) -> Void)
    func importBookmarks(_ bookmarks: ImportedBookmarks, source: BookmarkImportSource) -> BookmarksImportSummary
    func handleFavoritesAfterDisablingSync()

    /// Searches for bookmarks and folders by title. If query is blank empty list is returned
    ///
    /// - Parameters:
    ///   - query: The query we will use to filter bookmarks. We will check if query is contained in the title.
    /// - Returns: An array of bookmarks that matches the query.
    func search(by query: String) -> [BaseBookmarkEntity]

    // Wrapper definition in a protocol is not supported yet
    var listPublisher: Published<BookmarkList?>.Publisher { get }
    var list: BookmarkList? { get }

    var sortModePublisher: Published<BookmarksSortMode>.Publisher { get }
    var sortMode: BookmarksSortMode { get set }

    func requestSync()
}
extension BookmarkManager {
    @discardableResult func makeBookmark(for url: URL, title: String, isFavorite: Bool) -> Bookmark? {
        makeBookmark(for: url, title: title, isFavorite: isFavorite, index: nil, parent: nil)
    }
    @discardableResult func makeBookmark(for url: URL, title: String, isFavorite: Bool, index: Int?, parent: BookmarkFolder?) -> Bookmark? {
        makeBookmark(for: url, title: title, isFavorite: isFavorite, index: index, parent: parent)
    }
    func move(objectUUIDs: [String], toIndex index: Int?, withinParentFolder parent: ParentFolderType) {
        move(objectUUIDs: objectUUIDs, toIndex: index, withinParentFolder: parent) { _ in }
    }
}
final class LocalBookmarkManager: BookmarkManager {
    static let shared = LocalBookmarkManager()

    init(bookmarkStore: BookmarkStore? = nil, faviconManagement: FaviconManagement? = nil) {
        if let bookmarkStore {
            self.bookmarkStore = bookmarkStore
        }
        if let faviconManagement {
            self.faviconManagement = faviconManagement
        }

        self.subscribeToFavoritesDisplayMode()
        self.sortMode = sortRepository.storedSortMode
    }

    private func subscribeToFavoritesDisplayMode() {
        favoritesDisplayMode = AppearancePreferences.shared.favoritesDisplayMode
        favoritesDisplayModeCancellable = AppearancePreferences.shared.$favoritesDisplayMode
            .dropFirst()
            .sink { [weak self] displayMode in
                self?.favoritesDisplayMode = displayMode
                self?.bookmarkStore.applyFavoritesDisplayMode(displayMode)
                self?.loadBookmarks()
            }
    }

    @Published private(set) var list: BookmarkList?
    var listPublisher: Published<BookmarkList?>.Publisher { $list }

    @Published var sortMode: BookmarksSortMode = .manual {
        didSet {
            sortRepository.storedSortMode = sortMode
        }
    }
    var sortModePublisher: Published<BookmarksSortMode>.Publisher { $sortMode }

    private lazy var bookmarkStore: BookmarkStore = LocalBookmarkStore(bookmarkDatabase: BookmarkDatabase.shared)
    private lazy var faviconManagement: FaviconManagement = FaviconManager.shared
    private lazy var sortRepository: SortBookmarksRepository = SortBookmarksUserDefaults()

    private var favoritesDisplayMode: FavoritesDisplayMode = .displayNative(.desktop)
    private var favoritesDisplayModeCancellable: AnyCancellable?

    // MARK: - Bookmarks

    func loadBookmarks() {
        bookmarkStore.loadAll(type: .topLevelEntities) { [weak self] (topLevelEntities, error) in
            guard error == nil, let topLevelEntities = topLevelEntities else {
                Logger.bookmarks.error("LocalBookmarkManager: Failed to fetch entities.")
                return
            }

            self?.bookmarkStore.loadAll(type: .bookmarks) { [weak self] (bookmarks, error) in
                guard error == nil, let bookmarks = bookmarks else {
                    Logger.bookmarks.error("LocalBookmarkManager: Failed to fetch bookmarks.")
                    return
                }

                self?.bookmarkStore.loadAll(type: .favorites) { [weak self] (favorites, error) in
                    guard error == nil, let favorites = favorites else {
                        Logger.bookmarks.error("LocalBookmarkManager: Failed to fetch favorites.")
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

    /// Checks if any variant of the given URL (http/https, trailing slash) is bookmarked.
    func isAnyUrlVariantBookmarked(url: URL) -> Bool {
        findBookmark(forVariantUrl: url) != nil
    }

    func isUrlFavorited(url: URL) -> Bool {
        return list?[url.absoluteString]?.isFavorite == true
    }

    func allHosts() -> Set<String> {
        Set(list?.allBookmarkURLsOrdered.compactMap(\.urlObject?.host) ?? [])
    }

    func getBookmark(for url: URL) -> Bookmark? {
        return list?[url.absoluteString]
    }

    func getBookmark(forUrl url: String) -> Bookmark? {
        return list?[url]
    }

    /// Returns the bookmark for the given URL or any of its variants (http/https, trailing slash), if it exists.
    func getBookmark(forVariantUrl variantURL: URL) -> Bookmark? {
        findBookmark(forVariantUrl: variantURL)
    }

    /// Finds a bookmark by checking all possible URL variants (http/https, trailing slash).
    private func findBookmark(forVariantUrl url: URL) -> Bookmark? {
        guard let list = list else {
            return nil
        }

        for variant in url.bookmarkButtonUrlVariants() {
            let variantString = variant.absoluteString.lowercased()
            if let bookmark = list.lowercasedItemsDict[variantString]?.first {
                return bookmark
            }
        }
        return nil
    }

    func getBookmarkFolder(withId id: String) -> BookmarkFolder? {
        bookmarkStore.bookmarkFolder(withId: id)
    }

    @discardableResult func makeBookmark(for url: URL, title: String, isFavorite: Bool) -> Bookmark? {
        makeBookmark(for: url, title: title, isFavorite: isFavorite, index: nil, parent: nil)
    }

    @discardableResult func makeBookmark(for url: URL, title: String, isFavorite: Bool, index: Int? = nil, parent: BookmarkFolder? = nil) -> Bookmark? {
        guard list != nil else { return nil }

        guard !isUrlBookmarked(url: url) else {
            Logger.bookmarks.error("LocalBookmarkManager: Url is already bookmarked")
            return nil
        }

        let id = UUID().uuidString
        let bookmark = Bookmark(id: id, url: url.absoluteString, title: title, isFavorite: isFavorite, parentFolderUUID: parent?.id)

        list?.insert(bookmark)
        bookmarkStore.save(bookmark: bookmark, index: index) { [weak self] error  in
            if error != nil {
                self?.list?.remove(bookmark)
                return
            }

            self?.loadBookmarks()
            self?.requestSync()
        }

        return bookmark
    }

    func makeBookmarks(for websitesInfo: [WebsiteInfo], inNewFolderNamed folderName: String, withinParentFolder parent: ParentFolderType) {
        bookmarkStore.saveBookmarks(for: websitesInfo, inNewFolderNamed: folderName, withinParentFolder: parent)
        loadBookmarks()
        requestSync()
    }

    @MainActor
    func remove(bookmark: Bookmark, undoManager: UndoManager?) {
        guard list != nil else { return }
        guard let latestBookmark = getBookmark(forUrl: bookmark.url) else {
            Logger.bookmarks.error("LocalBookmarkManager: Attempt to remove already removed bookmark")
            return
        }

        undoManager?.registerUndoDeleteEntities([bookmark], bookmarkManager: self)
        list?.remove(latestBookmark)
        bookmarkStore.remove(objectsWithUUIDs: [bookmark.id]) { [weak self] error in
            if error != nil {
                self?.list?.insert(bookmark)
            }

            self?.loadBookmarks()
            self?.requestSync()
        }
    }

    @MainActor
    func remove(folder: BookmarkFolder, undoManager: UndoManager?) {
        undoManager?.registerUndoDeleteEntities([folder], bookmarkManager: self)
        bookmarkStore.remove(objectsWithUUIDs: [folder.id]) { [weak self] _ in
            self?.loadBookmarks()
            self?.requestSync()
        }
    }

    @MainActor
    func remove(objectsWithUUIDs uuids: [String], undoManager: UndoManager?) {
        if let undoManager, let entities = bookmarkStore.bookmarkEntities(withIds: uuids) {
            undoManager.registerUndoDeleteEntities(entities, bookmarkManager: self)
        }
        bookmarkStore.remove(objectsWithUUIDs: uuids) { [weak self] _ in
            self?.loadBookmarks()
            self?.requestSync()
        }
    }

    @MainActor
    func restore(_ restorableEntities: [RestorableBookmarkEntity], undoManager: UndoManager) {
        let entitiesAtIndices = restorableEntities.map { entity -> (entity: BaseBookmarkEntity, index: Int?, indexInFavoritesArray: Int?) in
            switch entity {
            case let .bookmark(url: url, title: title, isFavorite: isFavorite, parent: parent, index: index, indexInFavoritesArray: indexInFavoritesArray):
                let bookmark = Bookmark(id: UUID().uuidString, url: url, title: title, isFavorite: isFavorite, parentFolderUUID: parent?.actualId)
                list?.insert(bookmark)
                return (bookmark, index, indexInFavoritesArray)

            case let .folder(title: title, parent: parent, index: index, originalId: originalId):
                return (BookmarkFolder(id: originalId.newId(), title: title, parentFolderUUID: parent?.actualId, children: []), index, nil)
            }
        }
        bookmarkStore.save(entitiesAtIndices: entitiesAtIndices) { [weak self] _ in
            self?.loadBookmarks()
            self?.requestSync()
        }

        var subfolderIds = Set<String>()
        let topLevelUuids = entitiesAtIndices.reduce(into: [String]()) { (uuids, item) in
            if item.entity.isFolder {
                subfolderIds.insert(item.entity.id)
            }
            if let parentId = item.entity.parentFolderUUID, subfolderIds.contains(parentId) {
                // don‘t include a nested item id as its parent will be removed with all its descendants
                return
            }
            uuids.append(item.entity.id)
        }
        undoManager.registerUndo(withTarget: self) { @MainActor this in
            this.remove(objectsWithUUIDs: topLevelUuids, undoManager: undoManager)
        }
    }

    func update(bookmark: Bookmark) {
        guard list != nil else { return }
        guard getBookmark(forUrl: bookmark.url) != nil else {
            Logger.bookmarks.error("LocalBookmarkManager: Failed to update bookmark - not in the list.")
            return
        }

        list?.update(with: bookmark)
        bookmarkStore.update(bookmark: bookmark)
        loadBookmarks()
        requestSync()

    }

    func update(bookmark: Bookmark, withURL url: URL, title: String, isFavorite: Bool) {
        guard list != nil else { return }
        guard getBookmark(forUrl: bookmark.url) != nil else {
            Logger.bookmarks.error("LocalBookmarkManager: Failed to update bookmark url - not in the list.")
            return
        }

        guard let newBookmark = list?.update(bookmark: bookmark, newURL: url.absoluteString, newTitle: title, newIsFavorite: isFavorite) else {
            Logger.bookmarks.error("LocalBookmarkManager: Failed to update URL of bookmark.")
            return
        }

        bookmarkStore.update(bookmark: newBookmark)
        loadBookmarks()
        requestSync()
    }

    func update(folder: BookmarkFolder) {
        bookmarkStore.update(folder: folder)
        loadBookmarks()
        requestSync()
    }

    func update(folder: BookmarkFolder, andMoveToParent parent: ParentFolderType) {
        bookmarkStore.update(folder: folder, andMoveToParent: parent)
        loadBookmarks()
        requestSync()
    }

    func updateUrl(of bookmark: Bookmark, to newUrl: URL) -> Bookmark? {
        guard list != nil else { return nil }
        guard getBookmark(forUrl: bookmark.url) != nil else {
            Logger.bookmarks.error("LocalBookmarkManager: Failed to update bookmark url - not in the list.")
            return nil
        }

        guard let newBookmark = list?.updateUrl(of: bookmark, to: newUrl.absoluteString) else {
            Logger.bookmarks.error("LocalBookmarkManager: Failed to update URL of bookmark.")
            return nil
        }

        bookmarkStore.update(bookmark: newBookmark)
        loadBookmarks()
        requestSync()

        return newBookmark
    }

    // MARK: - Folders

    func makeFolder(named title: String, parent: BookmarkFolder?, completion: @escaping (Result<BookmarkFolder, Error>) -> Void) {
        let folder = BookmarkFolder(id: UUID().uuidString, title: title, parentFolderUUID: parent?.id, children: [])

        bookmarkStore.save(folder: folder) { [weak self] error  in
            if let error {
                completion(.failure(error))
                return
            }
            self?.loadBookmarks()
            self?.requestSync()
            completion(.success(folder))
        }
    }

    func add(bookmark: Bookmark, to parent: BookmarkFolder?, completion: @escaping (Error?) -> Void) {
        add(objectsWithUUIDs: [bookmark.id], to: parent, completion: completion)
    }

    func add(objectsWithUUIDs uuids: [String], to parent: BookmarkFolder?, completion: @escaping (Error?) -> Void) {
        bookmarkStore.add(objectsWithUUIDs: uuids, to: parent) { [weak self] error in
            self?.loadBookmarks()
            if error == nil {
                self?.requestSync()
            }
            completion(error)
        }
    }

    func update(objectsWithUUIDs uuids: [String], update: @escaping (BaseBookmarkEntity) -> Void, completion: @escaping (Error?) -> Void) {
        bookmarkStore.update(objectsWithUUIDs: uuids, update: update) { [weak self] error in
            self?.loadBookmarks()
            if error == nil {
                self?.requestSync()
            }
            completion(error)
        }
    }

    func canMoveObjectWithUUID(objectUUID uuid: String, to parent: BookmarkFolder) -> Bool {
        return bookmarkStore.canMoveObjectWithUUID(objectUUID: uuid, to: parent)
    }

    func move(objectUUIDs: [String], toIndex index: Int?, withinParentFolder parent: ParentFolderType, completion: @escaping (Error?) -> Void) {
        bookmarkStore.move(objectUUIDs: objectUUIDs, toIndex: index, withinParentFolder: parent) { [weak self] error in
            self?.loadBookmarks()
            if error == nil {
                self?.requestSync()
            }
            completion(error)
        }
    }

    func moveFavorites(with objectUUIDs: [String], toIndex index: Int?, completion: @escaping (Error?) -> Void) {
        bookmarkStore.moveFavorites(with: objectUUIDs, toIndex: index) { [weak self] error in
            self?.loadBookmarks()
            if error == nil {
                self?.requestSync()
            }
            completion(error)

        }
    }

    // MARK: - Favicons

    @MainActor(unsafe)
    private func favicon(for host: String?) -> NSImage? {
        if let host = host {
            return faviconManagement.getCachedFavicon(for: host, sizeCategory: .small)?.image
        }

        return nil
    }

    // MARK: - Import

    func importBookmarks(_ bookmarks: ImportedBookmarks, source: BookmarkImportSource) -> BookmarksImportSummary {
        let results = bookmarkStore.importBookmarks(bookmarks, source: source)
        loadBookmarks()
        requestSync()

        return results
    }

    // MARK: - Sync

    func handleFavoritesAfterDisablingSync() {
        bookmarkStore.handleFavoritesAfterDisablingSync()
    }

    func requestSync() {
        Task { @MainActor in
            guard let syncService = NSApp.delegateTyped.syncService else {
                return
            }
            Logger.bookmarks.debug("Requesting sync if enabled")
            syncService.scheduler.notifyDataChanged()
        }
    }

    // MARK: - Debugging

    func resetBookmarks() {
        guard let store = bookmarkStore as? LocalBookmarkStore else {
            return
        }

        store.resetBookmarks { [self] _ in
            self.loadBookmarks()
            self.requestSync()

        }
    }

    // MARK: - Search

    func search(by query: String) -> [BaseBookmarkEntity] {
        guard let topLevelEntities = list?.topLevelEntities, !query.isBlank else {
            return [BaseBookmarkEntity]()
        }

        return search(query: query, in: topLevelEntities)
    }

    private func search(query: String, in bookmarks: [BaseBookmarkEntity]) -> [BaseBookmarkEntity] {
        var result: [BaseBookmarkEntity] = []

        var queue: [BaseBookmarkEntity] = bookmarks
        while !queue.isEmpty {
            let current = queue.removeFirst()

            if current.title.cleaningStringForBookmarkSearch.contains(query.cleaningStringForBookmarkSearch) {
                result.append(current)
            }

            if let folder = current as? BookmarkFolder {
                queue.append(contentsOf: folder.children)
            }
        }

        return result
    }

}
// MARK: - UndoManager
@MainActor
final class KnownBookmarkFolderIdList {
    struct WeakRef {
        weak var value: KnownBookmarkFolderIdList?
    }
    static var restorableFolders = [String: WeakRef]()

    var knownIds: Set<String>
    var actualId: String?

    private init(uuid: String) {
        self.knownIds = [uuid]
        self.actualId = uuid
    }

    static func list(withId uuid: String) -> KnownBookmarkFolderIdList {
        if let list = restorableFolders[uuid]?.value {
            return list
        }
        let list = KnownBookmarkFolderIdList(uuid: uuid)
        restorableFolders[uuid] = WeakRef(value: list)
        return list
    }

    func resolve(withId actualId: String) {
        self.knownIds.insert(actualId)
        self.actualId = actualId
    }

    /// update known folder (ex) id list with actual id so the restored bookmarks referencing an old id are restored to this folder
    func newId() -> String {
        let newId = UUID().uuidString
        self.resolve(withId: newId)
        return newId
    }

    deinit {
        MainActor.assumeIsolated {
            for id in knownIds {
                Self.restorableFolders[id] = nil
            }
        }
    }
}
enum RestorableBookmarkEntity {
    case bookmark(url: String, title: String, isFavorite: Bool, parent: KnownBookmarkFolderIdList?, index: Int?, indexInFavoritesArray: Int?)
    case folder(title: String, parent: KnownBookmarkFolderIdList?, index: Int?, originalId: KnownBookmarkFolderIdList)

    @MainActor
    init(bookmarkEntity: BaseBookmarkEntity, index: Int?, indexInFavoritesArray: Int?) {
        switch bookmarkEntity {
        case let bookmark as Bookmark:
            self = .bookmark(url: bookmark.url, title: bookmark.title, isFavorite: bookmark.isFavorite, parent: bookmark.parentFolderUUID.map(KnownBookmarkFolderIdList.list(withId:)), index: index, indexInFavoritesArray: indexInFavoritesArray)
        case let folder as BookmarkFolder:
            self = .folder(title: folder.title, parent: folder.parentFolderUUID.map(KnownBookmarkFolderIdList.list(withId:)), index: index, originalId: .list(withId: folder.id))
        default:
            fatalError("Unexpected entity type \(bookmarkEntity)")
        }
    }

    var parent: KnownBookmarkFolderIdList? {
        switch self {
        case .bookmark(_, _, _, parent: let parent, index: _, indexInFavoritesArray: _),
             .folder(_, parent: let parent, index: _, originalId: _):
            return parent
        }
    }
    var index: Int? {
        switch self {
        case .bookmark(_, _, _, _, index: let index, indexInFavoritesArray: _),
             .folder(_, _, index: let index, originalId: _):
            return index
        }
    }
    var title: String {
        switch self {
        case .bookmark(_, title: let title, _, _, _, _),
             .folder(title: let title, _, _, originalId: _):
            return title
        }
    }
}
extension [RestorableBookmarkEntity] {
    @MainActor
    init(entities: [BaseBookmarkEntity], bookmarkManager: some BookmarkManager) {
        assert(Set(entities.map(\.parentFolderUUID)).count == 1, "Removing multiple items at different levels has not been implemented/tested!")
        assert(Set(entities.map(\.id)).count == entities.count, "Some entities are repeated in the passed array")

        var folderCache = [String: BookmarkFolder]()
        var removedFolderStack = [(folder: BookmarkFolder, index: Int?)]()
        self = entities.map { entity in

            let parent: BookmarkFolder? = {
                guard let parentId = entity.parentFolderUUID else {
                    return nil
                }
                if let cachedFolder = folderCache[parentId] {
                    return cachedFolder
                }
                guard let folder = bookmarkManager.getBookmarkFolder(withId: parentId) else {
                    return nil
                }
                folderCache[folder.id] = folder
                return folder
            }()

            let siblings = parent?.children ?? bookmarkManager.list?.topLevelEntities
            let index = siblings?.firstIndex(where: { $0.id == entity.id }) ?? -1

            if let folder = entity as? BookmarkFolder {
                removedFolderStack.append((folder, index))
            }

            if let bookmark = entity as? Bookmark, bookmark.isFavorite {
                let indexInFavoritesArray = bookmarkManager.list?.favoriteBookmarks.firstIndex(of: bookmark)
                return RestorableBookmarkEntity(bookmarkEntity: bookmark, index: index, indexInFavoritesArray: indexInFavoritesArray)
            }

            return RestorableBookmarkEntity(bookmarkEntity: entity, index: index, indexInFavoritesArray: nil)
        }.sorted {
            $0.index ?? Int.max < $1.index ?? Int.max
        }
        removedFolderStack.sort {
            $0.index ?? Int.max > $1.index ?? Int.max
        }

        while let (folder, _) = removedFolderStack.popLast() {
            for entity in folder.children {
                // children items of a removed folder are inserted in the original order so we don‘t need to track their indices
                if let bookmark = entity as? Bookmark, bookmark.isFavorite {
                    let indexInFavoritesArray = bookmarkManager.list?.favoriteBookmarks.firstIndex(of: bookmark)
                    self.append(RestorableBookmarkEntity(bookmarkEntity: entity, index: nil, indexInFavoritesArray: indexInFavoritesArray))
                } else {
                    self.append(RestorableBookmarkEntity(bookmarkEntity: entity, index: nil, indexInFavoritesArray: nil))
                }

                if let folder = entity as? BookmarkFolder {
                    removedFolderStack.append((folder, nil))
                }
            }
        }
    }
}

private extension UndoManager {

    @MainActor
    func registerUndoDeleteEntities(_ entities: [BaseBookmarkEntity], bookmarkManager: some BookmarkManager) {
        let restorableEntities = [RestorableBookmarkEntity].init(entities: entities, bookmarkManager: bookmarkManager)
        registerUndo(withTarget: bookmarkManager) { bookmarkManager in
            bookmarkManager.restore(restorableEntities, undoManager: self)
        }
        if !isUndoing {
            let actionName = if entities.count == 1 {
                if entities[0].isFolder {
                    UserText.deleteFolder
                } else {
                    UserText.deleteBookmark
                }
            } else {
                UserText.mainMenuEditDelete
            }
            setActionName(actionName)
        }
    }
}

private extension String {

    /// A computed property that returns a cleaned version of the string for bookmark search purposes.
    /// The cleaning process involves removing accents, stripping out non-alphanumeric characters,
    /// and converting the string to lowercase.
    ///
    /// - Returns: A cleaned string suitable for bookmark searches.
    var cleaningStringForBookmarkSearch: String {
        self.removeAccents()
            .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
            .lowercased()
    }

    /// Removes accents (diacritics) from the string by normalizing it and applying transformations.
    /// This method uses Unicode normalization to decompose characters and then strips away
    /// the combining marks (accents).
    ///
    /// - Returns: A new string with accents removed. For example, café, will return cafe.
    private func removeAccents() -> String {
        // Normalize the string to NFD (Normalization Form Decomposition)
        let normalizedString = self as NSString

        // Apply the transform to remove diacritics
        let transformedString = normalizedString.applyingTransform(.toLatin, reverse: false) ?? ""
        let finalString = transformedString.applyingTransform(.stripCombiningMarks, reverse: false) ?? ""

        return finalString
    }

}
