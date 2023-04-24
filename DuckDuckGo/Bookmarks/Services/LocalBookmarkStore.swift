//
//  LocalBookmarkStore.swift
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

import Common
import Foundation
import CoreData
import Bookmarks
import Cocoa

// swiftlint:disable:next type_body_length
final class LocalBookmarkStore: BookmarkStore {

    init(bookmarkDatabase: BookmarkDatabase) {
        self.context = bookmarkDatabase.db.makeContext(concurrencyType: .privateQueueConcurrencyType)
        sharedInitialization()
    }

    init(context: NSManagedObjectContext) {
        self.context = context
        sharedInitialization()
    }

    private func sharedInitialization() {
        removeInvalidBookmarkEntities()
        cacheReadOnlyTopLevelBookmarksFolders()
    }

    enum BookmarkStoreError: Error {
        case storeDeallocated
        case noObjectId
        case badObjectId
        case asyncFetchFailed
        case missingParent
    }

    private let context: NSManagedObjectContext

    /// All entities within the bookmarks store must exist under this root level folder. Because this value is used so frequently, it is cached here.
    private var rootLevelFolder: BookmarkEntity?

    /// All favorites must additionally be children of this special folder. Because this value is used so frequently, it is cached here.
    private var favoritesFolder: BookmarkEntity?

    private func cacheReadOnlyTopLevelBookmarksFolders() {
        context.performAndWait {
            guard let folder = BookmarkUtils.fetchRootFolder(context) else {
                fatalError("Top level folder missing")
            }

            self.rootLevelFolder = folder
            self.favoritesFolder = BookmarkUtils.fetchFavoritesFolder(context)
        }
    }

    // MARK: - Bookmarks

    func loadAll(type: BookmarkStoreFetchPredicateType, completion: @escaping ([BaseBookmarkEntity]?, Error?) -> Void) {
        func mainQueueCompletion(bookmarks: [BaseBookmarkEntity]?, error: Error?) {
            DispatchQueue.main.async {
                completion(bookmarks, error)
            }
        }

        context.perform {
            do {
                self.context.refreshAllObjects()
                let results: [BookmarkEntity]

                switch type {
                case .bookmarks:
                    let fetchRequest = Bookmark.bookmarksFetchRequest()
                    fetchRequest.returnsObjectsAsFaults = false
                    results = try self.context.fetch(fetchRequest)
                case .topLevelEntities:
                    // When fetching the top level entities, the root folder will be returned. To make things simpler for the caller, this function
                    // will return the children of the root folder, as the root folder is an implementation detail of the bookmarks store.
                    let rootFolder = BookmarkUtils.fetchRootFolder(self.context)
                    results = rootFolder?.childrenArray ?? []
                case .favorites:
                    results = self.favoritesFolder?.favoritesArray ?? []
                }

                let entities: [BaseBookmarkEntity] = results.compactMap { entity in
                    BaseBookmarkEntity.from(managedObject: entity,
                                            parentFolderUUID: entity.parent?.uuid)
                }

                mainQueueCompletion(bookmarks: entities, error: nil)
            } catch let error {
                completion(nil, error)
            }
        }
    }

