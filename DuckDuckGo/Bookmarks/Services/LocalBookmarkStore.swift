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

import Combine
import Common
import Foundation
import CoreData
import DDGSync
import Bookmarks
import Cocoa
import Persistence
import PixelKit

// swiftlint:disable:next type_body_length
final class LocalBookmarkStore: BookmarkStore {

    convenience init(bookmarkDatabase: BookmarkDatabase) {
        self.init(contextProvider: {
            let context = bookmarkDatabase.db.makeContext(concurrencyType: .privateQueueConcurrencyType)
            context.stalenessInterval = 0
            return context
        })
    }

    // Directly used in tests
    init(contextProvider: @escaping () -> NSManagedObjectContext, appearancePreferences: AppearancePreferences = .shared) {
        self.contextProvider = contextProvider

        favoritesDisplayMode = appearancePreferences.favoritesDisplayMode
        migrateToFormFactorSpecificFavoritesFolders()
        removeInvalidBookmarkEntities()
        cacheReadOnlyTopLevelBookmarksFolders()
    }

    enum BookmarkStoreError: Error {
        case storeDeallocated
        case noObjectId
        case badObjectId
        case asyncFetchFailed
        case missingParent
        case missingEntity
        case missingRoot
        case missingFavoritesRoot
        case saveLoopError(Error?)
    }

    private(set) var favoritesDisplayMode: FavoritesDisplayMode
    private(set) var didMigrateToFormFactorSpecificFavorites: Bool = false

    private let contextProvider: () -> NSManagedObjectContext

    /// All entities within the bookmarks store must exist under this root level folder. Because this value is used so frequently, it is cached here.
    private var rootLevelFolderObjectID: NSManagedObjectID?

    /// All favorites must additionally be children of this special folder. Because this value is used so frequently, it is cached here.
    private var favoritesFolderObjectID: NSManagedObjectID?

    private func makeContext() -> NSManagedObjectContext {
        return contextProvider()
    }

    private func bookmarksRoot(in context: NSManagedObjectContext) -> BookmarkEntity? {
        guard let objectID = self.rootLevelFolderObjectID else {
            return nil
        }
        return try? (context.existingObject(with: objectID) as? BookmarkEntity)
    }

    private func favoritesRoot(in context: NSManagedObjectContext) -> BookmarkEntity? {
        guard let objectID = self.favoritesFolderObjectID else {
            return nil
        }
        return try? (context.existingObject(with: objectID) as? BookmarkEntity)
    }

    /*
     Utility function to help with saving changes to the database.

     If there is a timing issue (e.g. another context making changes), we may encounter merge error on save, in such case:
       - reset context
       - reapply changes
       - retry save

     You can expect either `onError` or `onDidSave` to be called once.
     Error thrown from within `changes` block triggers `onError` call and prevents saving.
     */
    func applyChangesAndSave(changes: @escaping (NSManagedObjectContext) throws -> Void,
                             onError: @escaping (Error) -> Void,
                             onDidSave: @escaping () -> Void) {
        let context = makeContext()

        let maxRetries = 4
        var iteration = 0

        context.perform {
            var lastError: Error?
            while iteration < maxRetries {
                do {
                    try changes(context)

                    try context.save()
                    onDidSave()
                    return
                } catch {
                    let nsError = error as NSError
                    if nsError.code == NSManagedObjectMergeError || nsError.code == NSManagedObjectConstraintMergeError {
                        iteration += 1
                        lastError = error
                        context.reset()
                    } else {
                        onError(error)
                        return
                    }
                }
            }

            onError(BookmarkStoreError.saveLoopError(lastError))
        }
    }

    /*
     Utility function to help with saving changes to the database.

     If there is a timing issue (e.g. another context making changes), we may encounter merge error on save, in such case:
       - reset context
       - reapply changes
       - retry save

     Error thrown from within `changes` block prevent saving and is rethrown.
     */
    func applyChangesAndSave(changes: (NSManagedObjectContext) throws -> Void) throws {
        let context = makeContext()

        let maxRetries = 4
        var iteration = 0

        var errorToThrow: Error?
        context.performAndWait {
            var lastMergeError: NSError?
            while iteration < maxRetries {
                do {
                    try changes(context)
                    try context.save()
                    return
                } catch {

                    let nsError = error as NSError
                    if nsError.code == NSManagedObjectMergeError || nsError.code == NSManagedObjectConstraintMergeError {
                        lastMergeError = nsError
                        iteration += 1
                        context.reset()
                    } else {
                        errorToThrow = error
                        return
                    }
                }
            }

            errorToThrow = BookmarkStoreError.saveLoopError(lastMergeError)
        }

        if let errorToThrow {
            throw errorToThrow
        }
    }

