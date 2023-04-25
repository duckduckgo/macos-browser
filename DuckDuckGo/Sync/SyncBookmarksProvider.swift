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
                let updatedObjects = Array(context.updatedObjects).compactMap { $0 as? BookmarkEntity }

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

//            print(received)
//            print(String(reflecting: timestamp))
        }
    }

    private func processReceivedBookmarks(_ received: [Syncable], in context: NSManagedObjectContext, using crypter: Crypting) {
        let receivedIDs = received.compactMap { $0.payload["id"] as? String }
        if receivedIDs.isEmpty {
            return
        }
        guard let favoritesFolder = BookmarkUtils.fetchFavoritesFolder(context) else {
            return
        }

        let request = BookmarkEntity.fetchRequest()
        request.predicate = NSPredicate(format: "%K IN %@", #keyPath(BookmarkEntity.uuid), receivedIDs)
        request.returnsObjectsAsFaults = false
        request.relationshipKeyPathsForPrefetching = [#keyPath(BookmarkEntity.children), #keyPath(BookmarkEntity.favorites)]

        let bookmarks = (try? context.fetch(request)) ?? []

        var existingByUUID = [String: BookmarkEntity]()
        bookmarks.forEach { bookmark in
            guard let uuid = bookmark.uuid else {
                return
            }
            existingByUUID[uuid] = bookmark
        }

        var processedUUIDs = [String]()
        for bookmark in bookmarks {
            if let syncable = received.first(where: { $0.payload["id"] as? String == bookmark.uuid }) {
                try? bookmark.update(with: syncable, in: context, using: crypter, existing: &existingByUUID)
                if let uuid = bookmark.uuid {
                    processedUUIDs.append(uuid)
                }
            }
        }

        var newBookmarks = [String: BookmarkEntity]()

        let childToParentMap = received.mapParentFolders()

        let favoritesUUIDs: Set<String> = {
            guard let favoritesFolder = received.first(where: { $0.payload["id"] as? String == BookmarkEntity.Constants.favoritesFolderID }),
                  let folderData = favoritesFolder.payload["folder"] as? [String: Any],
                  let children = folderData["children"] as? [String]
            else {
                return []
            }
            return Set(children)
        }()

        for syncable in received {
            guard let uuid = syncable.payload["id"] as? String else {
                continue
            }
            if processedUUIDs.contains(uuid) {
                continue
            }

            let bookmark = BookmarkEntity(context: context)
            bookmark.uuid = uuid
            bookmark.isFolder = syncable.payload["folder"] != nil
            if favoritesUUIDs.contains(uuid) {
                bookmark.addToFavorites(favoritesRoot: favoritesFolder)
            }
            newBookmarks[uuid] = bookmark
        }

        for syncable in received {
            guard let uuid = syncable.payload["id"] as? String, let bookmark = newBookmarks[uuid], let parentUUID = childToParentMap[uuid] else {
                continue
            }
            bookmark.parent = newBookmarks[parentUUID] ?? existingByUUID[parentUUID]
            try? bookmark.update(with: syncable, in: context, using: crypter, existing: &existingByUUID)
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
        payload["title"] = try crypter.encryptAndBase64Encode(bookmark.title!)
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
        } else {
            payload["page"] = ["url": try crypter.encryptAndBase64Encode(bookmark.url!)]
        }
        if bookmark.isPendingDeletion {
            payload["deleted"] = ""
        }
        if let modifiedAt = bookmark.modifiedAt {
            payload["client_last_modified"] = Self.dateFormatter.string(from: modifiedAt)
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

        if isFolder, let folder = payload["folder"] as? [String: Any], let children = folder["children"] as? [String] {
            if payload["id"] as? String == BookmarkEntity.Constants.favoritesFolderID {
                for uuid in children {
                    existing[uuid]?.addToFavorites(favoritesRoot: self)
                }
            } else {
                for uuid in children {
                    existing[uuid]?.parent = self
                }
            }
        } else {
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

}
