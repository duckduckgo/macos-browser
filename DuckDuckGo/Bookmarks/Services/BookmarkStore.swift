//
//  BookmarkStore.swift
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

import Foundation
import CoreData
import Cocoa
import os.log

enum BookmarkStoreFetchPredicateType {
    case bookmarks
    case topLevelEntities
}

enum ParentFolderType {
    case root
    case parent(UUID)
}

struct BookmarkImportResult: Equatable {
    var successful: Int
    var duplicates: Int
    var failed: Int

    static func += (left: inout BookmarkImportResult, right: BookmarkImportResult) {
        left.successful += right.successful
        left.duplicates += right.duplicates
        left.failed += right.failed
    }
}

protocol BookmarkStore {

    func loadAll(type: BookmarkStoreFetchPredicateType, completion: @escaping ([BaseBookmarkEntity]?, Error?) -> Void)
    func save(bookmark: Bookmark, parent: BookmarkFolder?, index: Int?, completion: @escaping (Bool, Error?) -> Void)
    func save(folder: BookmarkFolder, parent: BookmarkFolder?, completion: @escaping (Bool, Error?) -> Void)
    func remove(objectsWithUUIDs: [UUID], completion: @escaping (Bool, Error?) -> Void)
    func update(bookmark: Bookmark)
    func update(folder: BookmarkFolder)
    func add(objectsWithUUIDs: [UUID], to parent: BookmarkFolder?, completion: @escaping (Error?) -> Void)
    func update(objectsWithUUIDs uuids: [UUID], update: @escaping (BaseBookmarkEntity) -> Void, completion: @escaping (Error?) -> Void)
    func canMoveObjectWithUUID(objectUUID uuid: UUID, to parent: BookmarkFolder) -> Bool
    func move(objectUUIDs: [UUID], toIndex: Int?, withinParentFolder: ParentFolderType, completion: @escaping (Error?) -> Void)
    func importBookmarks(_ bookmarks: ImportedBookmarks, source: BookmarkImportSource) -> BookmarkImportResult

}

// swiftlint:disable:next type_body_length
final class LocalBookmarkStore: BookmarkStore {
    
    enum Constants {
        static let rootFolderUUID = "87E09C05-17CB-4185-9EDF-8D1AF4312BAF"
        static let favoritesFolderUUID = "23B11CC4-EA56-4937-8EC1-15854109AE35"
    }

    init() {
        sharedInitialization()
    }

    init(context: NSManagedObjectContext) {
        self.context = context
        sharedInitialization()
    }
    
    private func sharedInitialization() {
        removeInvalidBookmarkEntities()
        migrateTopLevelStorageToRootLevelBookmarksFolder()
        cacheReadOnlyTopLevelBookmarksFolder()
        createAndCacheFavoritesFolderIfNeeded()
    }

    enum BookmarkStoreError: Error {
        case storeDeallocated
        case insertFailed
        case noObjectId
        case badObjectId
        case asyncFetchFailed
    }

    private lazy var context = Database.shared.makeContext(concurrencyType: .privateQueueConcurrencyType, name: "Bookmark")
    
    /// All entities within the bookmarks store must exist under this root level folder. Because this value is used so frequently, it is cached here.
    private var rootLevelFolder: BookmarkManagedObject?

    /// All favorites must additionally be children of this special folder. Because this value is used so frequently, it is cached here.
    private(set) var favoritesFolder: BookmarkManagedObject?

