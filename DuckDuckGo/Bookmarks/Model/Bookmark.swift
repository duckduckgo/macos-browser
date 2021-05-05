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

            let folder = Folder(id: id, title: title, parentFolderUUID: parentFolderUUID, children: children)

            return folder
        } else {
            guard let url = managedObject.urlEncrypted as? URL else {
                assertionFailure("\(#file): Failed to create Bookmark from BookmarkManagedObject")
                return nil
            }

            return Bookmark(id: id,
                            url: url,
                            title: title,
                            favicon: managedObject.faviconEncrypted as? NSImage,
                            isFavorite: managedObject.isFavorite,
                            parentFolderUUID: parentFolderUUID)
        }
    }

}

final class Folder: BaseBookmarkEntity {

    var parentFolderUUID: UUID?

    private(set) var children: [BaseBookmarkEntity] = []

    var childBookmarks: [Bookmark] {
        return children.compactMap { $0 as? Bookmark }
    }

    var childFolders: [Folder] {
        return children.compactMap { $0 as? Folder }
    }

    init(id: UUID,
         title: String,
         parentFolderUUID: UUID? = nil,
         children: [BaseBookmarkEntity] = []) {

        super.init(id: id, title: title, isFolder: true)

        self.parentFolderUUID = parentFolderUUID
        self.children = children

    }
}

final class Bookmark: BaseBookmarkEntity {

    static func bookmarksFetchRequest() -> NSFetchRequest<BookmarkManagedObject> {
        let request = NSFetchRequest<BookmarkManagedObject>(entityName: "BookmarkManagedObject")
        request.predicate = NSPredicate(format: "isFolder == NO")
        return request
    }

    let url: URL
    var favicon: NSImage?
    var isFavorite: Bool
    var parentFolderUUID: UUID?

    init(id: UUID,
         url: URL,
         title: String,
         favicon: NSImage? = nil,
         isFavorite: Bool,
         parentFolderUUID: UUID? = nil) {

        self.url = url
        self.favicon = favicon
        self.isFavorite = isFavorite
        self.parentFolderUUID = parentFolderUUID

        super.init(id: id, title: title, isFolder: false)
    }

    convenience init(from bookmark: Bookmark, with newUrl: URL) {
        self.init(id: bookmark.id,
                  url: newUrl,
                  title: bookmark.title,
                  favicon: nil,
                  isFavorite: bookmark.isFavorite)
    }

}

extension BaseBookmarkEntity: Equatable {

    static func == (lhs: BaseBookmarkEntity, rhs: BaseBookmarkEntity) -> Bool {
        return lhs.id == rhs.id
    }

}