    func save(bookmark: Bookmark, parent: BookmarkFolder?, index: Int?, completion: @escaping (Bool, Error?) -> Void) {
        context.perform { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false, BookmarkStoreError.storeDeallocated) }
                return
            }

            let parentEntity: BookmarkEntity
            if let parent = parent,
               let parentFetchRequestResult = try? self.context.fetch(BaseBookmarkEntity.singleEntity(with: parent.id)).first {
                parentEntity = parentFetchRequestResult
            } else if let root = BookmarkUtils.fetchRootFolder(self.context) {
                parentEntity = root
            } else {
                Pixel.fire(.debug(event: .missingParent))
                DispatchQueue.main.async { completion(false, BookmarkStoreError.missingParent) }
                return
            }

            let bookmarkMO: BookmarkEntity
            if bookmark.isFolder {
                bookmarkMO = BookmarkEntity.makeFolder(title: bookmark.title,
                                                       parent: parentEntity,
                                                       context: self.context)
            } else {
                bookmarkMO = BookmarkEntity.makeBookmark(title: bookmark.title,
                                                         url: bookmark.url,
                                                         parent: parentEntity,
                                                         context: self.context)

                if bookmark.isFavorite,
                   let favoritesFolder = self.favoritesFolder {
                    bookmarkMO.addToFavorites(favoritesRoot: favoritesFolder)
                }
            }

            bookmarkMO.uuid = bookmark.id

            do {
                try self.context.save(onErrorFire: .bookmarksSaveFailed)
            } catch {
                self.context.rollback()
                assertionFailure("LocalBookmarkStore: Saving of context failed")
                DispatchQueue.main.async { completion(false, error) }
                return
            }

            DispatchQueue.main.async { completion(true, nil) }
        }
    }

    func remove(objectsWithUUIDs identifiers: [String], completion: @escaping (Bool, Error?) -> Void) {
        context.perform { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false, BookmarkStoreError.storeDeallocated) }
                return
            }

            let fetchRequest = BaseBookmarkEntity.entities(with: identifiers)
            let fetchResults = (try? self.context.fetch(fetchRequest)) ?? []

            if fetchResults.count != identifiers.count {
                assertionFailure("\(#file): Fetched bookmark entities didn't match the number of provided UUIDs")
            }

            for object in fetchResults {
                object.markPendingDeletion()
            }

            do {
                try self.context.save(onErrorFire: .bookmarksSaveFailed)
            } catch {
                self.context.rollback()
                assertionFailure("LocalBookmarkStore: Saving of context failed")
                DispatchQueue.main.async { completion(false, error) }
            }

            DispatchQueue.main.async { completion(true, nil) }
        }
    }

    func update(bookmark: Bookmark) {
        context.performAndWait { [weak self] in
            guard let self = self else {
                return
            }

            let bookmarkFetchRequest = BaseBookmarkEntity.singleEntity(with: bookmark.id)
            let bookmarkFetchRequestResults = try? self.context.fetch(bookmarkFetchRequest)

            guard let bookmarkMO = bookmarkFetchRequestResults?.first else {
                assertionFailure("LocalBookmarkStore: Failed to get BookmarkEntity from the context")
                return
            }

            bookmarkMO.update(with: bookmark, favoritesFolder: self.favoritesFolder)

            do {
                try self.context.save(onErrorFire: .bookmarksSaveFailed)
            } catch {
                self.context.rollback()
                assertionFailure("LocalBookmarkStore: Saving of context failed")
            }
        }
    }

    func update(folder: BookmarkFolder) {
        context.performAndWait { [weak self] in
            guard let self = self else {
                return
            }

            let folderFetchRequest = BaseBookmarkEntity.singleEntity(with: folder.id)
            let folderFetchRequestResults = try? self.context.fetch(folderFetchRequest)

            guard let bookmarkFolderMO = folderFetchRequestResults?.first else {
                assertionFailure("LocalBookmarkStore: Failed to get BookmarkEntity from the context")
                return
            }

            bookmarkFolderMO.update(with: folder)

            do {
                try self.context.save(onErrorFire: .bookmarksSaveFailed)
            } catch {
                self.context.rollback()
                assertionFailure("LocalBookmarkStore: Saving of context failed")
            }
        }
    }

    func add(objectsWithUUIDs uuids: [String], to parent: BookmarkFolder?, completion: @escaping (Error?) -> Void) {
        context.perform { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }

            let bookmarksFetchRequest = BaseBookmarkEntity.entities(with: uuids)
            bookmarksFetchRequest.returnsObjectsAsFaults = false
            let bookmarksResults = try? self.context.fetch(bookmarksFetchRequest)

            guard let bookmarkManagedObjects = bookmarksResults else {
                assertionFailure("\(#file): Failed to get BookmarkEntity from the context")
                completion(nil)
                return
            }

            if let parentUUID = parent?.id {
                let parentFetchRequest = BaseBookmarkEntity.singleEntity(with: parentUUID)
                let parentFetchRequestResults = try? self.context.fetch(parentFetchRequest)

                guard let parentManagedObject = parentFetchRequestResults?.first, parentManagedObject.isFolder else {
                    assertionFailure("\(#file): Failed to get BookmarkEntity from the context")
                    completion(nil)
                    return
                }

                parentManagedObject.addToChildren(NSOrderedSet(array: bookmarkManagedObjects))
            } else {
                for bookmarkManagedObject in bookmarkManagedObjects {
                    bookmarkManagedObject.parent = self.rootLevelFolder
                }
            }

            do {
                try self.context.save(onErrorFire: .bookmarksSaveFailed)
            } catch {
                self.context.rollback()
                assertionFailure("\(#file): Saving of context failed: \(error)")
                DispatchQueue.main.async { completion(error) }
                return
            }

            DispatchQueue.main.async { completion(nil) }
        }
    }

    func update(objectsWithUUIDs uuids: [String], update: @escaping (BaseBookmarkEntity) -> Void, completion: @escaping (Error?) -> Void) {
        context.perform { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }

            let bookmarksFetchRequest = BaseBookmarkEntity.entities(with: uuids)
            bookmarksFetchRequest.returnsObjectsAsFaults = false
            let bookmarksResults = try? self.context.fetch(bookmarksFetchRequest)

            guard let bookmarkManagedObjects = bookmarksResults else {
                assertionFailure("\(#file): Failed to get BookmarkEntity from the context")
                completion(nil)
                return
            }

            bookmarkManagedObjects.forEach { managedObject in
                if let entity = BaseBookmarkEntity.from(managedObject: managedObject, parentFolderUUID: nil) {
                    update(entity)
                    managedObject.update(with: entity, favoritesFolder: self.favoritesFolder)
                }
            }

            do {
                try self.context.save(onErrorFire: .bookmarksSaveFailed)
            } catch {
                self.context.rollback()
                assertionFailure("\(#file): Saving of context failed")
                DispatchQueue.main.async { completion(error) }
                return
            }

            DispatchQueue.main.async { completion(nil) }
        }
    }

    // MARK: - Folders

    func save(folder: BookmarkFolder, parent: BookmarkFolder?, completion: @escaping (Bool, Error?) -> Void) {
        context.perform { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false, BookmarkStoreError.storeDeallocated) }
                return
            }

            let parentEntity: BookmarkEntity
            if let parent = parent,
               let parentFetchRequestResult = try? self.context.fetch(BaseBookmarkEntity.singleEntity(with: parent.id)).first {
                parentEntity = parentFetchRequestResult
            } else if let root = BookmarkUtils.fetchRootFolder(self.context) {
                parentEntity = root
            } else {
                Pixel.fire(.debug(event: .missingParent))
                DispatchQueue.main.async { completion(false, BookmarkStoreError.missingParent) }
                return
            }

            let bookmarkMO = BookmarkEntity.makeFolder(title: folder.title,
                                                       parent: parentEntity,
                                                       context: self.context)

            bookmarkMO.uuid = folder.id

            do {
                try self.context.save(onErrorFire: .bookmarksSaveFailed)
            } catch {
                self.context.rollback()
                // Only throw this assertion when running in debug and when unit tests are not running.
                if !NSApp.isRunningUnitTests {
                    assertionFailure("LocalBookmarkStore: Saving of context failed")
                }

                DispatchQueue.main.async { completion(false, error) }
                return
            }

            DispatchQueue.main.async { completion(true, nil) }
        }
    }

    func canMoveObjectWithUUID(objectUUID uuid: String, to parent: BookmarkFolder) -> Bool {
        guard uuid != parent.id else {
            // A folder cannot set itself as its parent
            return false
        }

        // Assume true by default – the database validations will serve as a final check before any invalid state makes it into the database.
        var canMoveObject = true

        context.performAndWait { [weak self] in
            guard let self = self else {
                assertionFailure("Couldn't get strong self")
                return
            }

            let folderToMoveFetchRequest = BaseBookmarkEntity.singleEntity(with: uuid)
            let folderToMoveFetchRequestResults = try? self.context.fetch(folderToMoveFetchRequest)

            let parentFolderFetchRequest = BaseBookmarkEntity.singleEntity(with: parent.id)
            let parentFolderFetchRequestResults = try? self.context.fetch(parentFolderFetchRequest)

            guard let folderToMove = folderToMoveFetchRequestResults?.first,
                  let parentFolder = parentFolderFetchRequestResults?.first,
                  folderToMove.isFolder,
                  parentFolder.isFolder else {
                return
            }

            var currentParentFolder = parentFolder.parent

            // Check each parent and verify that the folder being moved isn't being given itself as an ancestor
            while let currentParent = currentParentFolder {
                if currentParent.uuid == uuid {
                    canMoveObject = false
                    return
                }

                currentParentFolder = currentParent.parent
            }
        }

        return canMoveObject
    }

    func move(objectUUIDs: [String], toIndex index: Int?, withinParentFolder type: ParentFolderType, completion: @escaping (Error?) -> Void) {
        context.perform { [weak self] in
            guard let self = self else {
                assertionFailure("Couldn't get strong self")
                completion(nil)
                return
            }

            guard let rootFolder = self.rootLevelFolder else {
                assertionFailure("\(#file): Failed to get root level folder")
                completion(nil)
                return
            }

            // Guarantee that bookmarks are fetched in the same order as the UUIDs. In the future, this should fetch all objects at once with a
            // batch fetch request and have them sorted in the correct order.
            let bookmarkManagedObjects: [BookmarkEntity] = objectUUIDs.compactMap { uuid in
                let entityFetchRequest = BaseBookmarkEntity.singleEntity(with: uuid)
                return (try? self.context.fetch(entityFetchRequest))?.first
            }

            let newParentFolder: BookmarkEntity

            switch type {
            case .root: newParentFolder = rootFolder
            case .parent(let newParentUUID):
                let bookmarksFetchRequest = BaseBookmarkEntity.singleEntity(with: newParentUUID)

                do {
                    if let fetchedParent = try self.context.fetch(bookmarksFetchRequest).first, fetchedParent.isFolder {
                        newParentFolder = fetchedParent
                    } else {
                        completion(nil)
                        return
                    }
                } catch {
                    completion(error)
                    return
                }
            }

            if let index = index, index < newParentFolder.childrenArray.count {
                self.move(entities: bookmarkManagedObjects, to: index, within: newParentFolder)
            } else {
                for bookmarkManagedObject in bookmarkManagedObjects {
                    bookmarkManagedObject.parent = nil
                    newParentFolder.addToChildren(bookmarkManagedObject)
                }
            }

            do {
                try self.context.save(onErrorFire: .bookmarksSaveFailed)
            } catch {
                self.context.rollback()
                assertionFailure("\(#file): Saving of context failed")
                DispatchQueue.main.async { completion(error) }
                return
            }

            DispatchQueue.main.async { completion(nil) }
        }
    }

    private func move(entities bookmarkManagedObjects: [BookmarkEntity], to index: Int, within newParentFolder: BookmarkEntity) {
        var currentInsertionIndex = max(index, 0)

        for bookmarkManagedObject in bookmarkManagedObjects {
            let movingObjectWithinSameFolder = bookmarkManagedObject.parent?.id == newParentFolder.id

            var adjustedInsertionIndex = currentInsertionIndex

            if movingObjectWithinSameFolder,
               let objectIndex = newParentFolder.childrenArray.firstIndex(of: bookmarkManagedObject),
               currentInsertionIndex > objectIndex {
                adjustedInsertionIndex -= 1
            }

            bookmarkManagedObject.parent = nil

            // Removing the bookmark from its current parent may have removed it from the collection it is about to be added to, so re-check
            // the bounds before adding it back.
            if adjustedInsertionIndex < newParentFolder.childrenArray.count {
                newParentFolder.insertIntoChildren(bookmarkManagedObject, at: adjustedInsertionIndex)
            } else {
                newParentFolder.addToChildren(bookmarkManagedObject)
            }

            currentInsertionIndex = adjustedInsertionIndex + 1
        }
    }

    func moveFavorites(with objectUUIDs: [String], toIndex index: Int?, completion: @escaping (Error?) -> Void) {
        context.perform { [weak self] in
            guard let self = self else {
                assertionFailure("Couldn't get strong self")
                completion(nil)
                return
            }

            guard let favoritesFolder = self.favoritesFolder else {
                assertionFailure("\(#file): Failed to get favorites folder")
                completion(nil)
                return
            }

            // Guarantee that bookmarks are fetched in the same order as the UUIDs. In the future, this should fetch all objects at once with a
            // batch fetch request and have them sorted in the correct order.
            let bookmarkManagedObjects: [BookmarkEntity] = objectUUIDs.compactMap { uuid in
                let entityFetchRequest = BaseBookmarkEntity.favorite(with: uuid)
                return (try? self.context.fetch(entityFetchRequest))?.first
            }

            if let index = index, index < (favoritesFolder.favorites?.count ?? 0) {
                var currentInsertionIndex = max(index, 0)

                for bookmarkManagedObject in bookmarkManagedObjects {
                    var adjustedInsertionIndex = currentInsertionIndex

                    if let currentIndex = favoritesFolder.favorites?.index(of: bookmarkManagedObject),
                       currentInsertionIndex > currentIndex {
                        adjustedInsertionIndex -= 1
                    }

                    bookmarkManagedObject.removeFromFavorites()
                    if adjustedInsertionIndex < (favoritesFolder.favorites?.count ?? 0) {
                        bookmarkManagedObject.addToFavorites(insertAt: adjustedInsertionIndex,
                                                             favoritesRoot: favoritesFolder)
                    } else {
                        bookmarkManagedObject.addToFavorites(favoritesRoot: favoritesFolder)
                    }

                    currentInsertionIndex = adjustedInsertionIndex + 1
                }
            } else {
                for bookmarkManagedObject in bookmarkManagedObjects {
                    bookmarkManagedObject.removeFromFavorites()
                    bookmarkManagedObject.addToFavorites(favoritesRoot: favoritesFolder)
                }
            }

            do {
                try self.context.save(onErrorFire: .bookmarksSaveFailed)
            } catch {
                self.context.rollback()
                assertionFailure("\(#file): Saving of context failed")
                DispatchQueue.main.async { completion(error) }
                return
            }

            DispatchQueue.main.async { completion(nil) }
        }
    }

    // MARK: - Import

    /// Imports bookmarks into the Core Data store from an `ImportedBookmarks` object.
    /// The source is used to determine where to put bookmarks, as we want to match the source browser's structure as closely as possible.
    ///
    /// The import strategy is as follows:
    ///
    /// 1. **DuckDuckGo:** Put all bookmarks at the root level
    /// 2. **Safari:** Create a root level "Imported Favorites" folder to store bookmarks from the bookmarks bar, and all other bookmarks go at the root level.
    /// 3. **Chrome:** Put all bookmarks at the root level, except for Other Bookmarks which go in a root level "Other Bookmarks" folder.
    /// 4. **Firefox:** Put all bookmarks at the root level, except for Other Bookmarks which go in a root level "Other Bookmarks" folder.
    func importBookmarks(_ bookmarks: ImportedBookmarks, source: BookmarkImportSource) -> BookmarkImportResult {
        var total = BookmarkImportResult(successful: 0, duplicates: 0, failed: 0)

        context.performAndWait {
            do {
                let bookmarkCountBeforeImport = try context.count(for: Bookmark.bookmarksFetchRequest())
                let allFolders = try context.fetch(BookmarkFolder.bookmarkFoldersFetchRequest())

                total += createEntitiesFromBookmarks(allFolders: allFolders, bookmarks: bookmarks, importSourceName: source.importSourceName)

                try self.context.save(onErrorFire: .bookmarksSaveFailedOnImport)
                let bookmarkCountAfterImport = try context.count(for: Bookmark.bookmarksFetchRequest())

                total.successful = bookmarkCountAfterImport - bookmarkCountBeforeImport
            } catch {
                self.context.rollback()
                os_log("Failed to import bookmarks, with error: %s", log: .dataImportExport, type: .error, error.localizedDescription)

                // Only throw this assertion when running in debug and when unit tests are not running.
                if !NSApp.isRunningUnitTests {
                    assertionFailure("LocalBookmarkStore: Saving of context failed, error: \(error.localizedDescription)")
                }
            }
        }

        return total
    }

    private func createEntitiesFromDDGWebKitBookmarks(allFolders: [BookmarkEntity], bookmarks: ImportedBookmarks) -> BookmarkImportResult {

        var total = BookmarkImportResult(successful: 0, duplicates: 0, failed: 0)

        if let otherBookmarks = bookmarks.topLevelFolders.otherBookmarks.children,
           let rootFolder = rootLevelFolder {
            let result = recursivelyCreateEntities(from: otherBookmarks,
                                                   parent: rootFolder,
                                                   in: self.context)

            total += result
        }

        return total

    }

    private func createEntitiesFromBookmarks(allFolders: [BookmarkEntity],
                                             bookmarks: ImportedBookmarks,
                                             importSourceName: String) -> BookmarkImportResult {

        guard let root = rootLevelFolder else {
            return .init(successful: 0,
                         duplicates: 0,
                         failed: bookmarks.numberOfBookmarks)
        }

        var total = BookmarkImportResult(successful: 0, duplicates: 0, failed: 0)

        var parent = root
        var makeFavorties = true
        if root.children?.count != 0 {
            makeFavorties = false
            parent = BookmarkEntity.makeFolder(title: "Imported from \(importSourceName)",
                                               parent: root,
                                               context: context)
        }

        if let bookmarksBar = bookmarks.topLevelFolders.bookmarkBar.children {
            let result = recursivelyCreateEntities(from: bookmarksBar,
                                                   parent: parent,
                                                   markBookmarksAsFavorite: makeFavorties,
                                                   in: self.context)

            total += result
        }

        if let otherBookmarks = bookmarks.topLevelFolders.otherBookmarks.children {
            let result = recursivelyCreateEntities(from: otherBookmarks,
                                                   parent: parent,
                                                   markBookmarksAsFavorite: false,
                                                   in: self.context)

            total += result
        }

        return total

    }

    private func recursivelyCreateEntities(from bookmarks: [ImportedBookmarks.BookmarkOrFolder],
                                           parent: BookmarkEntity,
                                           markBookmarksAsFavorite: Bool? = false,
                                           in context: NSManagedObjectContext) -> BookmarkImportResult {
        var total = BookmarkImportResult(successful: 0, duplicates: 0, failed: 0)

        for bookmarkOrFolder in bookmarks {

            let bookmarkManagedObject: BookmarkEntity
            if bookmarkOrFolder.isFolder {
                bookmarkManagedObject = BookmarkEntity.makeFolder(title: bookmarkOrFolder.name,
                                                                  parent: parent,
                                                                  context: context)
            } else if let urlString = bookmarkOrFolder.url?.absoluteString {
                bookmarkManagedObject = BookmarkEntity.makeBookmark(title: bookmarkOrFolder.name,
                                                                    url: urlString,
                                                                    parent: parent,
                                                                    context: context)
            } else {
                // Skip importing bookmarks that don't have a valid URL
                total.failed += 1
                continue
            }

            // Bookmarks from the bookmarks bar are imported as favorites
            if let favoritesRoot = favoritesFolder,
               bookmarkOrFolder.isDDGFavorite || (!bookmarkOrFolder.isFolder && markBookmarksAsFavorite == true) {
                bookmarkManagedObject.addToFavorites(favoritesRoot: favoritesRoot)
            }

            if let children = bookmarkOrFolder.children {
                let result = recursivelyCreateEntities(from: children,
                                                       parent: bookmarkManagedObject,
                                                       markBookmarksAsFavorite: false,
                                                       in: context)

                total += result
            }

            // If a managed object is a folder, and it doesn't have any child bookmarks, it can be deleted. In the future, duplicate bookmarks will be
            // allowed and folders won't have to be removed like this. This is done here as a separate step so that it's easy to delete later once
            // duplicates are allowed.
            if bookmarkManagedObject.isFolder, let folderChildren = bookmarkManagedObject.children {
                let children = folderChildren.compactMap { $0 as? BookmarkEntity }
                let containsBookmark = children.contains(where: { !$0.isFolder })
                let containsPopulatedFolder = children.contains(where: { ($0.children?.count ?? 0) > 0 })

                if !containsBookmark && !containsPopulatedFolder {
                    context.delete(bookmarkManagedObject)
                }
            }
        }

        return total
    }

    /// There is a rare issue where bookmark managed objects can end up in the database with an invalid state, that is that they are missing their title value despite being non-optional.
    /// They appear to be disjoint from a user's actual bookmarks data, so this function removes them.
    private func removeInvalidBookmarkEntities() {
        context.performAndWait {
            let entitiesFetchRequest = BookmarkEntity.fetchRequest()

            do {
                let entities = try self.context.fetch(entitiesFetchRequest)

                var deletedEntityCount = 0

                for entity in entities where entity.isInvalid {
                    self.context.delete(entity)
                    deletedEntityCount += 1
                }

                if deletedEntityCount > 0 {
                    Pixel.fire(.debug(event: .removedInvalidBookmarkManagedObjects))
                }

                try self.context.save(onErrorFire: .bookmarksSaveFailed)
            } catch {
                self.context.rollback()
                os_log("Failed to remove invalid bookmark entities", type: .error)
            }
        }
    }

    func resetBookmarks() {
        context.performAndWait {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: BookmarkEntity.className())
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try context.execute(deleteRequest)
            } catch {
                assertionFailure("Failed to reset bookmarks")
            }
        }

        sharedInitialization()
    }

    // MARK: - Concurrency

    func loadAll(type: BookmarkStoreFetchPredicateType) async -> Result<[BaseBookmarkEntity], Error> {
        return await withCheckedContinuation { continuation in
            loadAll(type: type) { result, error in
                if let error = error {
                    continuation.resume(returning: .failure(error))
                    return
                }

                guard let result = result else {
                    fatalError("Expected non-nil result 'result' for nil error")
                }

                continuation.resume(returning: .success(result))
            }
        }
    }

    func save(folder: BookmarkFolder, parent: BookmarkFolder?) async -> Result<Bool, Error> {
        return await withCheckedContinuation { continuation in
            save(folder: folder, parent: parent) { result, error in
                if let error = error {
                    continuation.resume(returning: .failure(error))
                    return
                }

                continuation.resume(returning: .success(result))
            }
        }
    }

    func save(bookmark: Bookmark, parent: BookmarkFolder?, index: Int?) async -> Result<Bool, Error> {
        return await withCheckedContinuation { continuation in
            save(bookmark: bookmark, parent: parent, index: index) { result, error in
                if let error = error {
                    continuation.resume(returning: .failure(error))
                    return
                }

                continuation.resume(returning: .success(result))
            }
        }
    }

    func move(objectUUIDs: [String], toIndex index: Int?, withinParentFolder parent: ParentFolderType) async -> Error? {
        return await withCheckedContinuation { continuation in
            move(objectUUIDs: objectUUIDs, toIndex: index, withinParentFolder: parent) { error in
                if let error = error {
                    continuation.resume(returning: error)
                    return
                }

                continuation.resume(returning: nil)
            }
        }
    }

    func moveFavorites(with objectUUIDs: [String], toIndex index: Int?) async -> Error? {
        return await withCheckedContinuation { continuation in
            moveFavorites(with: objectUUIDs, toIndex: index) { error in
                if let error = error {
                    continuation.resume(returning: error)
                    return
                }

                continuation.resume(returning: nil)
            }
        }
    }

}

fileprivate extension BookmarkEntity {

    var isInvalid: Bool {
        if title == nil {
            return true
        }

        return false
    }

    func update(with baseEntity: BaseBookmarkEntity, favoritesFolder: BookmarkEntity?) {
        if let bookmark = baseEntity as? Bookmark {
            update(with: bookmark, favoritesFolder: favoritesFolder)
        } else if let folder = baseEntity as? BookmarkFolder {
            update(with: folder)
        } else {
            assertionFailure("\(#file): Failed to cast base entity to Bookmark or BookmarkFolder")
        }
    }

    func update(with bookmark: Bookmark, favoritesFolder: BookmarkEntity?) {
        url = bookmark.url
        title = bookmark.title
        if bookmark.isFavorite {
            if let favoritesFolder = favoritesFolder {
                addToFavorites(favoritesRoot: favoritesFolder)
            }
        } else {
            removeFromFavorites()
        }
    }

    func update(with folder: BookmarkFolder) {
        title = folder.title
    }

}
