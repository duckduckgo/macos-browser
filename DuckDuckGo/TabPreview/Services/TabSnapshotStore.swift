//
//  TabSnapshotStore.swift
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

import Cocoa
import Common
import os.log

protocol TabSnapshotStoring {

    func persistSnapshot(_ snapshot: NSImage, id: UUID)
    func clearSnapshot(tabID: UUID)
    func loadSnapshot(for tabID: UUID) async -> NSImageSendable?
    func loadAllStoredSnapshotIds() async -> [UUID]

}

final class TabSnapshotStore: TabSnapshotStoring {

    static let directoryName: String = "tabSnapshots"

    private let fileStore: FileStore

    init(fileStore: FileStore) {
        self.fileStore = fileStore
    }

    func persistSnapshot(_ snapshot: NSImage, id: UUID) {
        guard let data = snapshot.tiffRepresentation else {
            Logger.tabSnapshots.error("TabSnapshotPersistenceService: Failed to create tiff representation")
            return
        }

        Task {
            let url = URL.persistenceLocation(for: id)
            createDirectoryIfNeeded()
            guard fileStore.persist(data, url: url) else {
                Logger.tabSnapshots.error("TabSnapshotPersistenceService: Saving of snapshot failed")
                return
            }
        }
    }

    func clearSnapshot(tabID: UUID) {
        Task {
            let url = URL.persistenceLocation(for: tabID)
            fileStore.remove(fileAtURL: url)
        }
    }

    func loadSnapshot(for tabID: UUID) async -> NSImageSendable? {
        let url = URL.persistenceLocation(for: tabID)

        if let data = fileStore.loadData(at: url),
           let image = NSImage(data: data) {
            return image as NSImageSendable
        } else {
            Logger.tabSnapshots.error("TabSnapshotPersistenceService: Loading of snapshot failed")
            return nil
        }
    }

    private func createDirectoryIfNeeded() {
        let directoryURL = URL.persistenceLocation(for: Self.directoryName)

        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            do {
                try FileManager.default.createDirectory(at: directoryURL,
                                                        withIntermediateDirectories: true,
                                                        attributes: nil)
            } catch {
                fatalError("Failed to create directory at \(directoryURL.path)")
            }
        }
    }

    func loadAllStoredSnapshotIds() async -> [UUID] {
        var uuids: [UUID] = []

        let directoryURL = URL.persistenceLocation(for: Self.directoryName)
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                guard let uuid = UUID(uuidString: fileURL.deletingPathExtension().lastPathComponent) else {
                    continue
                }

                uuids.append(uuid)
            }
        } catch {
            Logger.tabSnapshots.error("Failed to load stored snapshot ids: \(error.localizedDescription, privacy: .public)")
        }

        return uuids
    }

}

fileprivate extension URL {

    static func persistenceLocation(for id: UUID) -> URL {
        let fileName = "\(TabSnapshotStore.directoryName)/\(id.uuidString)"
        return URL.persistenceLocation(for: fileName)
    }

}