    private func commonOnSaveErrorHandler(_ error: Error, source: String = #function) {
        guard NSApp.runType.requiresEnvironment else { return }

        assertionFailure("LocalBookmarkStore: Saving of context failed")

        if let localError = error as? BookmarkStoreError {
            if case BookmarkStoreError.saveLoopError(let innerError) = localError, let innerError {
                let processedErrors = CoreDataErrorsParser.parse(error: innerError as NSError)

                var params = processedErrors.errorPixelParameters
                params[PixelKit.Parameters.errorSource] = source
                Pixel.fire(.debug(event: .bookmarksSaveFailed, error: error),
                           withAdditionalParameters: params)
            } else {
                Pixel.fire(.debug(event: .bookmarksSaveFailed, error: localError),
                           withAdditionalParameters: [PixelKit.Parameters.errorSource: source])
            }
        } else {
            let error = error as NSError
            let processedErrors = CoreDataErrorsParser.parse(error: error)

            var params = processedErrors.errorPixelParameters
            params[PixelKit.Parameters.errorSource] = source
            Pixel.fire(.debug(event: .bookmarksSaveFailed, error: error),
                       withAdditionalParameters: params)
        }
    }

    private func migrateToFormFactorSpecificFavoritesFolders() {
        let context = makeContext()

        context.performAndWait {
            do {
                BookmarkUtils.migrateToFormFactorSpecificFavorites(byCopyingExistingTo: .desktop, in: context)

                if context.hasChanges {
                    try context.save(onErrorFire: .bookmarksMigrationCouldNotPrepareMultipleFavoriteFolders)
                    didMigrateToFormFactorSpecificFavorites = true
                }
            } catch {
                Thread.sleep(forTimeInterval: 1)
                fatalError("Could not prepare Bookmarks DB structure")
            }
        }
    }

    private func cacheReadOnlyTopLevelBookmarksFolders() {
        let context = makeContext()
        context.performAndWait {
            guard let folder = BookmarkUtils.fetchRootFolder(context) else {
                fatalError("Top level folder missing")
            }

            self.rootLevelFolderObjectID = folder.objectID
            let favoritesFolderUUID = favoritesDisplayMode.displayedFolder.rawValue
            self.favoritesFolderObjectID = BookmarkUtils.fetchFavoritesFolder(withUUID: favoritesFolderUUID, in: context)?.objectID
        }
    }

    // MARK: - Bookmarks

    func applyFavoritesDisplayMode(_ displayMode: FavoritesDisplayMode) {
        favoritesDisplayMode = displayMode
        cacheReadOnlyTopLevelBookmarksFolders()
    }

    func loadAll(type: BookmarkStoreFetchPredicateType, completion: @escaping ([BaseBookmarkEntity]?, Error?) -> Void) {
        func mainQueueCompletion(bookmarks: [BaseBookmarkEntity]?, error: Error?) {
            DispatchQueue.main.async {
                completion(bookmarks, error)
            }
        }

        let context = makeContext()
        context.perform {
            do {
                let results: [BookmarkEntity]

                switch type {
                case .bookmarks:
                    let fetchRequest = Bookmark.bookmarksFetchRequest()
                    fetchRequest.returnsObjectsAsFaults = false
                    results = try context.fetch(fetchRequest)
                case .topLevelEntities:
                    // When fetching the top level entities, the root folder will be returned. To make things simpler for the caller, this function
                    // will return the children of the root folder, as the root folder is an implementation detail of the bookmarks store.
                    let rootFolder = self.bookmarksRoot(in: context)
                    let orphanedEntities = BookmarkUtils.fetchOrphanedEntities(context)
                    if !orphanedEntities.isEmpty {
                        self.reportOrphanedBookmarksIfNeeded()
                    }
                    results = (rootFolder?.childrenArray ?? []) + orphanedEntities
                case .favorites:
                    results = self.favoritesRoot(in: context)?.favoritesArray ?? []
                }

                let entities: [BaseBookmarkEntity] = results.compactMap { entity in
                    BaseBookmarkEntity.from(managedObject: entity,
                                            parentFolderUUID: entity.parent?.uuid,
                                            favoritesDisplayMode: self.favoritesDisplayMode)
                }

                mainQueueCompletion(bookmarks: entities, error: nil)
            } catch let error {
                completion(nil, error)
            }
        }
    }

