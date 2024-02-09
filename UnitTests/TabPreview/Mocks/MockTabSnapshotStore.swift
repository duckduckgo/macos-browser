//
//  MockTabSnapshotStore.swift
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

import AppKit
@testable import DuckDuckGo_Privacy_Browser

class MockTabSnapshotStore: TabSnapshotStoring {

    // Use dictionaries to mock storing and loading snapshots by tab ID
    var snapshots = [UUID: NSImage]()

    // Tracks calls to methods for verification in tests
    var persistedSnapshotIDs = [UUID]()
    var clearedSnapshotIDs = [UUID]()
    var loadedSnapshotIDs = [UUID]()

    func persistSnapshot(_ snapshot: NSImage, id: UUID) {
        snapshots[id] = snapshot
        persistedSnapshotIDs.append(id)
    }

    func clearSnapshot(tabID: UUID) {
        snapshots.removeValue(forKey: tabID)
        clearedSnapshotIDs.append(tabID)
    }

    func loadSnapshot(for tabID: UUID) async -> DuckDuckGo_Privacy_Browser.NSImageSendable? {
        let snapshot = snapshots[tabID]
        loadedSnapshotIDs.append(tabID)
        return snapshot as? DuckDuckGo_Privacy_Browser.NSImageSendable
    }

    func loadAllStoredSnapshotIds() async -> [UUID] {
        return loadedSnapshotIDs
    }

}
