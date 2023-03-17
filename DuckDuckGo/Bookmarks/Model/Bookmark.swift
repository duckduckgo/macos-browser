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

internal class BaseBookmarkEntity {

    static func singleEntity(with uuid: String) -> NSFetchRequest<BookmarkEntity> {
        let request = BookmarkEntity.fetchRequest()
        request.predicate = NSPredicate(format: "%K == %@", #keyPath(BookmarkEntity.uuid), uuid)
        return request
    }

    static func favorite(with uuid: String) -> NSFetchRequest<BookmarkEntity> {
        let request = BookmarkEntity.fetchRequest()
        request.predicate = NSPredicate(format: "%K == %@ AND %K != nil AND %K == NO",
                                        #keyPath(BookmarkEntity.uuid),
                                        uuid as CVarArg,
                                        #keyPath(BookmarkEntity.favoriteFolder),
                                        #keyPath(BookmarkEntity.isFolder))
        return request
    }

    static func entities(with identifiers: [String]) -> NSFetchRequest<BookmarkEntity> {
        let request = BookmarkEntity.fetchRequest()
        request.predicate = NSPredicate(format: "%K IN %@", #keyPath(BookmarkEntity.uuid), identifiers)
        return request
    }

    let id: String
    var title: String
    let isFolder: Bool

    fileprivate init(id: String,
                     title: String,
                     isFolder: Bool) {

        self.id = id
        self.title = title
        self.isFolder = isFolder
    }

    static func from(managedObject: BookmarkEntity, parentFolderUUID: String? = nil) -> BaseBookmarkEntity? {
        guard let id = managedObject.uuid,
              let title = managedObject.title else {
            assertionFailure("\(#file): Failed to create BaseBookmarkEntity from BookmarkManagedObject")
            return nil
        }

        if managedObject.isFolder {
            let children: [BaseBookmarkEntity] = managedObject.childrenArray.compactMap {
                return BaseBookmarkEntity.from(managedObject: $0, parentFolderUUID: id)
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
                            isFavorite: managedObject.isFavorite,
                            parentFolderUUID: parentFolderUUID)
        }
    }

}

final class BookmarkFolder: BaseBookmarkEntity {

    static func bookmarkFoldersFetchRequest() -> NSFetchRequest<BookmarkEntity> {
        let request = BookmarkEntity.fetchRequest()
        request.predicate = NSPredicate(format: "%K == YES", #keyPath(BookmarkEntity.isFolder))
        return request
    }

    let parentFolderUUID: String?
    let children: [BaseBookmarkEntity]
    let totalChildBookmarks: Int

    var childBookmarks: [Bookmark] {
        return children.compactMap { $0 as? Bookmark }
    }

    var childFolders: [BookmarkFolder] {
        return children.compactMap { $0 as? BookmarkFolder }
    }

    init(id: String,
         title: String,
         parentFolderUUID: String? = nil,
         children: [BaseBookmarkEntity] = []) {
        self.parentFolderUUID = parentFolderUUID
        self.children = children

        let childFolders = children.compactMap({ $0 as? BookmarkFolder })
        let childBookmarks = children.compactMap({ $0 as? Bookmark })
        let subfolderBookmarksCount = childFolders.reduce(0) { total, folder in return total + folder.totalChildBookmarks }

        self.totalChildBookmarks = childBookmarks.count + subfolderBookmarksCount

        super.init(id: id, title: title, isFolder: true)
    }
}

final class Bookmark: BaseBookmarkEntity {

    static func bookmarksFetchRequest() -> NSFetchRequest<BookmarkEntity> {
        let request = BookmarkEntity.fetchRequest()
        request.predicate = NSPredicate(format: "%K == NO", #keyPath(BookmarkEntity.isFolder))
        return request
    }

    let url: String
    var isFavorite: Bool
    private(set) var parentFolderUUID: String?

    public var urlObject: URL? {
        return url.isBookmarklet() ? url.toEncodedBookmarklet() : URL(string: url)
    }

    let faviconManagement: FaviconManagement
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

    init(id: String,
         url: String,
         title: String,
         isFavorite: Bool,
         parentFolderUUID: String? = nil,
         faviconManagement: FaviconManagement = FaviconManager.shared) {
        self.url = url
        self.isFavorite = isFavorite
        self.parentFolderUUID = parentFolderUUID
        self.faviconManagement = faviconManagement

        super.init(id: id, title: title, isFolder: false)
    }

    convenience init(from bookmark: Bookmark, with newUrl: String) {
        self.init(id: bookmark.id,
                  url: newUrl,
                  title: bookmark.title,
                  isFavorite: bookmark.isFavorite,
                  parentFolderUUID: bookmark.parentFolderUUID)
    }

}

extension BaseBookmarkEntity: Equatable {

    static func == (lhs: BaseBookmarkEntity, rhs: BaseBookmarkEntity) -> Bool {
        return lhs.id == rhs.id
    }

}
