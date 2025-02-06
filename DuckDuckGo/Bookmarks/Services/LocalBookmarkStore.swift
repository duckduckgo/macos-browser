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
import os.log
import BrowserServicesKit

protocol BookmarkEntityProtocol {
    var uuid: String? { get }
    var bookmarkEntityParent: BookmarkEntityProtocol? { get }
}
extension BookmarkEntity: BookmarkEntityProtocol {
    var bookmarkEntityParent: (any BookmarkEntityProtocol)? {
        parent
    }
}

final class LocalBookmarkStore: BookmarkStore {
    typealias BookmarkEntityAtIndex = (entity: BaseBookmarkEntity,
                                       index: Int?,
                                       indexInFavoritesArray: Int?)

    convenience init(bookmarkDatabase: BookmarkDatabase) {
        self.init(
            contextProvider: {
                let context = bookmarkDatabase.db.makeContext(concurrencyType: .privateQueueConcurrencyType)
                context.stalenessInterval = 0
                return context
            },
            preFormFactorSpecificFavoritesOrder: bookmarkDatabase.preFormFactorSpecificFavoritesFolderOrder
        )
    }

    // Directly used in tests
    init(
        contextProvider: @escaping () -> NSManagedObjectContext,
        appearancePreferences: AppearancePreferences = .shared,
        preFormFactorSpecificFavoritesOrder: [String]? = nil
    ) {
        self.contextProvider = contextProvider
        self.preFormFactorSpecificFavoritesOrder = preFormFactorSpecificFavoritesOrder

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
        case badModelMapping
    }

    private(set) var favoritesDisplayMode: FavoritesDisplayMode
    private(set) var didMigrateToFormFactorSpecificFavorites: Bool = false
    private var preFormFactorSpecificFavoritesOrder: [String]?

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

        assertionFailure("LocalBookmarkStore: Saving of context failed: \(error)")

