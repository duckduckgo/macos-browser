//
//  TabSnapshotCleanupService.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

final class TabSnapshotCleanupService {

    private let fileStore: FileStore
    private let store: TabSnapshotStore

    init(fileStore: FileStore) {
        self.fileStore = fileStore
        self.store = TabSnapshotStore(fileStore: fileStore)
    }

    func cleanStoredSnapshots(except ids: Set<UUID>) async {
        let tabSnapshotStore = TabSnapshotStore(fileStore: fileStore)

        // Get all snapshot UUIDs stored in the snapshot directory
        let storedSnapshotIds = Set(await tabSnapshotStore.loadAllStoredSnapshotIds())

        // Cleanup
        let snapshotsToRemove = storedSnapshotIds.subtracting(ids)
        snapshotsToRemove.forEach {
            store.clearSnapshot(tabID: $0)
        }
    }

}
