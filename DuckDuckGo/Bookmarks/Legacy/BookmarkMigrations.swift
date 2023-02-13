//
//  BookmarkMigrations.swift
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
import Bookmarks
import Persistence
import os.log

fileprivate extension UUID {

    static var rootBookmarkFolderUUID: UUID {
        return UUID(uuidString: LegacyBookmarkStore.Constants.rootFolderUUID)!
    }

    static var favoritesFolderUUID: UUID {
        return UUID(uuidString: LegacyBookmarkStore.Constants.favoritesFolderUUID)!
    }

}

final class LegacyBookmarkQueries {

    static func singleEntity(with uuid: UUID) -> NSFetchRequest<BookmarkManagedObject> {
        let request = NSFetchRequest<BookmarkManagedObject>(entityName: "BookmarkManagedObject")
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        return request
    }

    static func favorite(with uuid: UUID) -> NSFetchRequest<BookmarkManagedObject> {
        let request = NSFetchRequest<BookmarkManagedObject>(entityName: "BookmarkManagedObject")
        request.predicate = NSPredicate(format: "id == %@ AND %K != nil AND %K == NO",
                                        uuid as CVarArg,
                                        #keyPath(BookmarkManagedObject.favoritesFolder),
                                        #keyPath(BookmarkManagedObject.isFolder))
        return request
    }

    static func entities(with identifiers: [UUID]) -> NSFetchRequest<BookmarkManagedObject> {
        let request = NSFetchRequest<BookmarkManagedObject>(entityName: "BookmarkManagedObject")
        request.predicate = NSPredicate(format: "id IN %@", identifiers)
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

    static func bookmarksAndFoldersFetchRequest() -> NSFetchRequest<BookmarkManagedObject> {
        return BookmarkManagedObject.fetchRequest()
    }
}

struct ToLegacyStoreBookmarkMigrations {

    func migrate(context: NSManagedObjectContext) {
        migrateTopLevelStorageToRootLevelBookmarksFolder(context: context)
        migrateToFavoritesFolder(context: context)
    }

    // TODO: make it work on legacy stack IF there are bookmarks
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
            Pixel.fire(.debug(event: .bookmarksStoreRootFolderMigrationFailed, error: error))
        }
    }

    private func migrateToFavoritesFolder(context: NSManagedObjectContext) {
        // 1. Create Favorites Folder if needed
        // 2. Create a relationship between all favorites and the Favorites Folder

        let favoritesFolderFetchRequest = Bookmark.favoritesFolderFetchRequest()

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
            Pixel.fire(.debug(event: .bookmarksStoreRootFolderMigrationFailed, error: error))
        }
    }
}

public class LegacyBookmarksStoreMigration {

    internal enum LegacyTopLevelFolderType {
        case favorite
        case bookmark
    }

    public static func migrate(from legacyStorage: CoreDataDatabase?,
                               to context: NSManagedObjectContext) {
        if let legacyStorage = legacyStorage {
            // Perform migration from legacy store.
            let source = legacyStorage.makeContext(concurrencyType: .privateQueueConcurrencyType)
            source.performAndWait {
                LegacyBookmarksStoreMigration.migrate(source: source,
                                                      destination: context)
            }
        } else {
            // Initialize structure if needed
            BookmarkUtils.prepareFoldersStructure(in: context)
            if context.hasChanges {
                do {
                    try context.save(onErrorFire: .bookmarksCouldNotPrepareDatabase)
                } catch {
                    Thread.sleep(forTimeInterval: 1)
                    fatalError("Could not prepare Bookmarks DB structure")
                }
            }
        }
    }

