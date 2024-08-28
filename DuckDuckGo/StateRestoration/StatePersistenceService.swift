//
//  StatePersistenceService.swift
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

final class StatePersistenceService {
    private let fileStore: FileStore
    private let fileName: String
    ///  The `persistentState` file is renamed to `persistentState.1` after it‘s loaded for the first time
    ///  if no new persistentState is written during the session it will be used on the next load and renamed to `persistentState.2`
    private var lastLoadedStateFileName: String {
        fileName + ".1"
    }
    private var oldStateFileName: String {
        fileName + ".2"
    }
    private var lastSessionStateArchive: Data?
    private let queue = DispatchQueue(label: "StateRestorationManager.queue", qos: .background)
    private var job: DispatchWorkItem?

    private(set) var error: Error?

    /// `false` if `persistentState` or `persistentState.1` file exists,
    /// `true` if `persistentState.2` (old app state that was not updated after 2nd app relaunch) file exists
    var isAppStateFileStale: Bool {
        if fileStore.hasData(at: .persistenceLocation(for: fileName)) || fileStore.hasData(at: .persistenceLocation(for: lastLoadedStateFileName)) {
            return false
        } else {
            return true
        }
    }

    init(fileStore: FileStore, fileName: String) {
        self.fileStore = fileStore
        self.fileName = fileName
    }

    var canRestoreLastSessionState: Bool {
        lastSessionStateArchive != nil
    }

    @MainActor
    func persistState(using encoder: @escaping @MainActor (NSCoder) -> Void, sync: Bool = false) {
        dispatchPrecondition(condition: .onQueue(.main))

        let data = archive(using: encoder)
        write(data, sync: sync)
    }

    func clearState(sync: Bool = false) {
        dispatchPrecondition(condition: .onQueue(.main))

        job?.cancel()
        job = DispatchWorkItem {
            self.performClearState()
        }
        queue.dispatch(job!, sync: sync)
    }

    func flush() {
        queue.sync {}
    }

    func loadLastSessionState() {
        lastSessionStateArchive = loadStateFromFile()
    }

    // perform state clearing synchronously, called from `clearState(sync:)` on `StateRestorationManager.queue`
    func performClearState() {
        lastSessionStateArchive = nil
        let location = URL.persistenceLocation(for: self.fileName)
        fileStore.remove(fileAtURL: location)
        fileStore.remove(fileAtURL: .persistenceLocation(for: self.lastLoadedStateFileName))
        fileStore.remove(fileAtURL: .persistenceLocation(for: self.oldStateFileName))
    }

    /// rename `persistentState` to `persistentState.1` after the state was loaded
    /// if the state was loaded from `persistentState.1`, it will be renamed to `persistentState.2`
    /// `persistentState.2` won‘t restore windows automatically to avoid a possible crash loop
    func didLoadState() {
        let location = URL.persistenceLocation(for: self.fileName)
        let location1 = URL.persistenceLocation(for: self.lastLoadedStateFileName)
        let location2 = URL.persistenceLocation(for: self.oldStateFileName)
        if fileStore.hasData(at: location) {
            fileStore.remove(fileAtURL: location1)
            fileStore.remove(fileAtURL: location2)
            fileStore.move(fileAt: location, to: location1)
        } else if fileStore.hasData(at: location1) {
            fileStore.remove(fileAtURL: location2)
            fileStore.move(fileAt: location1, to: location2)
        }
    }

    @MainActor
    func restoreState(using restore: @escaping @MainActor (NSCoder) throws -> Void) throws {
        guard let encryptedData = lastSessionStateArchive ?? loadStateFromFile() else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        try restoreState(from: encryptedData, using: restore)
    }

    // MARK: - Private

    @MainActor
    private func archive(using encoder: @escaping @MainActor (NSCoder) -> Void) -> Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        encoder(archiver)
        return archiver.encodedData
    }

    private func write(_ data: Data, sync: Bool) {
        job?.cancel()
        job = DispatchWorkItem {
            self.error = nil
            let location = URL.persistenceLocation(for: self.fileName)
            if !self.fileStore.persist(data, url: location) {
                self.error = CocoaError(.fileWriteNoPermission)
            }
            self.fileStore.remove(fileAtURL: .persistenceLocation(for: self.lastLoadedStateFileName))
            self.fileStore.remove(fileAtURL: .persistenceLocation(for: self.oldStateFileName))
        }
        queue.dispatch(job!, sync: sync)
    }

    private func loadStateFromFile() -> Data? {
        fileStore.loadData(at: URL.persistenceLocation(for: self.fileName), decryptIfNeeded: false)
        ?? fileStore.loadData(at: .persistenceLocation(for: self.lastLoadedStateFileName), decryptIfNeeded: false)
        ?? fileStore.loadData(at: .persistenceLocation(for: self.oldStateFileName), decryptIfNeeded: false)
    }

    @MainActor
    private func restoreState(from archive: Data, using restore: @escaping @MainActor (NSCoder) throws -> Void) throws {
        guard let data = fileStore.decrypt(archive) else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        try restore(unarchiver)
    }

}
