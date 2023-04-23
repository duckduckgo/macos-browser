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
        await withCheckedContinuation { continuation in
            var syncableBookmarks: [Syncable] = []
            context.performAndWait {
                let bookmarks = BookmarkUtils.fetchModifiedBookmarks(context)
                syncableBookmarks = bookmarks.map(Syncable.init(bookmark:))
            }
            continuation.resume(with: .success(syncableBookmarks))
        }
    }

    func fetchAllObjects() async throws -> [Syncable] {
        try await fetchChangedObjects()
    }

    func handleSyncResult(sent: [Syncable], received: [Syncable], timestamp: String?) async throws {
    }

    init(database: CoreDataDatabase, metadataStore: SyncMetadataStore) {
        self.context = database.makeContext(concurrencyType: .privateQueueConcurrencyType)
        self.metadataStore = metadataStore
    }

    private let context: NSManagedObjectContext
    private let metadataStore: SyncMetadataStore
}

extension Syncable {
    init(bookmark: BookmarkEntity) {
        var payload: [String: Any] = [:]
        self.init(jsonObject: payload)
    }
}