    private func cacheReadOnlyTopLevelBookmarksFolder() {
        context.performAndWait {
            let fetchRequest = NSFetchRequest<BookmarkManagedObject>(entityName: BookmarkManagedObject.className())
            fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K == nil AND %K == true",
                                                 "id",
                                                 Constants.rootFolderUUID,
                                                 #keyPath(BookmarkManagedObject.parentFolder),
                                                 #keyPath(BookmarkManagedObject.isFolder))
            
            let results = (try? context.fetch(fetchRequest)) ?? []

            guard results.count == 1 else {
                fatalError("There shouldn't be more than one root folder")
            }
            
            guard let folder = results.first else {
                fatalError("Top level folder missing")
            }
            
            self.rootLevelFolder = folder
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
            let fetchRequest: NSFetchRequest<BookmarkManagedObject>

            switch type {
            case .bookmarks:
                fetchRequest = Bookmark.bookmarksFetchRequest()
            case .topLevelEntities:
                fetchRequest = Bookmark.topLevelEntitiesFetchRequest()
            }

            fetchRequest.returnsObjectsAsFaults = false

            do {
                let results: [BookmarkManagedObject]
                
                switch type {
                case .bookmarks:
                    results = try self.context.fetch(fetchRequest)
                case .topLevelEntities:
                    // When fetching the top level entities, the root folder will be returned. To make things simpler for the caller, this function
                    // will return the children of the root folder, as the root folder is an implementation detail of the bookmarks store.
                    let entities = try self.context.fetch(fetchRequest)
                    results = entities.first?.children?.array as? [BookmarkManagedObject] ?? []
                }
                
                let entities: [BaseBookmarkEntity] = results.compactMap { entity in
                    BaseBookmarkEntity.from(managedObject: entity, parentFolderUUID: entity.parentFolder?.id)
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

            let managedObject = NSEntityDescription.insertNewObject(forEntityName: BookmarkManagedObject.className(), into: self.context)

            guard let bookmarkMO = managedObject as? BookmarkManagedObject else {
                assertionFailure("LocalBookmarkStore: Failed to init BookmarkManagedObject")
                DispatchQueue.main.async { completion(false, BookmarkStoreError.insertFailed) }
                return
            }

            bookmarkMO.id = bookmark.id
            bookmarkMO.urlEncrypted = bookmark.url as NSURL?
            bookmarkMO.titleEncrypted = bookmark.title as NSString
            bookmarkMO.favoritesFolder = bookmark.isFavorite ? self.favoritesFolder : nil
            bookmarkMO.isFolder = bookmark.isFolder
            bookmarkMO.dateAdded = NSDate.now

            if let parent = parent {
                let parentFetchRequest = BaseBookmarkEntity.singleEntity(with: parent.id)
                let parentFetchRequestResults = try? self.context.fetch(parentFetchRequest)
                let parentFolder = parentFetchRequestResults?.first
                
                if let index = index {
                    parentFolder?.mutableChildren.insert(bookmarkMO, at: index)
                } else {
                    parentFolder?.mutableChildren.add(bookmarkMO)
                }
            } else {
                if let index = index {
                    self.rootLevelFolder?.mutableChildren.insert(bookmarkMO, at: index)
                } else {
                    self.rootLevelFolder?.mutableChildren.add(bookmarkMO)
                }
            }

            do {
                try self.context.save()
            } catch {
                assertionFailure("LocalBookmarkStore: Saving of context failed")
                DispatchQueue.main.async { completion(true, error) }
                return
            }

            DispatchQueue.main.async { completion(true, nil) }
        }
    }

    func remove(objectsWithUUIDs identifiers: [UUID], completion: @escaping (Bool, Error?) -> Void) {
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
                self.context.delete(object)
            }

            do {
                try self.context.save()
            } catch {
                assertionFailure("LocalBookmarkStore: Saving of context failed")
                DispatchQueue.main.async { completion(true, error) }
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
                assertionFailure("LocalBookmarkStore: Failed to get BookmarkManagedObject from the context")
                return
            }

            bookmarkMO.update(with: bookmark, favoritesFolder: self.favoritesFolder)

            do {
                try self.context.save()
            } catch {
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
                assertionFailure("LocalBookmarkStore: Failed to get BookmarkManagedObject from the context")
                return
            }

            bookmarkFolderMO.update(with: folder)

            do {
                try self.context.save()
            } catch {
                assertionFailure("LocalBookmarkStore: Saving of context failed")
            }
        }
    }

