//
//  Bookmark.swift
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
import Bookmarks

internal class BaseBookmarkEntity: Identifiable, Equatable, Hashable {

    static func singleEntity(with uuid: String) -> NSFetchRequest<BookmarkEntity> {
        let request = BookmarkEntity.fetchRequest()
        request.predicate = NSPredicate(format: "%K == %@ AND %K == NO AND (%K == NO OR %K == nil)",
                                        #keyPath(BookmarkEntity.uuid), uuid,
                                        #keyPath(BookmarkEntity.isPendingDeletion),
                                        #keyPath(BookmarkEntity.isStub), #keyPath(BookmarkEntity.isStub))
        return request
    }

    static func favorite(with uuid: String, favoritesFolder: BookmarkEntity) -> NSFetchRequest<BookmarkEntity> {
        let request = BookmarkEntity.fetchRequest()
        request.predicate = NSPredicate(format: "%K == %@ AND %K CONTAINS %@ AND %K == NO AND %K == NO AND (%K == NO OR %K == nil)",
                                        #keyPath(BookmarkEntity.uuid),
                                        uuid as CVarArg,
                                        #keyPath(BookmarkEntity.favoriteFolders),
                                        favoritesFolder,
                                        #keyPath(BookmarkEntity.isFolder),
                                        #keyPath(BookmarkEntity.isPendingDeletion),
                                        #keyPath(BookmarkEntity.isStub), #keyPath(BookmarkEntity.isStub))
        return request
    }

    static func entities(with identifiers: [String]) -> NSFetchRequest<BookmarkEntity> {
        let request = BookmarkEntity.fetchRequest()
        request.predicate = NSPredicate(format: "%K IN %@ AND %K == NO AND (%K == NO OR %K == nil)",
                                        #keyPath(BookmarkEntity.uuid), identifiers,
                                        #keyPath(BookmarkEntity.isPendingDeletion),
                                        #keyPath(BookmarkEntity.isStub), #keyPath(BookmarkEntity.isStub))
        return request
    }

    let id: String
    var title: String
    let isFolder: Bool
    let parentFolderUUID: String?

    fileprivate init(id: String, title: String, isFolder: Bool, parentFolderUUID: String?) {
        self.id = id
        self.title = title
        self.isFolder = isFolder
        self.parentFolderUUID = parentFolderUUID
    }

    static func from(
        managedObject: BookmarkEntity,
        parentFolderUUID: String? = nil,
        favoritesDisplayMode: FavoritesDisplayMode
    ) -> BaseBookmarkEntity? {

        guard let id = managedObject.uuid,
              let title = managedObject.title else {
            assertionFailure("\(#file): Failed to create BaseBookmarkEntity from BookmarkManagedObject")
            return nil
        }

        if managedObject.isFolder {
            let children: [BaseBookmarkEntity] = managedObject.childrenArray.compactMap {
                return BaseBookmarkEntity.from(managedObject: $0, parentFolderUUID: id, favoritesDisplayMode: favoritesDisplayMode)
            }

            let folder = BookmarkFolder(id: id, title: title, parentFolderUUID: parentFolderUUID, children: children)

            return folder
        } else {
            guard let url = managedObject.url else {
                assertionFailure("\(#file): Failed to create Bookmark from BookmarkManagedObject")
                return nil
            }

            return Bookmark(id: id,
                            url: url,
                            title: title,
                            isFavorite: managedObject.isFavorite(on: favoritesDisplayMode.displayedFolder),
                            parentFolderUUID: parentFolderUUID)
        }
    }

    // Subclasses needs to override to check equality on their properties
    func isEqual(to instance: BaseBookmarkEntity) -> Bool {
        id == instance.id &&
        title == instance.title &&
        isFolder == instance.isFolder
    }

    static func == (lhs: BaseBookmarkEntity, rhs: BaseBookmarkEntity) -> Bool {
        return type(of: lhs) == type(of: rhs) && lhs.isEqual(to: rhs)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(isFolder)
    }

}

final class BookmarkFolder: BaseBookmarkEntity {

    static func bookmarkFoldersFetchRequest() -> NSFetchRequest<BookmarkEntity> {
        let request = BookmarkEntity.fetchRequest()
        request.predicate = NSPredicate(format: "%K == YES AND %K == NO AND (%K == NO OR %K == nil)",
                                        #keyPath(BookmarkEntity.isFolder),
                                        #keyPath(BookmarkEntity.isPendingDeletion),
                                        #keyPath(BookmarkEntity.isStub), #keyPath(BookmarkEntity.isStub))
        return request
    }

    let children: [BaseBookmarkEntity]
    let totalChildBookmarks: Int

    var childBookmarks: [Bookmark] {
        return children.compactMap { $0 as? Bookmark }
    }

    var childFolders: [BookmarkFolder] {
        return children.compactMap { $0 as? BookmarkFolder }
    }

    init(id: String, title: String, parentFolderUUID: String? = nil, children: [BaseBookmarkEntity] = []) {
        self.children = children

        let childFolders = children.compactMap({ $0 as? BookmarkFolder })
        let childBookmarks = children.compactMap({ $0 as? Bookmark })
        let subfolderBookmarksCount = childFolders.reduce(0) { total, folder in return total + folder.totalChildBookmarks }

        self.totalChildBookmarks = childBookmarks.count + subfolderBookmarksCount

        super.init(id: id, title: title, isFolder: true, parentFolderUUID: parentFolderUUID)
    }

    override func isEqual(to instance: BaseBookmarkEntity) -> Bool {
        guard let folder = instance as? BookmarkFolder else {
            return false
        }
        return id == folder.id &&
        title == folder.title &&
        isFolder == folder.isFolder &&
        isParentFolderEqual(lhs: parentFolderUUID, rhs: folder.parentFolderUUID) &&
        children == folder.children
    }

    override func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(isFolder)
        hasher.combine(parentFolderUUID)
        hasher.combine(children)
    }

    // In some cases a bookmark folder that is child of the root folder has its `parentFolderUUID` set to `bookmarks_root`. In some other cases is nil. Making sure that comparing a `nil` and a `bookmarks_root` does not return false. Probably would be good idea to remove the optionality of `parentFolderUUID` in the future and set it to `bookmarks_root` when needed.
    private func isParentFolderEqual(lhs: String?, rhs: String?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.some(let lhsValue), .some(let rhsValue)):
            return lhsValue == rhsValue
        case (.some(let value), .none), (.none, .some(let value)):
            return value == "bookmarks_root"
        }
    }

}

final class Bookmark: BaseBookmarkEntity {

