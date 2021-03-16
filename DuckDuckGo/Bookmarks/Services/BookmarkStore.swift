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

protocol BookmarkStore {

    func loadAll(completion: @escaping ([Bookmark]?, Error?) -> Void)
    func save(bookmark: Bookmark, completion: @escaping (Bool, NSManagedObjectID?, Error?) -> Void)
    func remove(bookmark: Bookmark, completion: @escaping (Bool, Error?) -> Void)
    func update(bookmark: Bookmark)

}

class LocalBookmarkStore: BookmarkStore {

    init() {}

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    enum BookmarkStoreError: Error {
        case storeDeallocated
        case insertFailed
        case noObjectId
        case badObjectId
    }

    private lazy var context = Database.shared.makeContext(concurrencyType: .privateQueueConcurrencyType, name: "Bookmark")

    func loadAll(completion: @escaping ([Bookmark]?, Error?) -> Void) {
        func mainQeueCompletion(bookmarks: [Bookmark]?, error: Error?) {
            DispatchQueue.main.async {
                completion(bookmarks, error)
            }
        }

        let fetchRequest = BookmarkManagedObject.fetchRequest() as NSFetchRequest<BookmarkManagedObject>
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(BookmarkManagedObject.dateAdded), ascending: false)]
        fetchRequest.returnsObjectsAsFaults = false
        let asyncRequest = NSAsynchronousFetchRequest(fetchRequest: fetchRequest) { result in
            guard let bookmarkManagedObjects = result.finalResult else {
                assertionFailure("LocalBookmarkStore: Async fetch failed")
                mainQeueCompletion(bookmarks: nil, error: result.operationError)
                return
            }

            let bookmarks = bookmarkManagedObjects.compactMap { Bookmark(bookmarkMO: $0) }
            mainQeueCompletion(bookmarks: bookmarks, error: nil)
        }

        do {
          try context.execute(asyncRequest)
        } catch let error {
          completion(nil, error)
        }
    }

    func save(bookmark: Bookmark, completion: @escaping (Bool, NSManagedObjectID?, Error?) -> Void) {
        context.perform { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false, nil, BookmarkStoreError.storeDeallocated) }
                return
            }

            let managedObject = NSEntityDescription.insertNewObject(forEntityName: BookmarkManagedObject.className(), into: self.context)
            guard let bookmarkMO = managedObject as? BookmarkManagedObject else {
                assertionFailure("LocalBookmarkStore: Failed to init BookmarkManagedObject")
                DispatchQueue.main.async { completion(false, nil, BookmarkStoreError.insertFailed) }
                return
            }

            bookmarkMO.urlEncrypted = bookmark.url as NSURL
            bookmarkMO.titleEncrypted = bookmark.title as NSString
            bookmarkMO.faviconEncrypted = bookmark.favicon
            bookmarkMO.isFavorite = bookmark.isFavorite
            bookmarkMO.dateAdded = NSDate.now

            do {
                try self.context.save()
            } catch {
                assertionFailure("LocalBookmarkStore: Saving of context failed")
                DispatchQueue.main.async { completion(false, nil, error) }
            }

            DispatchQueue.main.async { completion(true, managedObject.objectID, nil) }
        }
    }

    func remove(bookmark: Bookmark, completion: @escaping (Bool, Error?) -> Void) {
        guard let objectId = bookmark.managedObjectId else {
            completion(false, BookmarkStoreError.noObjectId)
            return
        }

        context.perform { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false, BookmarkStoreError.storeDeallocated) }
                return
            }

            guard let bookmarkMO = try? self.context.existingObject(with: objectId) else {
                assertionFailure("LocalBookmarkStore: No existing object with \(objectId)")
                DispatchQueue.main.async { completion(false, BookmarkStoreError.badObjectId) }
                return
            }
            self.context.delete(bookmarkMO)

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
        guard let objectId = bookmark.managedObjectId else {
            return
        }

        context.perform { [weak self] in
            guard let self = self else {
                return
            }

            guard let bookmarkMO = try? self.context.existingObject(with: objectId) as? BookmarkManagedObject else {
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

}

fileprivate extension Bookmark {

    init?(bookmarkMO: BookmarkManagedObject) {
        guard let url = bookmarkMO.urlEncrypted as? URL,
              let title = bookmarkMO.titleEncrypted as? String else {
            assertionFailure("Bookmark: Failed to init Bookmark from BookmarkManagedObject")
            return nil
        }
        let favicon = bookmarkMO.faviconEncrypted as? NSImage
        let isFavorite = bookmarkMO.isFavorite
        let objectId = bookmarkMO.objectID

        self.init(url: url, title: title, favicon: favicon, isFavorite: isFavorite, managedObjectId: objectId)
    }

}

fileprivate extension BookmarkManagedObject {

    func update(with bookmark: Bookmark) {
        guard objectID == bookmark.managedObjectId else {
            assertionFailure("BookmarkManagedObject: Incorrect bookmark struct for the update")
            return
        }

        urlEncrypted = bookmark.url as NSURL
        titleEncrypted = bookmark.title as NSString
        faviconEncrypted = bookmark.favicon
        isFavorite = bookmark.isFavorite
    }

}