    private func reportOrphanedBookmarksIfNeeded() {
        Task { @MainActor in
            guard let syncService = NSApp.delegateTyped.syncService, syncService.authState == .inactive else {
                return
            }
            Pixel.fire(.debug(event: .orphanedBookmarksPresent))
        }
    }

    func save(bookmark: Bookmark, parent: BookmarkFolder?, index: Int?, completion: @escaping (Bool, Error?) -> Void) {
        applyChangesAndSave(changes: { [weak self] context in
            guard let self = self else {
                throw BookmarkStoreError.storeDeallocated
            }

            let parentEntity: BookmarkEntity
            if let parent = parent,
               let parentFetchRequestResult = try? context.fetch(BaseBookmarkEntity.singleEntity(with: parent.id)).first {
                parentEntity = parentFetchRequestResult
            } else if let root = bookmarksRoot(in: context) {
                parentEntity = root
            } else {
                Pixel.fire(.debug(event: .missingParent))
                throw BookmarkStoreError.missingParent
            }

            let bookmarkMO: BookmarkEntity
            if bookmark.isFolder {
                bookmarkMO = BookmarkEntity.makeFolder(title: bookmark.title,
                                                       parent: parentEntity,
                                                       context: context)
            } else {
                bookmarkMO = BookmarkEntity.makeBookmark(title: bookmark.title,
                                                         url: bookmark.url,
                                                         parent: parentEntity,
                                                         context: context)

                if bookmark.isFavorite {
                    bookmarkMO.addToFavorites(with: favoritesDisplayMode, in: context)
                }
            }

            bookmarkMO.uuid = bookmark.id
        }, onError: { [weak self] error in
            self?.commonOnSaveErrorHandler(error)
            DispatchQueue.main.async { completion(false, error) }
        }, onDidSave: {
            DispatchQueue.main.async { completion(true, nil) }
        })
    }

    func remove(objectsWithUUIDs identifiers: [String], completion: @escaping (Bool, Error?) -> Void) {

        applyChangesAndSave(changes: { [weak self] context in
            guard self != nil else {
                throw BookmarkStoreError.storeDeallocated
            }

            let fetchRequest = BaseBookmarkEntity.entities(with: identifiers)
            let fetchResults = (try? context.fetch(fetchRequest)) ?? []

            if fetchResults.count != identifiers.count {
                assertionFailure("\(#file): Fetched bookmark entities didn't match the number of provided UUIDs")
            }

            for object in fetchResults {
                object.markPendingDeletion()
            }
        }, onError: { [weak self] error in
            self?.commonOnSaveErrorHandler(error)
            DispatchQueue.main.async { completion(false, error) }
        }, onDidSave: {
            DispatchQueue.main.async { completion(true, nil) }
        })
    }

    func update(bookmark: Bookmark) {

        do {
            try applyChangesAndSave(changes: { [weak self] context in
                guard let self = self else {
                    throw BookmarkStoreError.storeDeallocated
                }

                let bookmarkFetchRequest = BaseBookmarkEntity.singleEntity(with: bookmark.id)
                let bookmarkFetchRequestResults = try? context.fetch(bookmarkFetchRequest)

                guard let bookmarkMO = bookmarkFetchRequestResults?.first else {
                    assertionFailure("LocalBookmarkStore: Failed to get BookmarkEntity from the context")
                    throw BookmarkStoreError.missingEntity
                }

                let favoritesFolders = BookmarkUtils.fetchFavoritesFolders(for: favoritesDisplayMode, in: context)
                bookmarkMO.update(with: bookmark, favoritesFoldersToAddFavorite: favoritesFolders, favoritesDisplayMode: favoritesDisplayMode)
            })

        } catch {
            let error = error as NSError
            commonOnSaveErrorHandler(error)
        }
    }

