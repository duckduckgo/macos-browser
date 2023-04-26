//
//  SyncDataPersistor.swift
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
import Bookmarks
import CoreData
import Persistence
import DDGSync

final class SyncBookmarksProvider: DataProviding {
    let feature: Feature = .init(name: "bookmarks")

    var lastSyncTimestamp: String? {
        get {
            metadataStore.timestamp(forFeatureNamed: feature.name)
        }
        set {
            metadataStore.updateTimestamp(newValue, forFeatureNamed: feature.name)
        }
    }

    func prepareForFirstSync() {
        lastSyncTimestamp = nil
    }

    func fetchChangedObjects() async throws -> [Syncable] {
        // swiftlint:disable:next force_cast
        let crypter = await (NSApp.delegate as! AppDelegate).syncService.crypter

        return await withCheckedContinuation { continuation in

            let context = database.makeContext(concurrencyType: .privateQueueConcurrencyType)

            var syncableBookmarks: [Syncable] = []
            context.performAndWait {
                let bookmarks = BookmarkUtils.fetchModifiedBookmarks(context)
                syncableBookmarks = bookmarks.compactMap { try? Syncable(bookmark: $0, encryptedWith: crypter) }
            }
            continuation.resume(with: .success(syncableBookmarks))
        }
    }

    func fetchAllObjects() async throws -> [Syncable] {
        // swiftlint:disable:next force_cast
        let crypter = await (NSApp.delegate as! AppDelegate).syncService.crypter

        return await withCheckedContinuation { continuation in
            var syncableBookmarks: [Syncable] = []

            let context = database.makeContext(concurrencyType: .privateQueueConcurrencyType)

            context.performAndWait {
                let fetchRequest = BookmarkEntity.fetchRequest()
                let bookmarks = (try? context.fetch(fetchRequest)) ?? []
                syncableBookmarks = bookmarks.compactMap { try? Syncable(bookmark: $0, encryptedWith: crypter) }
            }
            continuation.resume(with: .success(syncableBookmarks))
        }
    }

