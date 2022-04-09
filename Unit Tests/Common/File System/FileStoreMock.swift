//
//  FileStoreMock.swift
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
@testable import DuckDuckGo_Privacy_Browser

final class FileStoreMock: NSObject, FileStore {

    private var _fileStorage = [String: Data]()
    private let fileStorageLock = NSLock()
    @objc dynamic var storage: [String: Data] {
        // swiftlint:disable implicit_getter
        get {
            fileStorageLock.lock()
            defer { fileStorageLock.unlock() }

            return _fileStorage
        }
        // swiftlint:enable implicit_getter
        _modify {
            fileStorageLock.lock()
            defer {
                fileStorageLock.unlock()
            }

            yield &_fileStorage
        }
    }

    private var _directoryStorage = [String: [String]]()
    private let directoryStorageLock = NSLock()
    @objc dynamic var directoryStorage: [String: [String]] {
        // swiftlint:disable implicit_getter
        get {
            directoryStorageLock.lock()
            defer { directoryStorageLock.unlock() }

            return _directoryStorage
        }
        // swiftlint:enable implicit_getter
        _modify {
            directoryStorageLock.lock()
            defer {
                directoryStorageLock.unlock()
            }

            yield &_directoryStorage
        }
    }

    var failWithError: Error?
    var delay: TimeInterval = 0

    func persist(_ data: Data, url: URL) -> Bool {
        if delay > 0 {
            usleep(UInt32(delay * 1_000_000))
        }
        guard failWithError == nil else { return false }
        storage[url.lastPathComponent] = data
        return true
    }

    func loadData(at url: URL) -> Data? {
        guard failWithError == nil else { return nil }
        guard let data = storage[url.lastPathComponent] else { return nil }
        return data
    }

    func hasData(at url: URL) -> Bool {
        storage[url.lastPathComponent] != nil
    }

    func directoryContents(at path: String) throws -> [String] {
        directoryStorage[path] ?? []
    }

    func remove(fileAtURL url: URL) {
        storage[url.lastPathComponent] = nil
    }
}