    func update(folder: BookmarkFolder) {

        do {
            _ = try applyChangesAndSave(changes: { context in
                let folderFetchRequest = BaseBookmarkEntity.singleEntity(with: folder.id)
                let folderFetchRequestResults = try? context.fetch(folderFetchRequest)

                guard let bookmarkFolderMO = folderFetchRequestResults?.first else {
                    assertionFailure("LocalBookmarkStore: Failed to get BookmarkEntity from the context")
                    throw BookmarkStoreError.missingEntity
                }

                bookmarkFolderMO.update(with: folder)
            })
        } catch {
            let error = error as NSError
            commonOnSaveErrorHandler(error)
        }
    }

    func add(objectsWithUUIDs uuids: [String], to parent: BookmarkFolder?, completion: @escaping (Error?) -> Void) {

        applyChangesAndSave(changes: { [weak self] context in
            guard let self = self else {
                throw BookmarkStoreError.storeDeallocated
            }

            let bookmarksFetchRequest = BaseBookmarkEntity.entities(with: uuids)
            bookmarksFetchRequest.returnsObjectsAsFaults = false
            let bookmarksResults = try? context.fetch(bookmarksFetchRequest)

            guard let bookmarkManagedObjects = bookmarksResults else {
                assertionFailure("\(#file): Failed to get BookmarkEntity from the context")
                throw BookmarkStoreError.missingEntity
            }

            if let parentUUID = parent?.id {
                let parentFetchRequest = BaseBookmarkEntity.singleEntity(with: parentUUID)
                let parentFetchRequestResults = try? context.fetch(parentFetchRequest)

                guard let parentManagedObject = parentFetchRequestResults?.first, parentManagedObject.isFolder else {
                    assertionFailure("\(#file): Failed to get BookmarkEntity from the context")
                    throw BookmarkStoreError.missingEntity
                }

                parentManagedObject.addToChildren(NSOrderedSet(array: bookmarkManagedObjects))
            } else {
                let root = self.bookmarksRoot(in: context)
                for bookmarkManagedObject in bookmarkManagedObjects {
                    bookmarkManagedObject.parent = root
                }
            }
        }, onError: { [weak self] error in
            self?.commonOnSaveErrorHandler(error)
            DispatchQueue.main.async { completion(error) }
        }, onDidSave: {
            DispatchQueue.main.async { completion(nil) }
        })
    }

    func update(objectsWithUUIDs uuids: [String], update: @escaping (BaseBookmarkEntity) -> Void, completion: @escaping (Error?) -> Void) {

        applyChangesAndSave(changes: { [weak self] context in
            guard let self = self else {
                throw BookmarkStoreError.storeDeallocated
            }

            let bookmarksFetchRequest = BaseBookmarkEntity.entities(with: uuids)
            bookmarksFetchRequest.returnsObjectsAsFaults = false
            let bookmarksResults = try? context.fetch(bookmarksFetchRequest)

            guard let bookmarkManagedObjects = bookmarksResults else {
                assertionFailure("\(#file): Failed to get BookmarkEntity from the context")
                throw BookmarkStoreError.missingEntity
            }

            let favoritesFolders = BookmarkUtils.fetchFavoritesFolders(for: favoritesDisplayMode, in: context)
            bookmarkManagedObjects.forEach { managedObject in
                if let entity = BaseBookmarkEntity.from(managedObject: managedObject, parentFolderUUID: nil, favoritesDisplayMode: self.favoritesDisplayMode) {
                    update(entity)
                    managedObject.update(with: entity, favoritesFoldersToAddFavorite: favoritesFolders, favoritesDisplayMode: self.favoritesDisplayMode)
                }
            }
        }, onError: { [weak self] error in
            self?.commonOnSaveErrorHandler(error)
            DispatchQueue.main.async { completion(error) }
        }, onDidSave: {
            DispatchQueue.main.async { completion(nil) }
        })
    }

    // MARK: - Folders

    func save(folder: BookmarkFolder, parent: BookmarkFolder?, completion: @escaping (Bool, Error?) -> Void) {

        applyChangesAndSave(changes: { [weak self] context in
            guard let self = self else {
                throw BookmarkStoreError.storeDeallocated
            }

            let parentEntity: BookmarkEntity
            if let parent = parent,
               let parentFetchRequestResult = try? context.fetch(BaseBookmarkEntity.singleEntity(with: parent.id)).first {
                parentEntity = parentFetchRequestResult
            } else if let root = self.bookmarksRoot(in: context) {
                parentEntity = root
            } else {
                Pixel.fire(.debug(event: .missingParent))
                throw BookmarkStoreError.missingParent
            }

            let bookmarkMO = BookmarkEntity.makeFolder(title: folder.title,
                                                       parent: parentEntity,
                                                       context: context)

            bookmarkMO.uuid = folder.id
        }, onError: { [weak self] error in
            self?.commonOnSaveErrorHandler(error)
            DispatchQueue.main.async { completion(false, error) }
        }, onDidSave: {
            DispatchQueue.main.async { completion(true, nil) }
        })
    }