        if let localError = error as? BookmarkStoreError {
            if case BookmarkStoreError.saveLoopError(let innerError) = localError, let innerError {
                let processedErrors = CoreDataErrorsParser.parse(error: innerError as NSError)

                var params = processedErrors.errorPixelParameters
                params[PixelKit.Parameters.errorSource] = source
                PixelKit.fire(DebugEvent(GeneralPixel.bookmarksSaveFailed, error: error),
                           withAdditionalParameters: params)
            } else {
                PixelKit.fire(DebugEvent(GeneralPixel.bookmarksSaveFailed, error: localError),
                           withAdditionalParameters: [PixelKit.Parameters.errorSource: source])
            }
        } else {
            let error = error as NSError
            let processedErrors = CoreDataErrorsParser.parse(error: error)

            var params = processedErrors.errorPixelParameters
            params[PixelKit.Parameters.errorSource] = source
            PixelKit.fire(DebugEvent(GeneralPixel.bookmarksSaveFailed, error: error),
                       withAdditionalParameters: params)
        }
    }

    private func migrateToFormFactorSpecificFavoritesFolders() {
        let context = makeContext()

        context.performAndWait {
            do {
                BookmarkFormFactorFavoritesMigration.migrateToFormFactorSpecificFavorites(
                    byCopyingExistingTo: .desktop,
                    preservingOrderOf: preFormFactorSpecificFavoritesOrder,
                    in: context
                )

                if context.hasChanges {
                    try context.save(onErrorFire: GeneralPixel.bookmarksMigrationCouldNotPrepareMultipleFavoriteFolders)
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
        context.perform { [favoritesDisplayMode] in
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
                    results = (rootFolder?.childrenArray ?? []) + orphanedEntities
                case .favorites:
                    results = self.favoritesRoot(in: context)?.favoritesArray ?? []
                }

                let entities: [BaseBookmarkEntity] = results.compactMap { entity in
                    BaseBookmarkEntity.from(managedObject: entity,
                                            parentFolderUUID: entity.parent?.uuid,
                                            favoritesDisplayMode: favoritesDisplayMode)
                }

                mainQueueCompletion(bookmarks: entities, error: nil)
            } catch let error {
                completion(nil, error)
            }
        }
    }

    func save(entitiesAtIndices: [BookmarkEntityAtIndex], completion: @escaping (Error?) -> Void) {
        applyChangesAndSave(changes: { [weak self] context in
            guard let self else { throw BookmarkStoreError.storeDeallocated }

            let (entitiesByUUID, objectsToInsertIntoParent) = try restoreBookmarksInParentEntity(entitiesAtIndices, in: context)

            for (parentEntity, (managedObjects, insertionIndices)) in objectsToInsertIntoParent {
                move(entities: managedObjects, to: insertionIndices, within: parentEntity)
            }

            try handleFavorites(entitiesAtIndices, entitiesByUUID: entitiesByUUID, in: context)
        }, onError: { [weak self] error in
            self?.commonOnSaveErrorHandler(error)
            DispatchQueue.main.async { completion(error) }
        }, onDidSave: {
            DispatchQueue.main.async { completion(nil) }
        })
    }

    func saveBookmarks(for websitesInfo: [WebsiteInfo], inNewFolderNamed folderName: String, withinParentFolder parent: ParentFolderType) {
        do {
            try applyChangesAndSave { context in
                // Fetch Parent folder
                let parentFolder = try bookmarkEntity(for: parent, in: context)
                // Create new Folder for all bookmarks
                let newFolderMO = BookmarkEntity.makeFolder(title: folderName, parent: parentFolder, context: context)
                // Save the bookmarks
                websitesInfo.forEach { info in
                    _ = BookmarkEntity.makeBookmark(title: info.title, url: info.url.absoluteString, parent: newFolderMO, context: context)
                }
            }
        } catch {
            commonOnSaveErrorHandler(error)
        }
    }

    func remove(objectsWithUUIDs identifiers: [String], completion: @escaping (Error?) -> Void) {

        applyChangesAndSave(changes: { context in
            let fetchRequest = BaseBookmarkEntity.entities(with: identifiers)
            let fetchResults = (try? context.fetch(fetchRequest)) ?? []

            if fetchResults.count != identifiers.count {
                assertionFailure("\(self): Fetched bookmark entities \(fetchResults) didn't match the number of provided UUIDs \(identifiers)")
            }

            for object in fetchResults {
                object.markPendingDeletion()
            }
        }, onError: { [weak self] error in
            self?.commonOnSaveErrorHandler(error)
            DispatchQueue.main.async { completion(error) }
        }, onDidSave: {
            DispatchQueue.main.async { completion(nil) }
        })
    }

    func update(bookmark: Bookmark) {

        do {
            try applyChangesAndSave(changes: { [favoritesDisplayMode] context in
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

    func bookmarkEntities(withIds ids: [String]) -> [BaseBookmarkEntity]? {
        let context = makeContext()

        var entitiesToReturn: [BaseBookmarkEntity]?

        context.performAndWait { [favoritesDisplayMode] in
            let fetchRequest = BaseBookmarkEntity.entities(with: ids)
            fetchRequest.returnsObjectsAsFaults = false
            do {
                let results = try context.fetch(fetchRequest)

                entitiesToReturn = results.compactMap { entity in
                    BaseBookmarkEntity.from(managedObject: entity,
                                            parentFolderUUID: entity.parent?.uuid,
                                            favoritesDisplayMode: favoritesDisplayMode)
                }

            } catch {
                Logger.bookmarks.error("Failed to fetch bookmark entitis, with error: \(error.localizedDescription, privacy: .public)")
            }
        }

        return entitiesToReturn
    }

    func update(folder: BookmarkFolder) {
        do {
            _ = try applyChangesAndSave(changes: { [weak self] context in
                guard let self = self else {
                    throw BookmarkStoreError.storeDeallocated
                }
                try update(folder: folder, in: context)
            })
        } catch {
            let error = error as NSError
            commonOnSaveErrorHandler(error)
        }
    }

    func update(folder: BookmarkFolder, andMoveToParent parent: ParentFolderType) {
        do {
            _ = try applyChangesAndSave(changes: { [weak self] context in
                guard let self = self else {
                    throw BookmarkStoreError.storeDeallocated
                }
                let folderEntity = try update(folder: folder, in: context)
                try move(entities: [folderEntity], toIndex: nil, withinParentFolderType: parent, in: context)
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

        applyChangesAndSave(changes: { [favoritesDisplayMode] context in
            let bookmarksFetchRequest = BaseBookmarkEntity.entities(with: uuids)
            bookmarksFetchRequest.returnsObjectsAsFaults = false
            let bookmarksResults = try? context.fetch(bookmarksFetchRequest)

            guard let bookmarkManagedObjects = bookmarksResults else {
                assertionFailure("\(#file): Failed to get BookmarkEntity from the context")
                throw BookmarkStoreError.missingEntity
            }

            let favoritesFolders = BookmarkUtils.fetchFavoritesFolders(for: favoritesDisplayMode, in: context)
            bookmarkManagedObjects.forEach { managedObject in
                if let entity = BaseBookmarkEntity.from(managedObject: managedObject, parentFolderUUID: nil, favoritesDisplayMode: favoritesDisplayMode) {
                    update(entity)
                    managedObject.update(with: entity, favoritesFoldersToAddFavorite: favoritesFolders, favoritesDisplayMode: favoritesDisplayMode)
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
                  parentFolder.isFolder,
                  let uuid = folderToMove.uuid else { return }

            canMoveObject = Self.validateObjectMove(withUUID: uuid, to: parentFolder)
        }

        return canMoveObject
    }

    static func validateObjectMove(withUUID uuid: String, to parent: BookmarkEntityProtocol) -> Bool {
        guard uuid != parent.uuid else { return false }
        var currentParentFolder = parent.bookmarkEntityParent

        // Check each parent and verify that the folder being moved isn't being given itself as an ancestor
        while let currentParent = currentParentFolder {
            if currentParent.uuid == uuid {
                return false
            }

            currentParentFolder = currentParent.bookmarkEntityParent
        }
        return true
    }

    func move(objectUUIDs: [String], toIndex index: Int?, withinParentFolder type: ParentFolderType, completion: @escaping (Error?) -> Void) {

        applyChangesAndSave(changes: { [weak self] context in
            guard let self = self else {
                throw BookmarkStoreError.storeDeallocated
            }

            // Guarantee that bookmarks are fetched in the same order as the UUIDs. In the future, this should fetch all objects at once with a
            // batch fetch request and have them sorted in the correct order.
            let bookmarkManagedObjects: [BookmarkEntity] = objectUUIDs.compactMap { uuid in
                let entityFetchRequest = BaseBookmarkEntity.singleEntity(with: uuid)
                return (try? context.fetch(entityFetchRequest))?.first
            }

            try move(entities: bookmarkManagedObjects, toIndex: index, withinParentFolderType: type, in: context)

        }, onError: { [weak self] error in
            self?.commonOnSaveErrorHandler(error)
            DispatchQueue.main.async { completion(error) }
        }, onDidSave: {
            DispatchQueue.main.async { completion(nil) }
        })
    }

    private func move(entities bookmarkManagedObjects: [BookmarkEntity], to indices: IndexSet = [], within newParentFolder: BookmarkEntity) {
        assert(bookmarkManagedObjects.count == indices.count || indices.isEmpty)
        var allChildren = (newParentFolder.children?.array as? [BookmarkEntity]) ?? []
        // shift indeces if needed to skip objects pending deletion and stubs
        let indices = allChildren.adjustInsertionIndices(indices) { !($0.isStub || $0.isPendingDeletion) }.map(\.self)
        // make pairs of objects and insertion indices (appending at the end if no matching index)
        let bookmarkManagedObjectsAndInsertionIndices = bookmarkManagedObjects.enumerated().map { idx, obj in (indices[safe: idx] ?? Int.max, obj) }

        var insertionIndexShift = 0
        for (var insertionIndex, bookmarkManagedObject) in bookmarkManagedObjectsAndInsertionIndices {
            // moving within the same folder?
            if bookmarkManagedObject.parent?.id == newParentFolder.id {
                guard let currentIndex = allChildren.firstIndex(of: bookmarkManagedObject) else {
                    assertionFailure("Object index not found in its parent")
                    continue
                }
                allChildren.remove(at: currentIndex)
                guard currentIndex != insertionIndex else { continue }
                // decrement insertion index if moving object within the same folder to a higher index
                if insertionIndex > currentIndex {
                    insertionIndexShift -= 1
                }
            }

            bookmarkManagedObject.parent = nil

            insertionIndex = max(min(insertionIndex + insertionIndexShift, allChildren.count), 0)
            newParentFolder.insertIntoChildren(bookmarkManagedObject, at: insertionIndex)
            allChildren.insert(bookmarkManagedObject, at: insertionIndex)
        }
    }

    func moveFavorites(with objectUUIDs: [String], toIndex index: Int?, completion: @escaping (Error?) -> Void) {

        applyChangesAndSave(changes: { [favoritesDisplayMode] context in
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

            if let index = index, index < displayedFavoritesFolder.favoritesArray.count {
                var currentInsertionIndex = max(index, 0)

                for bookmarkManagedObject in bookmarkManagedObjects {
                    var adjustedInsertionIndex = currentInsertionIndex

                    if let currentIndex = displayedFavoritesFolder.favoritesArray.firstIndex(of: bookmarkManagedObject),
                       currentInsertionIndex > currentIndex {
                        adjustedInsertionIndex -= 1
                    }
                    let nextInsertionIndex = adjustedInsertionIndex + 1

                    bookmarkManagedObject.removeFromFavorites(with: favoritesDisplayMode)

                    if adjustedInsertionIndex < displayedFavoritesFolder.favoritesArray.count {
                        // Handle stubs
                        let allChildren = (displayedFavoritesFolder.favorites?.array as? [BookmarkEntity]) ?? []
                        if displayedFavoritesFolder.favoritesArray.count != allChildren.count {
                            var correctedIndex = 0

                            while adjustedInsertionIndex > 0 && correctedIndex < allChildren.count {
                                if allChildren[correctedIndex].isStub == false {
                                    adjustedInsertionIndex -= 1
                                }
                                correctedIndex += 1
                            }
                            bookmarkManagedObject.addToFavorites(insertAt: correctedIndex,
                                                                 favoritesRoot: displayedFavoritesFolder)
                            bookmarkManagedObject.addToFavorites(folders: favoritesFoldersWithoutDisplayed)
                        } else {
                            bookmarkManagedObject.addToFavorites(insertAt: adjustedInsertionIndex,
                                                                 favoritesRoot: displayedFavoritesFolder)
                            bookmarkManagedObject.addToFavorites(folders: favoritesFoldersWithoutDisplayed)
                        }
                    } else {
                        bookmarkManagedObject.addToFavorites(folders: favoritesFolders)
                    }

                    currentInsertionIndex = nextInsertionIndex
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
    func importBookmarks(_ bookmarks: ImportedBookmarks, source: BookmarkImportSource) -> BookmarksImportSummary {
        var total = BookmarksImportSummary(successful: 0, duplicates: 0, failed: 0)

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
            Logger.dataImportExport.error("Failed to import bookmarks, with error: \(error.localizedDescription, privacy: .public)")

            let error = error as NSError
            let processedErrors = CoreDataErrorsParser.parse(error: error)

            if NSApp.runType.requiresEnvironment {
                PixelKit.fire(DebugEvent(GeneralPixel.bookmarksSaveFailedOnImport, error: error),
                           withAdditionalParameters: processedErrors.errorPixelParameters)
                assertionFailure("LocalBookmarkStore: Saving of context failed, error: \(error.localizedDescription)")
            }
        }

        return total
    }

    private func createEntitiesFromBookmarks(allFolders: [BookmarkEntity],
                                             bookmarks: ImportedBookmarks,
                                             importSourceName: String,
                                             in context: NSManagedObjectContext) -> BookmarksImportSummary {

        guard let root = bookmarksRoot(in: context) else {
            return .init(successful: 0,
                         duplicates: 0,
                         failed: bookmarks.numberOfBookmarks)
        }

        var total = BookmarksImportSummary(successful: 0, duplicates: 0, failed: 0)

        var parent = root
        var makeFavorties = true
        if root.children?.count != 0 {
            makeFavorties = false
            parent = BookmarkEntity.makeFolder(title: "\(UserText.bookmarkImportedFromFolder) \(importSourceName)",
                                               parent: root,
                                               context: context)
        }

        if let bookmarksBar = bookmarks.topLevelFolders.bookmarkBar?.children {
            let result = recursivelyCreateEntities(from: bookmarksBar,
                                                   parent: parent,
                                                   markBookmarksAsFavorite: makeFavorties,
                                                   in: context)

            total += result
        }

        for folder in [bookmarks.topLevelFolders.otherBookmarks, bookmarks.topLevelFolders.syncedBookmarks] {
            guard let folder, let children = folder.children else { continue }

            var folderParent = parent
            // keep the original imported folder if bookmarks bar is not empty
            // import to import root otherwise
            if !parent.childrenArray.isEmpty, !folder.name.isEmpty, !children.isEmpty {
                folderParent = BookmarkEntity.makeFolder(title: folder.name,
                                                         parent: parent,
                                                         context: context)
            }
            let result = recursivelyCreateEntities(from: children,
                                                   parent: folderParent,
                                                   markBookmarksAsFavorite: false,
                                                   in: context)

            total += result
        }

        return total

    }

    private func recursivelyCreateEntities(from bookmarks: [ImportedBookmarks.BookmarkOrFolder],
                                           parent: BookmarkEntity,
                                           markBookmarksAsFavorite: Bool? = false,
                                           in context: NSManagedObjectContext) -> BookmarksImportSummary {
        var total = BookmarksImportSummary(successful: 0, duplicates: 0, failed: 0)

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
                PixelKit.fire(DebugEvent(GeneralPixel.removedInvalidBookmarkManagedObjects))
            }
        } onError: { [weak self] error in
            self?.commonOnSaveErrorHandler(error)

            Logger.bookmarks.error("Failed to remove invalid bookmark entities")
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
        applyChangesAndSave { [favoritesDisplayMode] context in
            if favoritesDisplayMode.isDisplayUnified {
                BookmarkUtils.copyFavorites(from: .unified, to: .desktop, clearingNonNativeFavoritesFolder: .mobile, in: context)
            } else {
                BookmarkUtils.copyFavorites(from: .desktop, to: .unified, clearingNonNativeFavoritesFolder: .mobile, in: context)
            }
        } onError: { error in
            let nsError = error as NSError
            let processedErrors = CoreDataErrorsParser.parse(error: nsError)
            let params = processedErrors.errorPixelParameters
            PixelKit.fire(DebugEvent(GeneralPixel.favoritesCleanupFailed, error: error), withAdditionalParameters: params)
        } onDidSave: {}
    }

    // MARK: - Concurrency

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

    // MARK: - Restore boomarks helper functions

    /// Restores bookmarks within their respective parent entities and maps them by their UUID.
    /// - Parameters:
    ///   - entitiesAtIndices: An array of `BookmarkEntityAtIndex`, containing entities with their target indices.
    ///   - context: The managed object context for interacting with Core Data.
    /// - Returns: A tuple containing a dictionary that maps UUID strings to `BookmarkEntity` instances and a mapping of parent entities to their children and insertion indices.
    /// - Throws: An error if a parent entity cannot be retrieved.
    private func restoreBookmarksInParentEntity(_ entitiesAtIndices: [BookmarkEntityAtIndex],
                                                in context: NSManagedObjectContext) throws
                            -> ([String: BookmarkEntity], [BookmarkEntity: ([BookmarkEntity], IndexSet)]) {
        var entitiesByUUID: [String: BookmarkEntity] = [:]
        var objectsToInsertIntoParent = [BookmarkEntity: ([BookmarkEntity], IndexSet)]()

        for (entity, index, _) in entitiesAtIndices.sorted(by: { $0.index ?? Int.max < $1.index ?? Int.max }) {
            let parentEntity = try parent(for: entity, in: context)
            let bookmarkMO = createBookmarkDatabaseObject(from: entity, in: context)
            entitiesByUUID[entity.id] = bookmarkMO

            withUnsafeMutablePointer(to: &objectsToInsertIntoParent[parentEntity, default: ([], IndexSet())]) {
                $0.pointee.0.append(bookmarkMO)
                if let index {
                    $0.pointee.1.insert(index)
                }
            }
        }

        return (entitiesByUUID, objectsToInsertIntoParent)
    }

    private func handleFavorites(_ entitiesAtIndices: [BookmarkEntityAtIndex],
                                 entitiesByUUID: [String: BookmarkEntity],
                                 in context: NSManagedObjectContext) throws {
        let displayedFavoritesFolder = try fetchDisplayedFavoritesFolder(in: context)
        let favoritesFoldersWithoutDisplayed = fetchOtherFavoritesFolders(in: context)

        try restoreFavorites(entitiesAtIndices,
                             entitiesByUUID: entitiesByUUID,
                             displayedFavoritesFolder: displayedFavoritesFolder,
                             favoritesFoldersWithoutDisplayed: favoritesFoldersWithoutDisplayed,
                             in: context)

        try insertNewFavorites(entitiesAtIndices,
                               entitiesByUUID: entitiesByUUID,
                               displayedFavoritesFolder: displayedFavoritesFolder,
                               favoritesFoldersWithoutDisplayed: favoritesFoldersWithoutDisplayed,
                               in: context)
    }

    /// Restores favorite bookmark entities to their correct positions within the favorites list.
    ///
    /// - Parameters:
    ///   - entitiesAtIndices: An array of `BookmarkEntityAtIndex` objects, containing bookmark entities along with their respective indices.
    ///   - entitiesByUUID: A dictionary mapping UUID strings to `BookmarkEntity` objects, providing quick access to entities by their unique identifiers.
    ///   - displayedFavoritesFolder: The `BookmarkEntity` representing the currently displayed folder of favorites.
    ///   - favoritesFoldersWithoutDisplayed: An array of `BookmarkEntity` objects representing all other favorites folders, excluding the currently displayed folder.
    ///   - context: The `NSManagedObjectContext` used to perform Core Data operations.
    ///
    /// - Throws: This function can throw errors if adding an entity to the favorites fails during Core Data operations.
    ///
    private func restoreFavorites(_ entitiesAtIndices: [BookmarkEntityAtIndex],
                                  entitiesByUUID: [String: BookmarkEntity],
                                  displayedFavoritesFolder: BookmarkEntity,
                                  favoritesFoldersWithoutDisplayed: [BookmarkEntity],
                                  in context: NSManagedObjectContext) throws {
        let sortedEntitiesByFavoritesIndex = sortEntitiesByFavoritesIndex(entitiesAtIndices)
        let adjustedIndices = calculateAdjustedIndices(for: sortedEntitiesByFavoritesIndex, in: displayedFavoritesFolder)

        assert(adjustedIndices.count == sortedEntitiesByFavoritesIndex.count,
               "Adjusted indices array size is different than sorted entities array size")

        try zip(sortedEntitiesByFavoritesIndex.map(\.entity), adjustedIndices).forEach { entity, indexInFavoritesArray in
            try addEntityToFavorites(
                entity,
                at: indexInFavoritesArray,
                entitiesByUUID: entitiesByUUID,
                displayedFavoritesFolder: displayedFavoritesFolder,
                otherFavoritesFolders: favoritesFoldersWithoutDisplayed
            )
        }
    }

    /// Inserts new favorite bookmark entities into the favorites list if they meet certain conditions.
    ///
    /// - Parameters:
    ///   - entitiesAtIndices: An array of `BookmarkEntityAtIndex` objects, which contain bookmark entities and their respective indices.
    ///   - entitiesByUUID: A dictionary mapping UUID strings to `BookmarkEntity` objects, providing quick access to entities by their unique identifiers.
    ///   - displayedFavoritesFolder: The `BookmarkEntity` representing the currently displayed folder of favorites.
    ///   - favoritesFoldersWithoutDisplayed: An array of `BookmarkEntity` objects representing all other favorites folders, excluding the currently displayed folder.
    ///   - context: The `NSManagedObjectContext` used to perform Core Data operations.
    ///
    /// - Throws: This function can throw errors if adding an entity to the favorites fails during the Core Data operations.
    ///
    /// - Discussion:
    ///   This function iterates through the list of entities with their respective indices (`entitiesAtIndices`). For each entity:
    ///   - If the entity is a `Bookmark`, is marked as a favorite (`isFavorite`), and does not have an index in the favorites array (`indexInFavoritesArray == nil`), it is considered new, so we need to insert it.
    ///   - The `addEntityToFavorites` function is then called to add the bookmark to the list of favorites. The entity is added without specifying an index (`at: nil`), allowing it to be inserted at a default position (last position).
    ///   - The function uses `entitiesByUUID` to resolve relationships between entities, as well as the `displayedFavoritesFolder` and `favoritesFoldersWithoutDisplayed` to ensure that the entity is added correctly to the appropriate folder structure.
    private func insertNewFavorites(_ entitiesAtIndices: [BookmarkEntityAtIndex],
                                    entitiesByUUID: [String: BookmarkEntity],
                                    displayedFavoritesFolder: BookmarkEntity,
                                    favoritesFoldersWithoutDisplayed: [BookmarkEntity],
                                    in context: NSManagedObjectContext) throws {
        try entitiesAtIndices.forEach { (entity, _, indexInFavoritesArray) in
            if let bookmark = entity as? Bookmark,
               bookmark.isFavorite,
               indexInFavoritesArray == nil {
                try addEntityToFavorites(
                    entity,
                    at: nil,
                    entitiesByUUID: entitiesByUUID,
                    displayedFavoritesFolder: displayedFavoritesFolder,
                    otherFavoritesFolders: favoritesFoldersWithoutDisplayed)
            }
        }
    }

    private func fetchDisplayedFavoritesFolder(in context: NSManagedObjectContext) throws -> BookmarkEntity {
        let displayedFavoritesFolderUUID = favoritesDisplayMode.displayedFolder.rawValue
        guard let displayedFavoritesFolder = BookmarkUtils.fetchFavoritesFolder(withUUID: displayedFavoritesFolderUUID, in: context) else {
            throw BookmarkStoreError.missingFavoritesRoot
        }
        return displayedFavoritesFolder
    }

    private func fetchOtherFavoritesFolders(in context: NSManagedObjectContext) -> [BookmarkEntity] {
        let displayedFavoritesFolderUUID = favoritesDisplayMode.displayedFolder.rawValue
        let favoritesFolders = BookmarkUtils.fetchFavoritesFolders(for: favoritesDisplayMode, in: context)
        return favoritesFolders.filter { $0.uuid != displayedFavoritesFolderUUID }
    }

    private func sortEntitiesByFavoritesIndex(_ entitiesAtIndices: [BookmarkEntityAtIndex]) -> [BookmarkEntityAtIndex] {
        return entitiesAtIndices
            .filter { $0.indexInFavoritesArray != nil }
            .sorted { ($0.indexInFavoritesArray ?? Int.max) < ($1.indexInFavoritesArray ?? Int.max) }
    }

    private func calculateAdjustedIndices(for sortedEntities: [BookmarkEntityAtIndex], in folder: BookmarkEntity) -> IndexSet {
        let indicesInFavoritesArray = sortedEntities.compactMap(\.indexInFavoritesArray)
        return folder.favorites?.array.adjustInsertionIndices(IndexSet(indicesInFavoritesArray)) { object in
            guard let bookmarkMO = object as? BookmarkEntity else {
                return false
            }
            return !(bookmarkMO.isStub || bookmarkMO.isPendingDeletion)
        } ?? IndexSet()
    }

    private func addEntityToFavorites(_ entity: BaseBookmarkEntity,
                                      at index: Int?,
                                      entitiesByUUID: [String: BookmarkEntity],
                                      displayedFavoritesFolder: BookmarkEntity,
                                      otherFavoritesFolders: [BookmarkEntity]) throws {
        guard let bookmarkMO = entitiesByUUID[entity.id] else {
            throw BookmarkStoreError.missingEntity
        }

        if let bookmark = entity as? Bookmark, bookmark.isFavorite {
            bookmarkMO.addToFavorites(insertAt: index, favoritesRoot: displayedFavoritesFolder)
            bookmarkMO.addToFavorites(folders: otherFavoritesFolders)
        }
    }

    private func parent(for entity: BaseBookmarkEntity, in context: NSManagedObjectContext) throws -> BookmarkEntity {
        if let parentId = entity.parentFolderUUID, parentId != PseudoFolder.bookmarks.id, parentId != "bookmarks_root",
           let parentFetchRequestResult = try? context.fetch(BaseBookmarkEntity.singleEntity(with: parentId)).first {
            return parentFetchRequestResult
        } else if let root = bookmarksRoot(in: context) {
            return root
        } else {
            PixelKit.fire(DebugEvent(GeneralPixel.missingParent))
            throw BookmarkStoreError.missingParent
        }
    }

    private func createBookmarkDatabaseObject(from entity: BaseBookmarkEntity,
                                              in context: NSManagedObjectContext) -> BookmarkEntity {
        let bookmarkMO = BookmarkEntity(context: context)

        switch entity {
        case let folder as BookmarkFolder:
            bookmarkMO.title = folder.title
            bookmarkMO.isFolder = true
        case let bookmark as Bookmark:
            bookmarkMO.title = bookmark.title
            bookmarkMO.url = bookmark.url
            bookmarkMO.isFolder = false
        default:
            fatalError("Unexpected Bookmark Entity type \(entity)")
        }

        bookmarkMO.uuid = entity.id

        return bookmarkMO
    }
}

private extension LocalBookmarkStore {

    @discardableResult
    func update(folder: BookmarkFolder, in context: NSManagedObjectContext) throws -> BookmarkEntity {
        let folderFetchRequest = BaseBookmarkEntity.singleEntity(with: folder.id)
        let folderFetchRequestResults = try? context.fetch(folderFetchRequest)

        guard let bookmarkFolderMO = folderFetchRequestResults?.first else {
            assertionFailure("LocalBookmarkStore: Failed to get BookmarkEntity from the context")
            throw BookmarkStoreError.missingEntity
        }

        bookmarkFolderMO.update(with: folder)
        return bookmarkFolderMO
    }

    func move(entities: [BookmarkEntity], toIndex index: Int?, withinParentFolderType type: ParentFolderType, in context: NSManagedObjectContext) throws {
        let newParentFolder = try bookmarkEntity(for: type, in: context)

        if let index = index, index < newParentFolder.childrenArray.count {
            self.move(entities: entities, to: IndexSet(integersIn: (entities.indices.lowerBound + index)..<(entities.indices.upperBound + index)), within: newParentFolder)
        } else {
            for bookmarkManagedObject in entities {
                bookmarkManagedObject.parent = nil
                newParentFolder.addToChildren(bookmarkManagedObject)
            }
        }
    }

    func bookmarkEntity(for parentFolderType: ParentFolderType, in context: NSManagedObjectContext) throws -> BookmarkEntity {
        guard let rootFolder = bookmarksRoot(in: context) else {
            throw BookmarkStoreError.missingRoot
        }

        let parentFolder: BookmarkEntity

        switch parentFolderType {
        case .root:
            parentFolder = rootFolder
        case let .parent(parentUUID):
            let bookmarksFetchRequest = BaseBookmarkEntity.singleEntity(with: parentUUID)

            if let fetchedParent = try context.fetch(bookmarksFetchRequest).first, fetchedParent.isFolder {
                parentFolder = fetchedParent
            } else {
                throw BookmarkStoreError.missingEntity
            }
        }
        return parentFolder
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
        case .badModelMapping: return 10
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
        if bookmark.isFavorite && Set(favoritesFoldersToAddFavorite) != favoriteFoldersSet {
            addToFavorites(folders: favoritesFoldersToAddFavorite)
        } else if !bookmark.isFavorite && !favoriteFoldersSet.isEmpty {
            removeFromFavorites(with: favoritesDisplayMode)
        }
    }

    func update(with folder: BookmarkFolder) {
        title = folder.title
    }

}