    func handleSyncResult(sent: [Syncable], received: [Syncable], timestamp: String?) async {
        // swiftlint:disable:next force_cast
        let crypter = await (NSApp.delegate as! AppDelegate).syncService.crypter

        await withCheckedContinuation { continuation in
            var saveError: Error?

            let context = database.makeContext(concurrencyType: .privateQueueConcurrencyType)

            context.performAndWait {
                // clean up sent items

                let identifiers = sent.compactMap { $0.payload["id"] as? String }
                let request = BookmarkEntity.fetchRequest()
                request.predicate = NSPredicate(format: "%K IN %@", #keyPath(BookmarkEntity.uuid), identifiers)
                let bookmarks = (try? context.fetch(request)) ?? []
                bookmarks.forEach { $0.modifiedAt = nil }

                let bookmarksPendingDeletion = BookmarkUtils.fetchBookmarksPendingDeletion(context)

                for bookmark in bookmarksPendingDeletion {
                    context.delete(bookmark)
                }

                processReceivedBookmarks(received, in: context, using: crypter)
                let insertedObjects = Array(context.insertedObjects).compactMap { $0 as? BookmarkEntity }
                let updatedObjects = Array(context.updatedObjects.subtracting(context.deletedObjects)).compactMap { $0 as? BookmarkEntity }

                do {
                    try context.save()
                    (insertedObjects + updatedObjects).forEach { $0.modifiedAt = nil }
                    try context.save()
                } catch {
                    saveError = error
                }
            }
            if let saveError {
                print("SAVE ERROR", saveError)
            } else if let timestamp {
                lastSyncTimestamp = timestamp
            }

            LocalBookmarkManager.shared.loadBookmarks()
            continuation.resume()
        }
    }

    private func processReceivedBookmarks(_ received: [Syncable], in context: NSManagedObjectContext, using crypter: Crypting) {
        let receivedIDs: Set<String> = received.reduce(into: .init()) { partialResult, syncable in
            if let uuid = syncable.payload["id"] as? String {
                partialResult.insert(uuid)
            }
            if let folder = syncable.payload["folder"] as? [String: Any], let children = folder["children"] as? [String] {
                partialResult.formUnion(children)
            }
        }
        if receivedIDs.isEmpty {
            return
        }
        guard let favoritesFolder = BookmarkUtils.fetchFavoritesFolder(context) else {
            return
        }

        // fetch all local bookmarks referenced in the payload
        let request = BookmarkEntity.fetchRequest()
        request.predicate = NSPredicate(format: "%K IN %@", #keyPath(BookmarkEntity.uuid), receivedIDs)
        request.returnsObjectsAsFaults = false
        request.relationshipKeyPathsForPrefetching = [#keyPath(BookmarkEntity.children), #keyPath(BookmarkEntity.favorites)]

        let bookmarks = (try? context.fetch(request)) ?? []

        // index local bookmarks by UUID
        var existingByUUID: [String: BookmarkEntity] = bookmarks.reduce(into: .init()) { partialResult, bookmark in
            guard let uuid = bookmark.uuid else {
                return
            }
            partialResult[uuid] = bookmark
        }

        // update existing local bookmarks data and store them in processedUUIDs
        let processedUUIDs: [String] = bookmarks.reduce(into: .init()) { partialResult, bookmark in
            guard let syncable = received.first(where: { $0.payload["id"] as? String == bookmark.uuid }) else {
                return
            }
            try? bookmark.update(with: syncable, in: context, using: crypter, existing: &existingByUUID)
            if let uuid = bookmark.uuid {
                partialResult.append(uuid)
            }
        }

        // extract received favorites UUIDs
        let favoritesUUIDs: [String] = {
            guard let favoritesFolder = received.first(where: { $0.payload["id"] as? String == BookmarkEntity.Constants.favoritesFolderID }),
                  let folderData = favoritesFolder.payload["folder"] as? [String: Any],
                  let children = folderData["children"] as? [String]
            else {
                return []
            }
            return children
        }()

        var newBookmarks = [String: BookmarkEntity]()

        // go through all received items and create new bookmarks as needed
        // filter out deleted objects from received items (they are already gone locally)
        let validReceivedItems: [Syncable] = received.filter { syncable in
            guard let uuid = syncable.payload["id"] as? String, syncable.payload["deleted"] == nil else {
                return false
            }
            if processedUUIDs.contains(uuid) {
                return true
            }

            let bookmark = BookmarkEntity(context: context)
            bookmark.uuid = uuid
            bookmark.isFolder = syncable.payload["folder"] != nil
            newBookmarks[uuid] = bookmark
            return true
        }

        // at this point all new bookmarks are created
        // populate favorites
        if !favoritesUUIDs.isEmpty {
            favoritesFolder.favoritesArray.forEach { $0.removeFromFavorites() }
            favoritesUUIDs.forEach { uuid in
                if let newBookmark = newBookmarks[uuid] {
                    newBookmark.addToFavorites(favoritesRoot: favoritesFolder)
                } else if let existingBookmark = existingByUUID[uuid] {
                    existingBookmark.addToFavorites(favoritesRoot: favoritesFolder)
                }
            }
        }

        let bookmarkToFolderMap = received.mapParentFolders()
        let folderToBookmarksMap = received.mapChildren()

        // go through all received items and populate new bookmarks
        for syncable in validReceivedItems {
            guard let uuid = syncable.payload["id"] as? String, let bookmark = newBookmarks[uuid], let parentUUID = bookmarkToFolderMap[uuid] else {
                continue
            }
            bookmark.parent = newBookmarks[parentUUID] ?? existingByUUID[parentUUID]
            try? bookmark.update(with: syncable, in: context, using: crypter, existing: &existingByUUID)
        }

        for folderUUID in bookmarkToFolderMap.values {
            var folder = existingByUUID[folderUUID]
            if let folder = existingByUUID[folderUUID] ?? newBookmarks[folderUUID], let bookmarks = folderToBookmarksMap[folderUUID] {
                folder.childrenArray.forEach { $0.parent = nil }
                for bookmarkUUID in bookmarks {
                    if let bookmark = newBookmarks[bookmarkUUID] ?? existingByUUID[bookmarkUUID] {
                        folder.addToChildren(bookmark)
                    }
                }
            }
        }
    }

    init(database: CoreDataDatabase, metadataStore: SyncMetadataStore) {
        self.database = database
        self.metadataStore = metadataStore
        self.metadataStore.registerFeature(named: feature.name)
    }

    private let database: CoreDataDatabase
    private let metadataStore: SyncMetadataStore
}

extension Syncable {

    init(bookmark: BookmarkEntity, encryptedWith crypter: Crypting) throws {
        var payload: [String: Any] = [:]
        payload["id"] = bookmark.uuid!
        if bookmark.isPendingDeletion {
            payload["deleted"] = ""
        } else {
            if let title = bookmark.title {
                payload["title"] = try crypter.encryptAndBase64Encode(title)
            }
            if bookmark.isFolder {
                if bookmark.uuid == BookmarkEntity.Constants.favoritesFolderID {
                    payload["folder"] = [
                        "children": bookmark.favoritesArray.map(\.uuid)
                    ]
                } else {
                    payload["folder"] = [
                        "children": bookmark.childrenArray.map(\.uuid)
                    ]
                }
            } else if let url = bookmark.url {
                payload["page"] = ["url": try crypter.encryptAndBase64Encode(url)]
            }
            if let modifiedAt = bookmark.modifiedAt {
                payload["client_last_modified"] = Self.dateFormatter.string(from: modifiedAt)
            }
        }
        self.init(jsonObject: payload)
    }

    private static var dateFormatter: ISO8601DateFormatter {
        ISO8601DateFormatter()
    }
}

extension BookmarkEntity {

    func update(with syncable: Syncable, in context: NSManagedObjectContext, using crypter: Crypting, existing: inout [String: BookmarkEntity]) throws {
        let payload = syncable.payload
        guard payload["deleted"] == nil else {
            context.delete(self)
            return
        }

        modifiedAt = nil

        if let encryptedTitle = payload["title"] as? String {
            title = try crypter.base64DecodeAndDecrypt(encryptedTitle)
        }

        if !isFolder {
            if let page = payload["page"] as? [String: Any], let encryptedUrl = page["url"] as? String {
                url = try crypter.base64DecodeAndDecrypt(encryptedUrl)
            }
        }

    }
}

extension Array where Element == Syncable {

    func mapParentFolders() -> [String: String] {
        var folders: [String: String] = [:]

        forEach { syncable in
            if let folderUUID = syncable.payload["id"] as? String,
               folderUUID != BookmarkEntity.Constants.favoritesFolderID,
               let folder = syncable.payload["folder"] as? [String: Any],
               let children = folder["children"] as? [String] {

                children.forEach { child in
                    folders[child] = folderUUID
                }
            }
        }

        return folders
    }

    func mapChildren() -> [String: [String]] {
        var children: [String: [String]] = [:]

        forEach { syncable in
            if let folderUUID = syncable.payload["id"] as? String,
               folderUUID != BookmarkEntity.Constants.favoritesFolderID,
               let folder = syncable.payload["folder"] as? [String: Any],
               let folderChildren = folder["children"] as? [String] {

                children[folderUUID] = folderChildren
            }
        }

        return children
    }
}
