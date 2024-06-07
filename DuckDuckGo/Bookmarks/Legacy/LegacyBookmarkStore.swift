//
//  LegacyBookmarkStore.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import CoreData
import Cocoa
import PixelKit

fileprivate extension UUID {

    static var rootBookmarkFolderUUID: UUID {
        return UUID(uuidString: LegacyBookmarkStore.Constants.rootFolderUUID)!
    }

    static var favoritesFolderUUID: UUID {
        return UUID(uuidString: LegacyBookmarkStore.Constants.favoritesFolderUUID)!
    }

}

final class LegacyBookmarkStore {

    enum Constants {
        static let rootFolderUUID = "87E09C05-17CB-4185-9EDF-8D1AF4312BAF"
        static let favoritesFolderUUID = "23B11CC4-EA56-4937-8EC1-15854109AE35"
    }

    private var context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
        sharedInitialization()
    }

    private func sharedInitialization() {
        migrate(context: context)
    }

    enum BookmarkStoreError: Error {
        case storeDeallocated
        case insertFailed
        case noObjectId
        case badObjectId
        case asyncFetchFailed
    }

}

final class LegacyBookmarkQueries {

    static func singleEntity(with uuid: UUID) -> NSFetchRequest<BookmarkManagedObject> {
        let request = NSFetchRequest<BookmarkManagedObject>(entityName: "BookmarkManagedObject")
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        return request
    }

    static func topLevelEntitiesFetchRequest() -> NSFetchRequest<BookmarkManagedObject> {
        let request = NSFetchRequest<BookmarkManagedObject>(entityName: "BookmarkManagedObject")
        request.predicate = NSPredicate(format: "id != %@ AND parentFolder == nil", UUID.favoritesFolderUUID as CVarArg)
        return request
    }

    static func favoritesFolderFetchRequest() -> NSFetchRequest<BookmarkManagedObject> {
        let request = NSFetchRequest<BookmarkManagedObject>(entityName: "BookmarkManagedObject")
        request.predicate = NSPredicate(format: "id == %@ AND %K == nil AND %K == YES",
                                        UUID.favoritesFolderUUID as CVarArg,
                                        #keyPath(BookmarkManagedObject.parentFolder),
                                        #keyPath(BookmarkManagedObject.isFolder))
        return request
    }
}

// Migrations from very old state to LegacyStore state
extension LegacyBookmarkStore {

    func migrate(context: NSManagedObjectContext) {
        migrateTopLevelStorageToRootLevelBookmarksFolder(context: context)
        migrateToFavoritesFolder(context: context)
    }

