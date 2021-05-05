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

enum BookmarkStoreFetchPredicateType {
    case bookmarks
    case topLevelEntities
}

protocol BookmarkStore {

    func loadAll(type: BookmarkStoreFetchPredicateType, completion: @escaping ([BaseBookmarkEntity]?, Error?) -> Void)
    func save(bookmark: Bookmark, parent: Folder?, completion: @escaping (Bool, Error?) -> Void)
    func save(folder: Folder, parent: Folder?, completion: @escaping (Bool, Error?) -> Void)
    func remove(objectsWithUUIDs: [UUID], completion: @escaping (Bool, Error?) -> Void)
    func update(bookmark: Bookmark)
    func add(objectsWithUUIDs: [UUID], to parent: Folder?, completion: @escaping (Error?) -> Void)

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

        let fetchRequest: NSFetchRequest<BookmarkManagedObject>

        switch type {
        case .bookmarks:
            fetchRequest = Bookmark.bookmarksFetchRequest()
        case .topLevelEntities:
            fetchRequest = Bookmark.topLevelEntitiesFetchRequest()
        }

        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BookmarkManagedObject.dateAdded), ascending: false)]
        fetchRequest.returnsObjectsAsFaults = false

        let asyncRequest = NSAsynchronousFetchRequest(fetchRequest: fetchRequest) { result in
            guard let bookmarkManagedObjects = result.finalResult else {
                assertionFailure("LocalBookmarkStore: Async fetch failed")
                mainQueueCompletion(bookmarks: nil, error: result.operationError)
                return
            }

            let entities = bookmarkManagedObjects.compactMap { BaseBookmarkEntity.from(managedObject: $0) }
            mainQueueCompletion(bookmarks: entities, error: nil)
        }

        do {
          try context.execute(asyncRequest)
        } catch let error {
          completion(nil, error)
        }
    }

    func save(bookmark: Bookmark, parent: Folder?, completion: @escaping (Bool, Error?) -> Void) {
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
            bookmarkMO.faviconEncrypted = bookmark.favicon
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

    func add(objectsWithUUIDs uuids: [UUID], to parent: Folder?, completion: @escaping (Error?) -> Void) {
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
                assertionFailure("\(#file): Saving of context failed")
                DispatchQueue.main.async { completion(error) }
                return
            }

            DispatchQueue.main.async { completion(nil) }
        }
    }

    // MARK: - Folders

    func save(folder: Folder, parent: Folder?, completion: @escaping (Bool, Error?) -> Void) {
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

}

fileprivate extension BookmarkManagedObject {

    func update(with bookmark: Bookmark) {
        id = bookmark.id
        urlEncrypted = bookmark.url as NSURL?
        titleEncrypted = bookmark.title as NSString
        faviconEncrypted = bookmark.favicon
        isFavorite = bookmark.isFavorite
        isFolder = bookmark.isFolder
    }

}