    func add(objectsWithUUIDs uuids: [UUID], to parent: BookmarkFolder?, completion: @escaping (Error?) -> Void) {
        context.perform { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }

            let bookmarksFetchRequest = BaseBookmarkEntity.entities(with: uuids)
            let bookmarksResults = try? self.context.fetch(bookmarksFetchRequest)

            guard let bookmarkManagedObjects = bookmarksResults else {
                assertionFailure("\(#file): Failed to get BookmarkManagedObject from the context")
                completion(nil)
                return
            }

            if let parentUUID = parent?.id {
                let parentFetchRequest = BaseBookmarkEntity.singleEntity(with: parentUUID)
                let parentFetchRequestResults = try? self.context.fetch(parentFetchRequest)

                guard let parentManagedObject = parentFetchRequestResults?.first, parentManagedObject.isFolder else {
                    assertionFailure("\(#file): Failed to get BookmarkManagedObject from the context")
                    completion(nil)
                    return
                }

                parentManagedObject.addToChildren(NSOrderedSet(array: bookmarkManagedObjects))
            } else {
                for bookmarkManagedObject in bookmarkManagedObjects {
                    bookmarkManagedObject.parentFolder = self.rootLevelFolder
                }
            }

            do {
                try self.context.save()
            } catch {
                assertionFailure("\(#file): Saving of context failed: \(error)")
                DispatchQueue.main.async { completion(error) }
                return
            }

            DispatchQueue.main.async { completion(nil) }
        }
    }

    func update(objectsWithUUIDs uuids: [UUID], update: @escaping (BaseBookmarkEntity) -> Void, completion: @escaping (Error?) -> Void) {
        context.perform { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }

            let bookmarksFetchRequest = BaseBookmarkEntity.entities(with: uuids)
            let bookmarksResults = try? self.context.fetch(bookmarksFetchRequest)

            guard let bookmarkManagedObjects = bookmarksResults else {
                assertionFailure("\(#file): Failed to get BookmarkManagedObject from the context")
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
                try self.context.save()
            } catch {
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

            let managedObject = NSEntityDescription.insertNewObject(forEntityName: BookmarkManagedObject.className(), into: self.context)

            guard let bookmarkMO = managedObject as? BookmarkManagedObject else {
                assertionFailure("LocalBookmarkStore: Failed to init BookmarkManagedObject")
                DispatchQueue.main.async { completion(false, BookmarkStoreError.insertFailed) }
                return
            }

            bookmarkMO.id = folder.id
            bookmarkMO.titleEncrypted = folder.title as NSString
            bookmarkMO.isFolder = true
            bookmarkMO.dateAdded = NSDate.now

            if let parent = parent {
                let parentFetchRequest = BaseBookmarkEntity.singleEntity(with: parent.id)
                let parentFetchRequestResults = try? self.context.fetch(parentFetchRequest)
                bookmarkMO.parentFolder = parentFetchRequestResults?.first
            } else {
                bookmarkMO.parentFolder = self.rootLevelFolder
            }

            do {
                try self.context.save()
            } catch {
                // Only throw this assertion when running in debug and when unit tests are not running.
                if !AppDelegate.isRunningTests {
                    assertionFailure("LocalBookmarkStore: Saving of context failed")
                }

                DispatchQueue.main.async { completion(true, error) }
                return
            }

            DispatchQueue.main.async { completion(true, nil) }
        }
    }
    
    func canMoveObjectWithUUID(objectUUID uuid: UUID, to parent: BookmarkFolder) -> Bool {
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
            
            guard let folderToMove = folderToMoveFetchRequestResults?.first as? BookmarkManagedObject,
                  let parentFolder = parentFolderFetchRequestResults?.first as? BookmarkManagedObject,
                  folderToMove.isFolder,
                  parentFolder.isFolder else {
                return
            }
            
            var currentParentFolder: BookmarkManagedObject? = parentFolder.parentFolder
            
            // Check each parent and verify that the folder being moved isn't being given itself as an ancestor
            while let currentParent = currentParentFolder {
                if currentParent.id == uuid {
                    canMoveObject = false
                    return
                }

                currentParentFolder = currentParent.parentFolder
            }
        }

        return canMoveObject
    }
    
    func move(objectUUIDs: [UUID], toIndex index: Int?, withinParentFolder type: ParentFolderType, completion: @escaping (Error?) -> Void) {
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
            let bookmarkManagedObjects: [BookmarkManagedObject] = objectUUIDs.compactMap { uuid in
                let entityFetchRequest = BaseBookmarkEntity.singleEntity(with: uuid)
                return (try? self.context.fetch(entityFetchRequest))?.first
            }
            
            let newParentFolder: BookmarkManagedObject
            
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
            
            if let index = index, index < newParentFolder.mutableChildren.count {
                self.move(entities: bookmarkManagedObjects, to: index, within: newParentFolder)
            } else {
                for bookmarkManagedObject in bookmarkManagedObjects {
                    bookmarkManagedObject.parentFolder = nil
                }

                newParentFolder.mutableChildren.addObjects(from: bookmarkManagedObjects)
            }

            do {
                try self.context.save()
            } catch {
                assertionFailure("\(#file): Saving of context failed")
                DispatchQueue.main.async { completion(error) }
                return
            }

            DispatchQueue.main.async { completion(nil) }
        }
    }
    
    private func move(entities bookmarkManagedObjects: [BookmarkManagedObject], to index: Int, within newParentFolder: BookmarkManagedObject) {
        var currentInsertionIndex = max(index, 0)
        
        for bookmarkManagedObject in bookmarkManagedObjects {
            let movingObjectWithinSameFolder = bookmarkManagedObject.parentFolder?.id == newParentFolder.id
            
            var adjustedInsertionIndex = currentInsertionIndex
            
            if movingObjectWithinSameFolder, currentInsertionIndex > newParentFolder.mutableChildren.index(of: bookmarkManagedObject) {
                adjustedInsertionIndex -= 1
            }
            
            bookmarkManagedObject.parentFolder = nil
            
            // Removing the bookmark from its current parent may have removed it from the collection it is about to be added to, so re-check
            // the bounds before adding it back.
            if adjustedInsertionIndex < newParentFolder.mutableChildren.count {
                newParentFolder.mutableChildren.insert(bookmarkManagedObject, at: adjustedInsertionIndex)
            } else {
                newParentFolder.mutableChildren.add(bookmarkManagedObject)
            }

            currentInsertionIndex += 1
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

                try self.context.save()
                let bookmarkCountAfterImport = try context.count(for: Bookmark.bookmarksFetchRequest())

                total.successful = bookmarkCountAfterImport - bookmarkCountBeforeImport
            } catch {
                os_log("Failed to import bookmarks, with error: %s", log: .dataImportExport, type: .error, error.localizedDescription)

                // Only throw this assertion when running in debug and when unit tests are not running.
                if !AppDelegate.isRunningTests {
                    assertionFailure("LocalBookmarkStore: Saving of context failed, error: \(error.localizedDescription)")
                }
            }
        }

        return total
    }

    private func createEntitiesFromDDGWebKitBookmarks(allFolders: [BookmarkManagedObject], bookmarks: ImportedBookmarks) -> BookmarkImportResult {

        var total = BookmarkImportResult(successful: 0, duplicates: 0, failed: 0)

        if let otherBookmarks = bookmarks.topLevelFolders.otherBookmarks.children {
            let result = recursivelyCreateEntities(from: otherBookmarks,
                                                   parent: nil,
                                                   in: self.context)

            total += result
        }

        return total

    }

    private func createEntitiesFromBookmarks(allFolders: [BookmarkManagedObject],
                                             bookmarks: ImportedBookmarks,
                                             importSourceName: String) -> BookmarkImportResult {
        
        var total = BookmarkImportResult(successful: 0, duplicates: 0, failed: 0)
        var parent: BookmarkManagedObject?

        if rootLevelFolder?.children?.count != 0 {
            parent = createFolder(titled: "Imported from \(importSourceName)", in: self.context)
        }

        if let bookmarksBar = bookmarks.topLevelFolders.bookmarkBar.children {
            let result = recursivelyCreateEntities(from: bookmarksBar,
                                                   parent: parent,
                                                   markBookmarksAsFavorite: (parent == nil),
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

    private func createFolder(titled title: String, in context: NSManagedObjectContext) -> BookmarkManagedObject {
        let folder = BookmarkManagedObject(context: self.context)
        folder.id = UUID()
        folder.parentFolder = self.rootLevelFolder
        folder.titleEncrypted = title as NSString
        folder.isFolder = true
        folder.dateAdded = NSDate.now

        return folder
    }

    private func recursivelyCreateEntities(from bookmarks: [ImportedBookmarks.BookmarkOrFolder],
                                           parent: BookmarkManagedObject?,
                                           markBookmarksAsFavorite: Bool? = false,
                                           in context: NSManagedObjectContext) -> BookmarkImportResult {
        var total = BookmarkImportResult(successful: 0, duplicates: 0, failed: 0)

        for bookmarkOrFolder in bookmarks {
            if bookmarkOrFolder.isInvalidBookmark {
                // Skip importing bookmarks that don't have a valid URL
                total.failed += 1
                continue
            }

            let bookmarkManagedObject = BookmarkManagedObject(context: context)

            bookmarkManagedObject.id = UUID()
            bookmarkManagedObject.titleEncrypted = bookmarkOrFolder.name as NSString
            bookmarkManagedObject.isFolder = bookmarkOrFolder.isFolder
            bookmarkManagedObject.urlEncrypted = bookmarkOrFolder.url as NSURL?
            bookmarkManagedObject.dateAdded = NSDate.now
            bookmarkManagedObject.parentFolder = parent ?? self.rootLevelFolder
            
            // Bookmarks from the bookmarks bar are imported as favorites
            if bookmarkOrFolder.isDDGFavorite || (!bookmarkOrFolder.isFolder && markBookmarksAsFavorite == true) {
                bookmarkManagedObject.favoritesFolder = favoritesFolder
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
                let children = folderChildren.compactMap { $0 as? BookmarkManagedObject }
                let containsBookmark = children.contains(where: { !$0.isFolder })
                let containsPopulatedFolder = children.contains(where: { ($0.children?.count ?? 0) > 0 })

                if !containsBookmark && !containsPopulatedFolder {
                    context.delete(bookmarkManagedObject)
                }
            }
        }

        return total
    }
    
    // MARK: - Migration
    
    /// There is a rare issue where bookmark managed objects can end up in the database with an invalid state, that is that they are missing their title value despite being non-optional.
    /// They appear to be disjoint from a user's actual bookmarks data, so this function removes them.
    private func removeInvalidBookmarkEntities() {
        context.performAndWait {
            let entitiesFetchRequest = Bookmark.bookmarksAndFoldersFetchRequest()
            
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
                
                try self.context.save()
            } catch {
                os_log("Failed to remove invalid bookmark entities", type: .error)
            }
        }
    }

    /// Fetch and cache favorites folder, or create it if it does not exist
    private func createAndCacheFavoritesFolderIfNeeded() {
        context.performAndWait {
            let fetchRequest = NSFetchRequest<BookmarkManagedObject>(entityName: BookmarkManagedObject.className())
            fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K == nil AND %K == YES",
                                                 "id",
                                                 Constants.favoritesFolderUUID,
                                                 #keyPath(BookmarkManagedObject.parentFolder),
                                                 #keyPath(BookmarkManagedObject.isFolder))
            do {
                if let favoritesFolder = try context.fetch(fetchRequest).first {
                    self.favoritesFolder = favoritesFolder
                    return
                }

                let managedObject = NSEntityDescription.insertNewObject(forEntityName: BookmarkManagedObject.className(), into: self.context)

                guard let favoritesFolder = managedObject as? BookmarkManagedObject else {
                    assertionFailure("LocalBookmarkStore: Failed to migrate top level entities")
                    return
                }

                favoritesFolder.id = .favoritesFolderUUID
                favoritesFolder.titleEncrypted = "Favorites Folder" as NSString
                favoritesFolder.isFolder = true
                favoritesFolder.dateAdded = NSDate.now
                favoritesFolder.parentFolder = nil

                self.favoritesFolder = favoritesFolder

                try context.save()
            } catch {
                Pixel.fire(.debug(event: .bookmarksStoreFavoritesFolderCreationFailed, error: error))
            }
        }
    }

    private func migrateTopLevelStorageToRootLevelBookmarksFolder() {
        context.performAndWait {
            // 1. Fetch all top-level entities and check that there isn't an existing root folder
            // 2. If the root folder does not exist, create it
            // 3. Add all other top-level entities as children of the root folder
            
            let rootFolderFetchRequest = Bookmark.singleEntity(with: .rootBookmarkFolderUUID)
            
            let topLevelEntitiesFetchRequest = Bookmark.topLevelEntitiesFetchRequest()
            topLevelEntitiesFetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BookmarkManagedObject.dateAdded), ascending: true)]
            topLevelEntitiesFetchRequest.returnsObjectsAsFaults = true
            
            do {
                // 0. Up front, check if a root folder exists but has been moved deeper into the hierarchy, and remove it if so:
                
                if let existingRootFolder = try self.context.fetch(rootFolderFetchRequest).first,
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
                
                var existingTopLevelEntities = try self.context.fetch(topLevelEntitiesFetchRequest)
                
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
                    let managedObject = NSEntityDescription.insertNewObject(forEntityName: BookmarkManagedObject.className(), into: self.context)

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
    }
    
    func resetBookmarks() {
        context.performAndWait {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: BookmarkManagedObject.className())
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
    
    func move(objectUUIDs: [UUID], toIndex index: Int?, withinParentFolder parent: ParentFolderType) async -> Error? {
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

}

fileprivate extension BookmarkManagedObject {

    func update(with baseEntity: BaseBookmarkEntity, favoritesFolder: BookmarkManagedObject?) {
        if let bookmark = baseEntity as? Bookmark {
            update(with: bookmark, favoritesFolder: favoritesFolder)
        } else if let folder = baseEntity as? BookmarkFolder {
            update(with: folder)
        } else {
            assertionFailure("\(#file): Failed to cast base entity to Bookmark or BookmarkFolder")
        }
    }

    func update(with bookmark: Bookmark, favoritesFolder: BookmarkManagedObject?) {
        id = bookmark.id
        urlEncrypted = bookmark.url as NSURL?
        titleEncrypted = bookmark.title as NSString
        self.favoritesFolder = bookmark.isFavorite ? favoritesFolder : nil
        isFolder = false
    }

    func update(with folder: BookmarkFolder) {
        id = folder.id
        titleEncrypted = folder.title as NSString
        favoritesFolder = nil
        isFolder = true
    }

}

extension UUID {
    
    static var rootBookmarkFolderUUID: UUID {
        return UUID(uuidString: LocalBookmarkStore.Constants.rootFolderUUID)!
    }

    static var favoritesFolderUUID: UUID {
        return UUID(uuidString: LocalBookmarkStore.Constants.favoritesFolderUUID)!
    }
    
}

fileprivate extension BookmarkManagedObject {
    
    var isInvalid: Bool {
        if titleEncrypted == nil {
            return true
        }
        
        return false
    }

}