    private func migrateTopLevelStorageToRootLevelBookmarksFolder(context: NSManagedObjectContext) {
        // 1. Fetch all top-level entities and check that there isn't an existing root folder
        // 2. If the root folder does not exist, create it
        // 3. Add all other top-level entities as children of the root folder

        let rootFolderFetchRequest = LegacyBookmarkQueries.singleEntity(with: .rootBookmarkFolderUUID)

        let topLevelEntitiesFetchRequest = LegacyBookmarkQueries.topLevelEntitiesFetchRequest()
        topLevelEntitiesFetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BookmarkManagedObject.dateAdded), ascending: true)]
        topLevelEntitiesFetchRequest.returnsObjectsAsFaults = true

        do {
            // 0. Up front, check if a root folder exists but has been moved deeper into the hierarchy, and remove it if so:

            if let existingRootFolder = try context.fetch(rootFolderFetchRequest).first,
               let rootFolderParent = existingRootFolder.parentFolder {

                existingRootFolder.children?.forEach { child in
                    if let bookmarkEntity = child as? BookmarkManagedObject {
                        bookmarkEntity.parentFolder = rootFolderParent
                    } else {
                        assertionFailure("Tried to relocate child that was not a BookmarkManagedObject")
                    }
                }

                // Since the existing root folder's children have been relocated, delete it and let it be recreated later.
                context.delete(existingRootFolder)
            }

            // 1. Get the existing top level entities and check for a root folder:

            var existingTopLevelEntities = try context.fetch(topLevelEntitiesFetchRequest)

            let existingTopLevelFolderIndex = existingTopLevelEntities.firstIndex { entity in
                entity.id == .rootBookmarkFolderUUID
            }

            // Check if there's only one top level folder, and it's the root folder:
            if existingTopLevelFolderIndex != nil, existingTopLevelEntities.count == 1 {
                return
            }

            // 2. Get or create the top level folder:

            let topLevelFolder: BookmarkManagedObject

            if let existingTopLevelFolderIndex = existingTopLevelFolderIndex {
                topLevelFolder = existingTopLevelEntities[existingTopLevelFolderIndex]
                existingTopLevelEntities.remove(at: existingTopLevelFolderIndex)
            } else {
                let managedObject = NSEntityDescription.insertNewObject(forEntityName: BookmarkManagedObject.className(), into: context)

                guard let newTopLevelFolder = managedObject as? BookmarkManagedObject else {
                    assertionFailure("LocalBookmarkStore: Failed to migrate top level entities")
                    return
                }

                newTopLevelFolder.id = .rootBookmarkFolderUUID
                newTopLevelFolder.titleEncrypted = "Root Bookmarks Folder" as NSString
                newTopLevelFolder.isFolder = true
                newTopLevelFolder.dateAdded = NSDate.now

                topLevelFolder = newTopLevelFolder
            }

            // 3. Remove existing favorites folder from top level entities, if it exists:

            if let existingFavoritesFolderIndex = existingTopLevelEntities.firstIndex(where: { $0.id == .favoritesFolderUUID }) {
                existingTopLevelEntities.remove(at: existingFavoritesFolderIndex)
            }

            // 4. Add existing top level entities as children of the new top level folder:

            topLevelFolder.mutableChildren.addObjects(from: existingTopLevelEntities)

            // 5. Save the migration:

            try context.save()
        } catch {
            PixelKit.fire(DebugEvent(GeneralPixel.bookmarksStoreRootFolderMigrationFailed, error: error))
        }
    }

    private func migrateToFavoritesFolder(context: NSManagedObjectContext) {
        // 1. Create Favorites Folder if needed
        // 2. Create a relationship between all favorites and the Favorites Folder

        let favoritesFolderFetchRequest = LegacyBookmarkQueries.favoritesFolderFetchRequest()

        let favoritesFetchRequest = NSFetchRequest<BookmarkManagedObject>(entityName: "BookmarkManagedObject")
        favoritesFetchRequest.predicate = NSPredicate(format: "isFolder == NO AND isFavorite == YES")
        favoritesFetchRequest.sortDescriptors = [.init(key: "dateAdded", ascending: true)]

        do {
            // 0. Up front, check if a Favorites Folder exists, and if it does, return early (already migrated)

            if (try context.fetch(favoritesFolderFetchRequest).first) != nil {
                return
            }

            // 1. Create Favorites Folder
            let managedObject = BookmarkManagedObject.createFavoritesFolder(in: context)

            guard let favoritesFolder = managedObject as? BookmarkManagedObject else {
                assertionFailure("LocalBookmarkStore: Failed to create Favorites Folder")
                return
            }

            try context.save()

            // 2. Get existing favorites:
            let existingFavoritesEntities = try context.fetch(favoritesFetchRequest)

            // 3. Add favorites to Favorites Folder
            favoritesFolder.mutableFavorites.addObjects(from: existingFavoritesEntities)

            // 4. Save the migration:
            try context.save()
        } catch {
            PixelKit.fire(DebugEvent(GeneralPixel.bookmarksStoreRootFolderMigrationFailed, error: error))
        }
    }
}

extension BookmarkManagedObject {

    static func createFavoritesFolder(in context: NSManagedObjectContext) -> NSManagedObject {
        let managedObject = NSEntityDescription.insertNewObject(forEntityName: BookmarkManagedObject.className(), into: context)

        managedObject.setValue(UUID.favoritesFolderUUID, forKey: "id")
        managedObject.setValue("Favorites Folder" as NSString, forKey: "titleEncrypted")
        managedObject.setValue(true, forKey: "isFolder")
        managedObject.setValue(NSDate.now, forKey: "dateAdded")

        return managedObject
    }
}
