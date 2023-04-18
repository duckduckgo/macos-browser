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

    func changes(since timestamp: String?) async throws -> [Syncable] {
        []
    }

    init(metadataStore: SyncMetadataStore) {
        self.metadataStore = metadataStore
    }

    private let metadataStore: SyncMetadataStore

}