    func canMoveObjectWithUUID(objectUUID uuid: String, to parent: BookmarkFolder) -> Bool {
        guard uuid != parent.id else {
            // A folder cannot set itself as its parent
            return false
        }

        // Assume true by default – the database validations will serve as a final check before any invalid state makes it into the database.
        var canMoveObject = true

        let context = makeContext()
        context.performAndWait { [weak self] in
            guard self != nil else {
                assertionFailure("Couldn't get strong self")
                return
            }

            let folderToMoveFetchRequest = BaseBookmarkEntity.singleEntity(with: uuid)
            let folderToMoveFetchRequestResults = try? context.fetch(folderToMoveFetchRequest)

            let parentFolderFetchRequest = BaseBookmarkEntity.singleEntity(with: parent.id)
            let parentFolderFetchRequestResults = try? context.fetch(parentFolderFetchRequest)

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

        applyChangesAndSave(changes: { [weak self] context in
            guard let self = self else {
                throw BookmarkStoreError.storeDeallocated
            }

            guard let rootFolder = self.bookmarksRoot(in: context) else {
                throw BookmarkStoreError.missingRoot
            }

            // Guarantee that bookmarks are fetched in the same order as the UUIDs. In the future, this should fetch all objects at once with a
            // batch fetch request and have them sorted in the correct order.
            let bookmarkManagedObjects: [BookmarkEntity] = objectUUIDs.compactMap { uuid in
                let entityFetchRequest = BaseBookmarkEntity.singleEntity(with: uuid)
                return (try? context.fetch(entityFetchRequest))?.first
            }

            let newParentFolder: BookmarkEntity

            switch type {
            case .root: newParentFolder = rootFolder
            case .parent(let newParentUUID):
                let bookmarksFetchRequest = BaseBookmarkEntity.singleEntity(with: newParentUUID)

                if let fetchedParent = try context.fetch(bookmarksFetchRequest).first, fetchedParent.isFolder {
                    newParentFolder = fetchedParent
                } else {
                    throw BookmarkStoreError.missingEntity
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
        }, onError: { [weak self] error in
            self?.commonOnSaveErrorHandler(error)
            DispatchQueue.main.async { completion(error) }
        }, onDidSave: {
            DispatchQueue.main.async { completion(nil) }
        })
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

        applyChangesAndSave(changes: { [weak self] context in
            guard let self = self else {
                throw BookmarkStoreError.storeDeallocated
            }

            let displayedFavoritesFolderUUID = favoritesDisplayMode.displayedFolder.rawValue
            guard let displayedFavoritesFolder = BookmarkUtils.fetchFavoritesFolder(withUUID: displayedFavoritesFolderUUID, in: context) else {
                throw BookmarkStoreError.missingFavoritesRoot
            }

            let favoritesFolders = BookmarkUtils.fetchFavoritesFolders(for: favoritesDisplayMode, in: context)
            let favoritesFoldersWithoutDisplayed = favoritesFolders.filter { $0.uuid != displayedFavoritesFolderUUID }

            // Guarantee that bookmarks are fetched in the same order as the UUIDs. In the future, this should fetch all objects at once with a
            // batch fetch request and have them sorted in the correct order.
            let bookmarkManagedObjects: [BookmarkEntity] = objectUUIDs.compactMap { uuid in
                let entityFetchRequest = BaseBookmarkEntity.favorite(with: uuid, favoritesFolder: displayedFavoritesFolder)
                return (try? context.fetch(entityFetchRequest))?.first
            }

            if let index = index, index < (displayedFavoritesFolder.favorites?.count ?? 0) {
                var currentInsertionIndex = max(index, 0)

                for bookmarkManagedObject in bookmarkManagedObjects {
                    var adjustedInsertionIndex = currentInsertionIndex

                    if let currentIndex = displayedFavoritesFolder.favorites?.index(of: bookmarkManagedObject),
                       currentInsertionIndex > currentIndex {
                        adjustedInsertionIndex -= 1
                    }

                    bookmarkManagedObject.removeFromFavorites(with: favoritesDisplayMode)
                    if adjustedInsertionIndex < (displayedFavoritesFolder.favorites?.count ?? 0) {
                        bookmarkManagedObject.addToFavorites(insertAt: adjustedInsertionIndex,
                                                             favoritesRoot: displayedFavoritesFolder)
                        bookmarkManagedObject.addToFavorites(folders: favoritesFoldersWithoutDisplayed)
                    } else {
                        bookmarkManagedObject.addToFavorites(folders: favoritesFolders)
                    }

                    currentInsertionIndex = adjustedInsertionIndex + 1
                }
            } else {
                for bookmarkManagedObject in bookmarkManagedObjects {
                    bookmarkManagedObject.removeFromFavorites(with: favoritesDisplayMode)
                    bookmarkManagedObject.addToFavorites(folders: favoritesFolders)
                }
            }
        }, onError: { [weak self] error in
            self?.commonOnSaveErrorHandler(error)
            DispatchQueue.main.async { completion(error) }
        }, onDidSave: {
            DispatchQueue.main.async { completion(nil) }
        })

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

        do {
            let context = makeContext()
            var bookmarkCountBeforeImport = 0
            context.performAndWait {
                bookmarkCountBeforeImport = (try? context.count(for: Bookmark.bookmarksFetchRequest())) ?? 0
            }

            try applyChangesAndSave { context in
                let allFolders = try context.fetch(BookmarkFolder.bookmarkFoldersFetchRequest())
                total += createEntitiesFromBookmarks(allFolders: allFolders,
                                                     bookmarks: bookmarks,
                                                     importSourceName: source.importSourceName,
                                                     in: context)
            }

            context.performAndWait {
                let bookmarkCountAfterImport = (try? context.count(for: Bookmark.bookmarksFetchRequest())) ?? 0
                total.successful = bookmarkCountAfterImport - bookmarkCountBeforeImport
            }

        } catch {
            os_log("Failed to import bookmarks, with error: %s", log: .dataImportExport, type: .error, error.localizedDescription)

            let error = error as NSError
            let processedErrors = CoreDataErrorsParser.parse(error: error)

            if NSApp.runType.requiresEnvironment {
                Pixel.fire(.debug(event: .bookmarksSaveFailedOnImport, error: error),
                           withAdditionalParameters: processedErrors.errorPixelParameters)
                assertionFailure("LocalBookmarkStore: Saving of context failed, error: \(error.localizedDescription)")
            }
        }

        return total
    }

    private func createEntitiesFromBookmarks(allFolders: [BookmarkEntity],
                                             bookmarks: ImportedBookmarks,
                                             importSourceName: String,
                                             in context: NSManagedObjectContext) -> BookmarkImportResult {

        guard let root = bookmarksRoot(in: context) else {
            return .init(successful: 0,
                         duplicates: 0,
                         failed: bookmarks.numberOfBookmarks)
        }

        var total = BookmarkImportResult(successful: 0, duplicates: 0, failed: 0)

        var parent = root
        var makeFavorties = true
        if root.children?.count != 0 {
            makeFavorties = false
            parent = BookmarkEntity.makeFolder(title: "\(UserText.bookmarkImportedFromFolder) \(importSourceName)",
                                               parent: root,
                                               context: context)
        }

        if let bookmarksBar = bookmarks.topLevelFolders.bookmarkBar.children {
            let result = recursivelyCreateEntities(from: bookmarksBar,
                                                   parent: parent,
                                                   markBookmarksAsFavorite: makeFavorties,
                                                   in: context)

            total += result
        }

        if let otherBookmarks = bookmarks.topLevelFolders.otherBookmarks.children {
            let result = recursivelyCreateEntities(from: otherBookmarks,
                                                   parent: parent,
                                                   markBookmarksAsFavorite: false,
                                                   in: context)

            total += result
        }

        return total

    }

    private func recursivelyCreateEntities(from bookmarks: [ImportedBookmarks.BookmarkOrFolder],
                                           parent: BookmarkEntity,
                                           markBookmarksAsFavorite: Bool? = false,
                                           in context: NSManagedObjectContext) -> BookmarkImportResult {
        var total = BookmarkImportResult(successful: 0, duplicates: 0, failed: 0)

        let favoritesFolders = BookmarkUtils.fetchFavoritesFolders(for: favoritesDisplayMode, in: context)

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
            if bookmarkOrFolder.isDDGFavorite || (!bookmarkOrFolder.isFolder && markBookmarksAsFavorite == true) {
                bookmarkManagedObject.addToFavorites(folders: favoritesFolders)
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

        applyChangesAndSave { context in
            let entitiesFetchRequest = BookmarkEntity.fetchRequest()

            let entities = try context.fetch(entitiesFetchRequest)
            var deletedEntityCount = 0

            for entity in entities where entity.isInvalid {
                context.delete(entity)
                deletedEntityCount += 1
            }

            if deletedEntityCount > 0 {
                Pixel.fire(.debug(event: .removedInvalidBookmarkManagedObjects))
            }
        } onError: { [weak self] error in
            self?.commonOnSaveErrorHandler(error)

            os_log("Failed to remove invalid bookmark entities", type: .error)
        } onDidSave: {}

    }

    func resetBookmarks(completionHandler: @escaping (Error?) -> Void) {
        applyChangesAndSave { context in
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: BookmarkEntity.className())
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            try context.execute(deleteRequest)

            BookmarkUtils.prepareFoldersStructure(in: context)

        } onError: { error in
            assertionFailure("Failed to reset bookmarks: \(error)")
            DispatchQueue.main.async {
                completionHandler(error)
            }
        } onDidSave: { [self] in
            DispatchQueue.main.async {
                self.cacheReadOnlyTopLevelBookmarksFolders()
                completionHandler(nil)
            }
        }
    }

    // MARK: - Sync

    func handleFavoritesAfterDisablingSync() {
        applyChangesAndSave { [weak self] context in
            guard let self else {
                return
            }
            if self.favoritesDisplayMode.isDisplayUnified {
                BookmarkUtils.copyFavorites(from: .unified, to: .desktop, clearingNonNativeFavoritesFolder: .mobile, in: context)
            } else {
                BookmarkUtils.copyFavorites(from: .desktop, to: .unified, clearingNonNativeFavoritesFolder: .mobile, in: context)
            }
        } onError: { error in
            let nsError = error as NSError
            let processedErrors = CoreDataErrorsParser.parse(error: nsError)
            let params = processedErrors.errorPixelParameters
            Pixel.fire(.debug(event: .favoritesCleanupFailed, error: error), withAdditionalParameters: params)
        } onDidSave: {}
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

extension LocalBookmarkStore.BookmarkStoreError: CustomNSError {

    var errorCode: Int {
        switch self {
        case .storeDeallocated: return 1
        case .noObjectId: return 2
        case .badObjectId: return 3
        case .asyncFetchFailed: return 4
        case .missingParent: return 5
        case .missingEntity: return 6
        case .missingRoot: return 7
        case .missingFavoritesRoot: return 8
        case .saveLoopError: return 9
        }
    }

    var errorUserInfo: [String: Any] {
        guard case .saveLoopError(let error) = self, let error else {
            return [:]
        }

        return [NSUnderlyingErrorKey: error as NSError]
    }
}

fileprivate extension BookmarkEntity {

    var isInvalid: Bool {
        if title == nil && isPendingDeletion == false {
            return true
        }

        return false
    }

    func update(with baseEntity: BaseBookmarkEntity, favoritesFoldersToAddFavorite: [BookmarkEntity], favoritesDisplayMode: FavoritesDisplayMode) {
        if let bookmark = baseEntity as? Bookmark {
            update(with: bookmark, favoritesFoldersToAddFavorite: favoritesFoldersToAddFavorite, favoritesDisplayMode: favoritesDisplayMode)
        } else if let folder = baseEntity as? BookmarkFolder {
            update(with: folder)
        } else {
            assertionFailure("\(#file): Failed to cast base entity to Bookmark or BookmarkFolder")
        }
    }

    func update(with bookmark: Bookmark, favoritesFoldersToAddFavorite: [BookmarkEntity], favoritesDisplayMode: FavoritesDisplayMode) {
        url = bookmark.url
        title = bookmark.title
        if bookmark.isFavorite {
            addToFavorites(folders: favoritesFoldersToAddFavorite)
        } else {
            removeFromFavorites(with: favoritesDisplayMode)
        }
    }

    func update(with folder: BookmarkFolder) {
        title = folder.title
    }

}
