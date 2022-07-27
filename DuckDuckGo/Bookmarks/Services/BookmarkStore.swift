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
    func save(bookmark: Bookmark, parent: BookmarkFolder?, completion: @escaping (Bool, Error?) -> Void)
    func save(folder: BookmarkFolder, parent: BookmarkFolder?, completion: @escaping (Bool, Error?) -> Void)
    func remove(objectsWithUUIDs: [UUID], completion: @escaping (Bool, Error?) -> Void)
    func update(bookmark: Bookmark)
    func update(folder: BookmarkFolder)
    func add(objectsWithUUIDs: [UUID], to parent: BookmarkFolder?, completion: @escaping (Error?) -> Void)
    func update(objectsWithUUIDs uuids: [UUID], update: @escaping (BaseBookmarkEntity) -> Void, completion: @escaping (Error?) -> Void)
    func importBookmarks(_ bookmarks: ImportedBookmarks, source: BookmarkImportSource) -> BookmarkImportResult

}

final class LocalBookmarkStore: BookmarkStore {

    init() {}

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    enum BookmarkStoreError: Error {
        case storeDeallocated
        case insertFailed
        case noObjectId
        case badObjectId
        case asyncFetchFailed
    }

    private lazy var context = Database.shared.makeContext(concurrencyType: .privateQueueConcurrencyType, name: "Bookmark")

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

            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BookmarkManagedObject.dateAdded), ascending: true)]
            fetchRequest.returnsObjectsAsFaults = false

            do {
                let results = try self.context.fetch(fetchRequest)
                let entities = results.compactMap { BaseBookmarkEntity.from(managedObject: $0) }

                mainQueueCompletion(bookmarks: entities, error: nil)
            } catch let error {
                completion(nil, error)
            }
        }
    }

    func save(bookmark: Bookmark, parent: BookmarkFolder?, completion: @escaping (Bool, Error?) -> Void) {
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
            bookmarkMO.isFavorite = bookmark.isFavorite
            bookmarkMO.isFolder = bookmark.isFolder
            bookmarkMO.dateAdded = NSDate.now

            if let parent = parent {
                let parentFetchRequest = BaseBookmarkEntity.singleEntity(with: parent.id)
                let parentFetchRequestResults = try? self.context.fetch(parentFetchRequest)

                bookmarkMO.parentFolder = parentFetchRequestResults?.first
            }

            do {
                try self.context.save()
            } catch {
                assertionFailure("LocalBookmarkStore: Saving of context failed")
                DispatchQueue.main.async { completion(false, error) }
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
                assertionFailure("LocalBookmarkStore: Failed to get BookmarkManagedObject from the context")
                return
            }

            bookmarkMO.update(with: bookmark)

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
                    bookmarkManagedObject.parentFolder = nil
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
                if let entity = BaseBookmarkEntity.from(managedObject: managedObject) {
                    update(entity)
                    managedObject.update(with: entity)
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
            }

            do {
                try self.context.save()
            } catch {
                // Only throw this assertion when running in debug and when unit tests are not running.
                if !AppDelegate.isRunningTests {
                    assertionFailure("LocalBookmarkStore: Saving of context failed")
                }

                DispatchQueue.main.async { completion(false, error) }
                return
            }

            DispatchQueue.main.async { completion(true, nil) }
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
                var bookmarkURLs = Set<URL>()
                let allBookmarks = try context.fetch(Bookmark.bookmarksFetchRequest())

                for bookmark in allBookmarks {
                    guard let bookmarkURL = bookmark.urlEncrypted as? URL else { continue }
                    bookmarkURLs.insert(bookmarkURL)
                }

                let bookmarkCountBeforeImport = try context.count(for: Bookmark.bookmarksFetchRequest())
                let allFolders = try context.fetch(BookmarkFolder.bookmarkFoldersFetchRequest())
                
                switch source {
                case .duckduckgoWebKit:
                    total += createEntitiesFromDDGWebKitBookmarks(allFolders: allFolders, bookmarks: bookmarks, bookmarkURLs: bookmarkURLs)
                case .safari:
                    total += createEntitiesFromSafariBookmarks(allFolders: allFolders, bookmarks: bookmarks, bookmarkURLs: bookmarkURLs)
                case .chromium, .firefox:
                    total += createEntitiesFromChromiumAndFirefoxBookmarks(allFolders: allFolders, bookmarks: bookmarks, bookmarkURLs: bookmarkURLs)
                }

                try self.context.save()
                let bookmarkCountAfterImport = try context.count(for: Bookmark.bookmarksFetchRequest())

                total.successful = bookmarkCountAfterImport - bookmarkCountBeforeImport
            } catch {
                os_log("Failed to import bookmarks, with error: %s", log: .dataImportExport, type: .error, error.localizedDescription)

                // Only throw this assertion when running in debug and when unit tests are not running.
                if !AppDelegate.isRunningTests {
                    assertionFailure("LocalBookmarkStore: Saving of context failed")
                }
            }
        }

        return total
    }

    private func createEntitiesFromDDGWebKitBookmarks(allFolders: [BookmarkManagedObject],
                                                      bookmarks: ImportedBookmarks,
                                                      bookmarkURLs: Set<URL>) -> BookmarkImportResult {

        var total = BookmarkImportResult(successful: 0, duplicates: 0, failed: 0)

        if let otherBookmarks = bookmarks.topLevelFolders.otherBookmarks.children {
            let result = recursivelyCreateEntities(from: otherBookmarks,
                                                   parent: nil,
                                                   existingBookmarkURLs: bookmarkURLs,
                                                   in: self.context)

            total += result
        }

        return total

    }

    private func createEntitiesFromSafariBookmarks(allFolders: [BookmarkManagedObject],
                                                   bookmarks: ImportedBookmarks,
                                                   bookmarkURLs: Set<URL>) -> BookmarkImportResult {
        
        var total = BookmarkImportResult(successful: 0, duplicates: 0, failed: 0)
        
        let existingFolder = allFolders.first { ($0.titleEncrypted as? String) == UserText.bookmarkImportImportedFavorites }
        let parent = existingFolder ?? createFolder(titled: UserText.bookmarkImportImportedFavorites, in: self.context)
        
        if let bookmarksBar = bookmarks.topLevelFolders.bookmarkBar.children {
            let result = recursivelyCreateEntities(from: bookmarksBar,
                                                   parent: parent,
                                                   existingBookmarkURLs: bookmarkURLs,
                                                   markBookmarksAsFavorite: true,
                                                   in: self.context)

            total += result
        }

        if let otherBookmarks = bookmarks.topLevelFolders.otherBookmarks.children {
            let result = recursivelyCreateEntities(from: otherBookmarks,
                                                   parent: nil,
                                                   existingBookmarkURLs: bookmarkURLs,
                                                   markBookmarksAsFavorite: false,
                                                   in: self.context)
            
            total += result
        }
        
        return total
        
    }
    
    private func createEntitiesFromChromiumAndFirefoxBookmarks(allFolders: [BookmarkManagedObject],
                                                               bookmarks: ImportedBookmarks,
                                                               bookmarkURLs: Set<URL>) -> BookmarkImportResult {
        
        var total = BookmarkImportResult(successful: 0, duplicates: 0, failed: 0)
        
        if let bookmarksBar = bookmarks.topLevelFolders.bookmarkBar.children {
            let result = recursivelyCreateEntities(from: bookmarksBar,
                                                   parent: nil,
                                                   existingBookmarkURLs: bookmarkURLs,
                                                   markBookmarksAsFavorite: true,
                                                   in: self.context)

            total += result
        }
        
        let existingFolder = allFolders.first { ($0.titleEncrypted as? String) == UserText.bookmarkImportOtherBookmarks }
        let parent = existingFolder ?? createFolder(titled: UserText.bookmarkImportOtherBookmarks, in: self.context)

        if let otherBookmarks = bookmarks.topLevelFolders.otherBookmarks.children {
            let result = recursivelyCreateEntities(from: otherBookmarks,
                                                   parent: parent,
                                                   existingBookmarkURLs: bookmarkURLs,
                                                   markBookmarksAsFavorite: false,
                                                   in: self.context)
            
            total += result
        }
        
        return total
        
    }

    private func createFolder(titled title: String, in context: NSManagedObjectContext) -> BookmarkManagedObject {
        let folder = BookmarkManagedObject(context: self.context)
        folder.id = UUID()
        folder.titleEncrypted = title as NSString
        folder.isFolder = true
        folder.dateAdded = NSDate.now

        return folder
    }

    private func recursivelyCreateEntities(from bookmarks: [ImportedBookmarks.BookmarkOrFolder],
                                           parent: BookmarkManagedObject?,
                                           existingBookmarkURLs: Set<URL>,
                                           markBookmarksAsFavorite: Bool? = false,
                                           in context: NSManagedObjectContext) -> BookmarkImportResult {
        var total = BookmarkImportResult(successful: 0, duplicates: 0, failed: 0)

        for bookmarkOrFolder in bookmarks {
            if let bookmarkURL = bookmarkOrFolder.url, existingBookmarkURLs.contains(bookmarkURL) {
                // Avoid creating bookmarks that already exist in the database.
                total.duplicates += 1
                continue
            }

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
            bookmarkManagedObject.parentFolder = parent
            
            // Bookmarks from the bookmarks bar are imported as favorites
            bookmarkManagedObject.isFavorite = bookmarkOrFolder.isDDGFavorite || (!bookmarkOrFolder.isFolder && markBookmarksAsFavorite == true)

            if let children = bookmarkOrFolder.children {
                let result = recursivelyCreateEntities(from: children,
                                                       parent: bookmarkManagedObject,
                                                       existingBookmarkURLs: existingBookmarkURLs,
                                                       markBookmarksAsFavorite: markBookmarksAsFavorite,
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

}

fileprivate extension BookmarkManagedObject {

    func update(with baseEntity: BaseBookmarkEntity) {
        if let bookmark = baseEntity as? Bookmark {
            update(with: bookmark)
        } else if let folder = baseEntity as? BookmarkFolder {
            update(with: folder)
        } else {
            assertionFailure("\(#file): Failed to cast base entity to Bookmark or BookmarkFolder")
        }
    }

    func update(with bookmark: Bookmark) {
        id = bookmark.id
        urlEncrypted = bookmark.url as NSURL?
        titleEncrypted = bookmark.title as NSString
        isFavorite = bookmark.isFavorite
        isFolder = false
    }

    func update(with folder: BookmarkFolder) {
        id = folder.id
        titleEncrypted = folder.title as NSString
        isFavorite = false
        isFolder = true
    }

}
