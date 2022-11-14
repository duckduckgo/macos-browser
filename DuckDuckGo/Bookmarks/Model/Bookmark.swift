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

internal class BaseBookmarkEntity {

    static func singleEntity(with uuid: UUID) -> NSFetchRequest<BookmarkManagedObject> {
        let request = NSFetchRequest<BookmarkManagedObject>(entityName: "BookmarkManagedObject")
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        return request
    }

    static func entities(with identifiers: [UUID]) -> NSFetchRequest<BookmarkManagedObject> {
        let request = NSFetchRequest<BookmarkManagedObject>(entityName: "BookmarkManagedObject")
        request.predicate = NSPredicate(format: "id IN %@", identifiers)
        return request
    }

    static func topLevelEntitiesFetchRequest() -> NSFetchRequest<BookmarkManagedObject> {
        let request = NSFetchRequest<BookmarkManagedObject>(entityName: "BookmarkManagedObject")
        request.predicate = NSPredicate(format: "parentFolder == nil")
        return request
    }

    static func bookmarksAndFoldersFetchRequest() -> NSFetchRequest<BookmarkManagedObject> {
        return BookmarkManagedObject.fetchRequest()
    }

    let id: UUID
    var title: String
    let isFolder: Bool

    fileprivate init(id: UUID,
                     title: String,
                     isFolder: Bool) {

        self.id = id
        self.title = title
        self.isFolder = isFolder
    }

    static func from(managedObject: BookmarkManagedObject, parentFolderUUID: UUID? = nil) -> BaseBookmarkEntity? {
        guard let id = managedObject.id,
              let title = managedObject.titleEncrypted as? String else {
            assertionFailure("\(#file): Failed to create BaseBookmarkEntity from BookmarkManagedObject")
            return nil
        }

        if managedObject.isFolder {
            let children: [BaseBookmarkEntity] = managedObject.children?.compactMap {
                guard let baseBookmarkEntity = $0 as? BookmarkManagedObject else { return nil }
                return BaseBookmarkEntity.from(managedObject: baseBookmarkEntity, parentFolderUUID: id)
            } ?? []

            let folder = BookmarkFolder(id: id, title: title, parentFolderUUID: parentFolderUUID, children: children)

            return folder
        } else {
            guard let url = managedObject.urlEncrypted as? URL else {
                assertionFailure("\(#file): Failed to create Bookmark from BookmarkManagedObject")
                return nil
            }

            return Bookmark(id: id,
                            url: url,
                            title: title,
                            oldFavicon: managedObject.faviconEncrypted as? NSImage,
                            isFavorite: managedObject.favoritesFolder != nil,
                            parentFolderUUID: parentFolderUUID)
        }
    }

}

final class BookmarkFolder: BaseBookmarkEntity {

    static func bookmarkFoldersFetchRequest() -> NSFetchRequest<BookmarkManagedObject> {
        let request = NSFetchRequest<BookmarkManagedObject>(entityName: "BookmarkManagedObject")
        request.predicate = NSPredicate(format: "isFolder == YES")
        return request
    }

    let parentFolderUUID: UUID?
    let children: [BaseBookmarkEntity]
    let totalChildBookmarks: Int

    var childBookmarks: [Bookmark] {
        return children.compactMap { $0 as? Bookmark }
    }

    var childFolders: [BookmarkFolder] {
        return children.compactMap { $0 as? BookmarkFolder }
    }

    init(id: UUID,
         title: String,
         parentFolderUUID: UUID? = nil,
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

    static func bookmarksFetchRequest() -> NSFetchRequest<BookmarkManagedObject> {
        let request = NSFetchRequest<BookmarkManagedObject>(entityName: "BookmarkManagedObject")
        request.predicate = NSPredicate(format: "isFolder == NO")
        return request
    }

    static func favoritesFetchRequest() -> NSFetchRequest<BookmarkManagedObject> {
        let request = NSFetchRequest<BookmarkManagedObject>(entityName: "BookmarkManagedObject")
        request.predicate = NSPredicate(format: "isFolder == NO AND favo == YES")
        return request
    }

    let url: URL
    var isFavorite: Bool
    private(set) var parentFolderUUID: UUID?

    // Property oldFavicon can be removed in future updates when favicon cache is built
    var oldFavicon: NSImage?
    let faviconManagement: FaviconManagement
    func favicon(_ sizeCategory: Favicon.SizeCategory) -> NSImage? {
        if let privatePlayerFavicon = PrivatePlayer.shared.image(for: self) {
            return privatePlayerFavicon
        }
        return faviconManagement.getCachedFavicon(for: url, sizeCategory: sizeCategory)?.image ?? oldFavicon
    }

    init(id: UUID,
         url: URL,
         title: String,
         oldFavicon: NSImage? = nil,
         isFavorite: Bool,
         parentFolderUUID: UUID? = nil,
         faviconManagement: FaviconManagement = FaviconManager.shared) {
        self.url = url
        self.oldFavicon = oldFavicon
        self.isFavorite = isFavorite
        self.parentFolderUUID = parentFolderUUID
        self.faviconManagement = faviconManagement

        super.init(id: id, title: title, isFolder: false)
    }

    convenience init(from bookmark: Bookmark, with newUrl: URL) {
        self.init(id: bookmark.id,
                  url: newUrl,
                  title: bookmark.title,
                  oldFavicon: nil,
                  isFavorite: bookmark.isFavorite,
                  parentFolderUUID: bookmark.parentFolderUUID)
    }

}

extension BaseBookmarkEntity: Equatable {

    static func == (lhs: BaseBookmarkEntity, rhs: BaseBookmarkEntity) -> Bool {
        return lhs.id == rhs.id
    }

}
