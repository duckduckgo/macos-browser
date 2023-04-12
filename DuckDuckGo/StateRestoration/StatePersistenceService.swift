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
    private var lastSessionStateArchive: Data?
    private let queue = DispatchQueue(label: "StateRestorationManager.queue", qos: .background)
    private var job: DispatchWorkItem?

    private(set) var error: Error?

    init(fileStore: FileStore, fileName: String) {
        self.fileStore = fileStore
        self.fileName = fileName
    }

    var canRestoreLastSessionState: Bool {
        lastSessionStateArchive != nil
    }

    func persistState(using encoder: @escaping (NSCoder) -> Void, sync: Bool = false) {
        dispatchPrecondition(condition: .onQueue(.main))

        let data = archive(using: encoder)
        write(data, sync: sync)
    }

    func clearState(sync: Bool = false) {
        dispatchPrecondition(condition: .onQueue(.main))

        job?.cancel()
        job = DispatchWorkItem {
            let location = URL.persistenceLocation(for: self.fileName)
            self.fileStore.remove(fileAtURL: location)
        }
        queue.dispatch(job!, sync: sync)
    }

    func flush() {
        queue.sync {}
    }

    func loadLastSessionState() {
        lastSessionStateArchive = loadStateFromFile()
    }

    func removeLastSessionState() {
        lastSessionStateArchive = nil
    }

    func restoreState(using restore: @escaping (NSCoder) throws -> Void) throws {
        guard let encryptedData = lastSessionStateArchive ?? loadStateFromFile() else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        try restoreState(from: encryptedData, using: restore)
    }

    // MARK: - Private

    private func archive(using encoder: @escaping (NSCoder) -> Void) -> Data {
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
        }
        queue.dispatch(job!, sync: sync)
    }

    private func loadStateFromFile() -> Data? {
        fileStore.loadData(at: URL.persistenceLocation(for: self.fileName), decryptIfNeeded: false)
    }

    private func restoreState(from archive: Data, using restore: @escaping (NSCoder) throws -> Void) throws {
        guard let data = fileStore.decrypt(archive) else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        let unarchiver = try NSKeyedUnarchiver.init(forReadingFrom: data)
        try restore(unarchiver)
    }

}