    static func bookmarksFetchRequest() -> NSFetchRequest<BookmarkEntity> {
        let request = BookmarkEntity.fetchRequest()
        request.predicate = NSPredicate(format: "%K == NO AND %K == NO AND (%K == NO OR %K == nil)",
                                        #keyPath(BookmarkEntity.isFolder),
                                        #keyPath(BookmarkEntity.isPendingDeletion),
                                        #keyPath(BookmarkEntity.isStub), #keyPath(BookmarkEntity.isStub))
        return request
    }

    let url: String
    var isFavorite: Bool

    public var urlObject: URL? {
        return url.isBookmarklet() ? url.toEncodedBookmarklet() : URL(string: url)
    }

    let faviconManagement: FaviconManagement
    @MainActor(unsafe)
    func favicon(_ sizeCategory: Favicon.SizeCategory) -> NSImage? {
        if let duckPlayerFavicon = DuckPlayer.shared.image(for: self) {
            return duckPlayerFavicon
        }

        if let url = urlObject {
            return faviconManagement.getCachedFavicon(for: url, sizeCategory: sizeCategory)?.image
        } else {
            return faviconManagement.getCachedFavicon(for: url, sizeCategory: sizeCategory)?.image
        }
    }

    init(id: String, url: String, title: String, isFavorite: Bool, parentFolderUUID: String? = nil, faviconManagement: FaviconManagement = FaviconManager.shared) {
        self.url = url
        self.isFavorite = isFavorite
        self.faviconManagement = faviconManagement

        super.init(id: id, title: title, isFolder: false, parentFolderUUID: parentFolderUUID)
    }

    convenience init(from bookmark: Bookmark, with newUrl: String) {
        self.init(id: bookmark.id,
                  url: newUrl,
                  title: bookmark.title,
                  isFavorite: bookmark.isFavorite,
                  parentFolderUUID: bookmark.parentFolderUUID)
    }

    convenience init(from bookmark: Bookmark, withNewUrl url: String, title: String, isFavorite: Bool) {
        self.init(id: bookmark.id,
                  url: url,
                  title: title,
                  isFavorite: isFavorite,
                  parentFolderUUID: bookmark.parentFolderUUID)
    }

    override func isEqual(to instance: BaseBookmarkEntity) -> Bool {
        guard let bookmark = instance as? Bookmark else {
            return false
        }
        return id == bookmark.id &&
        title == bookmark.title &&
        isFolder == bookmark.isFolder &&
        url == bookmark.url &&
        isFavorite == bookmark.isFavorite &&
        parentFolderUUID == bookmark.parentFolderUUID
    }

    override func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(isFolder)
        hasher.combine(url)
        hasher.combine(isFavorite)
        hasher.combine(parentFolderUUID)
    }

}
extension BaseBookmarkEntity: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case let folder as BookmarkFolder:
            folder.folderDebugDescription
        case let bookmark as Bookmark:
            bookmark.bookmarkDebugDescription
        default:
            fatalError("Unexpected entity type: \(self)")
        }
    }
}
extension BookmarkFolder {
    fileprivate var folderDebugDescription: String {
        "<BookmarkFolder \(id) \"\(title)\" parent: \(parentFolderUUID ?? "root") children: [\(children.map(\.debugDescription))]>"
    }
}
extension Bookmark {
    fileprivate var bookmarkDebugDescription: String {
        "<Bookmark\(isFavorite ? "⭐️" : "") \(id) title: \"\(title)\" url: \"\(url)\" parent: \(parentFolderUUID ?? "root")>"
    }
}

extension Array where Element == BaseBookmarkEntity {
    func sorted(by sortMode: BookmarksSortMode) -> [BaseBookmarkEntity] {
        switch sortMode {
        case .manual:
            return self
        case .nameAscending:
            return self.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .nameDescending:
            return self.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        }
    }
}