    private static func fetchTopLevelFolder(in context: NSManagedObjectContext) -> [BookmarkManagedObject] {

        let fetchRequest = NSFetchRequest<BookmarkManagedObject>(entityName: "BookmarkManagedObject")
        fetchRequest.predicate = NSPredicate(format: "%K == nil AND %K == %@",
                                             #keyPath(BookmarkManagedObject.parentFolder),
                                             #keyPath(BookmarkManagedObject.isFolder), true)

        guard let results = try? context.fetch(fetchRequest) else {
            return []
        }

        // In case of corruption, we can cat more than one 'root'
        return results
    }

    // swiftlint:disable cyclomatic_complexity
    // swiftlint:disable function_body_length

    private static func migrate(source: NSManagedObjectContext, destination: NSManagedObjectContext) {

        // Do not migrate more than once
        guard BookmarkUtils.fetchRootFolder(destination) == nil else {
            Pixel.fire(.debug(event: .bookmarksMigrationAlreadyPerformed))
            return
        }

        BookmarkUtils.prepareFoldersStructure(in: destination)

        guard let newRoot = BookmarkUtils.fetchRootFolder(destination),
              let newFavoritesRoot = BookmarkUtils.fetchFavoritesFolder(destination) else {
            Pixel.fire(.debug(event: .bookmarksMigrationCouldNotPrepareDatabase))
            Thread.sleep(forTimeInterval: 2)
            fatalError("Could not write to Bookmarks DB")
        }

        // Fetch all 'roots' in case we had some kind of inconsistency and duplicated objects
        let bookmarkRoots = fetchTopLevelFolder(in: source)

        var index = 0
        var folderMap = [NSManagedObjectID: BookmarkEntity]()

        var bookmarksToMigrate = [BookmarkManagedObject]()

        var favoriteRoot: BookmarkManagedObject?

        // Map old roots to new one, prepare list of top level bookmarks to migrate
        for folder in bookmarkRoots {
            guard !folder.isFavorite else {
                favoriteRoot = folder
                continue
            }

            folderMap[folder.objectID] = newRoot

            bookmarksToMigrate.append(contentsOf: folder.children?.array as? [BookmarkManagedObject] ?? [])
        }

        var urlToBookmarkMap = [URL: BookmarkEntity]()

        var favoritesToAdd = [BookmarkEntity]()
        // Iterate over bookmarks to migrate
        while index < bookmarksToMigrate.count {

            let objectToMigrate = bookmarksToMigrate[index]

            guard let parent = objectToMigrate.parentFolder,
                  let newParent = folderMap[parent.objectID],
                  let title = objectToMigrate.titleEncrypted as? String else {
                index += 1
                continue
            }

            if objectToMigrate.isFolder {
                let newFolder = BookmarkEntity.makeFolder(title: title,
                                                          parent: newParent,
                                                          context: destination)
                folderMap[objectToMigrate.objectID] = newFolder

                if let children = objectToMigrate.children?.array as? [BookmarkManagedObject] {
                    bookmarksToMigrate.append(contentsOf: children)
                }

            } else if let url = objectToMigrate.urlEncrypted as? URL {

                let newBookmark = BookmarkEntity.makeBookmark(title: title,
                                                              url: url.absoluteString,
                                                              parent: newParent,
                                                              context: destination)

                if objectToMigrate.isFavorite {
                    favoritesToAdd.append(newBookmark)
                }

                urlToBookmarkMap[url] = newBookmark
            }

            index += 1
        }

        // Preserve the order of favorites
        if let oldFavoritesRoot = favoriteRoot,
           let oldFavorites = oldFavoritesRoot.children?.array as? [BookmarkManagedObject] {

            for oldFavorite in oldFavorites.reversed() {

                if let favoriteIndex = favoritesToAdd.firstIndex(where: { $0.title == oldFavorite.titleEncrypted as? String && $0.url == (oldFavorite.urlEncrypted as? URL)?.absoluteString}) {
                    let favorite = favoritesToAdd[favoriteIndex]
                    favorite.addToFavorites(favoritesRoot: newFavoritesRoot)
                    favoritesToAdd.remove(at: favoriteIndex)
                }

            }
        }

        do {
            try destination.save(onErrorFire: .bookmarksMigrationFailed)
        } catch {
            destination.reset()

            BookmarkUtils.prepareFoldersStructure(in: destination)
            do {
                try destination.save(onErrorFire: .bookmarksMigrationCouldNotPrepareDatabaseOnFailedMigration)
            } catch {
                Thread.sleep(forTimeInterval: 2)
                fatalError("Could not write to Bookmarks DB")
            }
        }
    }
    // swiftlint:enable cyclomatic_complexity
    // swiftlint:enable function_body_length

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
