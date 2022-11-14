//
//  Bookmark2ToBookmark3MigrationPolicy.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

internal class Bookmark2ToBookmark3MigrationPolicy: NSEntityMigrationPolicy {

    private var favoritesFolder: NSManagedObject?

    override func begin(_ mapping: NSEntityMapping, with manager: NSMigrationManager) throws {
        try super.begin(mapping, with: manager)

        let managedObject = NSEntityDescription.insertNewObject(forEntityName: BookmarkManagedObject.className(), into: manager.destinationContext)

        managedObject.setValue(UUID.favoritesFolderUUID, forKey: "id")
        managedObject.setValue("Favorites Folder" as NSString, forKey: "titleEncrypted")
        managedObject.setValue(true, forKey: "isFolder")
        managedObject.setValue(NSDate.now, forKey: "dateAdded")

        try manager.destinationContext.save()

        self.favoritesFolder = managedObject
        print("Migrating from \(manager.sourceModel.versionIdentifiers) to \(manager.destinationModel.versionIdentifiers)")
    }

    override func createDestinationInstances(forSource sInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        guard let favoritesFolder else {
            assertionFailure("Failed to create Favorites Folder")
            return
        }

        try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)

        guard let bookmark = manager.destinationInstances(forEntityMappingName: mapping.name, sourceInstances: [sInstance]).first else {
            fatalError("Must return Bookmark")
        }

        if sInstance.value(forKey: "isFavorite") as? Bool == true {
            bookmark.setValue(favoritesFolder, forKey: "favoritesFolder")
        } else {
            bookmark.setValue(nil, forKey: "favoritesFolder")
        }
    }
}


//    private func migrateFavoritesToFavoritesFolder() {
//        context.performAndWait {
//            // 1. Fetch all favorites and check that there isn't an existing favorites folder
//            // 2. If the favorites folder does not exist, create it
//            // 3. Add all favorites as children of the favorites folder
//
//            let favoritesFolderFetchRequest = Bookmark.singleEntity(with: .favoritesFolderUUID)
//
//            let favoritesFetchRequest = NSFetchRequest<BookmarkManagedObject>(entityName: "BookmarkManagedObject")
//            favoritesFetchRequest.predicate = NSPredicate(format: "isFolder == NO AND isFavorite == YES")
//            favoritesFetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BookmarkManagedObject.dateAdded), ascending: true)]
//            favoritesFetchRequest.returnsObjectsAsFaults = true
//
//            do {
//                // 0. Up front, check if a favorites folder exists and is in the hierarchy, and update its UUID if so:
//
//                if var existingFavoritesFolder = try self.context.fetch(favoritesFolderFetchRequest).first, existingFavoritesFolder.parentFolder != nil {
//                    existingFavoritesFolder.id = UUID()
//                    try context.save()
//                }
//
//                // 1. Get the existing favorites entities and check for a root folder:
//
//                var existingFavorites = try self.context.fetch(favoritesFetchRequest)
//
//                let existingTopLevelFolderIndex = existingTopLevelEntities.firstIndex { entity in
//                    entity.id == .rootBookmarkFolderUUID
//                }
//
//                // Check if there's only one top level folder, and it's the root folder:
//                if existingTopLevelFolderIndex != nil, existingTopLevelEntities.count == 1 {
//                    return
//                }
//
//                // 2. Get or create the top level folder:
//
//                let topLevelFolder: BookmarkManagedObject
//
//                if let existingTopLevelFolderIndex = existingTopLevelFolderIndex {
//                    topLevelFolder = existingTopLevelEntities[existingTopLevelFolderIndex]
//                    existingTopLevelEntities.remove(at: existingTopLevelFolderIndex)
//                } else {
//                    let managedObject = NSEntityDescription.insertNewObject(forEntityName: BookmarkManagedObject.className(), into: self.context)
//
//                    guard let newTopLevelFolder = managedObject as? BookmarkManagedObject else {
//                        assertionFailure("LocalBookmarkStore: Failed to migrate top level entities")
//                        return
//                    }
//
//                    newTopLevelFolder.id = .rootBookmarkFolderUUID
//                    newTopLevelFolder.titleEncrypted = "Root Bookmarks Folder" as NSString
//                    newTopLevelFolder.isFolder = true
//                    newTopLevelFolder.dateAdded = NSDate.now
//
//                    topLevelFolder = newTopLevelFolder
//                }
//
//                // 3. Add existing top level entities as children of the new top level folder:
//
//                topLevelFolder.mutableChildren.addObjects(from: existingTopLevelEntities)
//
//                // 4. Save the migration:
//
//                try context.save()
//            } catch {
//                Pixel.fire(.debug(event: .bookmarksStoreFavoritesFolderMigrationFailed, error: error))
//            }
//        }
//    }
