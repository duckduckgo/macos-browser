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

public class LegacyBookmarksStoreMigration {

    internal enum LegacyTopLevelFolderType {
        case favorite
        case bookmark
    }

    private static func fetchTopLevelFolders(in context: NSManagedObjectContext) -> [BookmarkManagedObject] {

        let fetchRequest = NSFetchRequest<BookmarkManagedObject>(entityName: "BookmarkManagedObject")
        fetchRequest.predicate = NSPredicate(format: "%K == nil AND %K == YES",
                                             #keyPath(BookmarkManagedObject.parentFolder),
                                             #keyPath(BookmarkManagedObject.isFolder))

        guard let results = try? context.fetch(fetchRequest) else {
            return []
        }

        // In case of corruption, we can have more than one 'root'
        return results
    }

    // swiftlint:disable cyclomatic_complexity
    // swiftlint:disable function_body_length
    public static func setupAndMigrate(from source: NSManagedObjectContext,
                                       to destination: NSManagedObjectContext) {

        // Fetch all 'roots' in case we had some kind of inconsistency and duplicated objects
        let bookmarkRoots = fetchTopLevelFolders(in: source)

        // Do not migrate more than once
        guard BookmarkUtils.fetchRootFolder(destination) == nil else {
            // There should be no data left as migration has been done already
            if !bookmarkRoots.isEmpty {
                Pixel.fire(.debug(event: .bookmarksMigrationAlreadyPerformed))
            }
            return
        }

        // Run trough older migrations on source store
        _ = LegacyBookmarkStore(context: source)

        // Prepare destination
        BookmarkUtils.prepareFoldersStructure(in: destination)

        guard let newRoot = BookmarkUtils.fetchRootFolder(destination),
              let newFavoritesRoot = BookmarkUtils.fetchFavoritesFolder(destination) else {
            Pixel.fire(.debug(event: .bookmarksMigrationCouldNotPrepareDatabase))
            Thread.sleep(forTimeInterval: 2)
            fatalError("Could not write to Bookmarks DB")
        }

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
            }

            index += 1
        }

        // Preserve the order of favorites
        if let oldFavoritesRoot = favoriteRoot,
           let oldFavorites = oldFavoritesRoot.favorites?.array as? [BookmarkManagedObject] {

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

            cleanupOldData(in: source)
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

    private static func cleanupOldData(in context: NSManagedObjectContext) {
        let allObjects = (try? context.fetch(BookmarkManagedObject.fetchRequest())) ?? []

        allObjects.forEach { context.delete($0) }

        try? context.save(onErrorFire: .bookmarksMigrationCouldNotRemoveOldStore)
    }

}
