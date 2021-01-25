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

class FileStoreMock: NSObject, FileStoring {

    private var _storage = [String: Data]()
    private let lock = NSLock()
    @objc dynamic var storage: [String: Data] {
        // swiftlint:disable implicit_getter
        get {
            lock.lock()
            defer { lock.unlock() }

            return _storage
        }
        // swiftlint:enable implicit_getter
        _modify {
            lock.lock()
            defer {
                lock.unlock()
            }

            yield &_storage
        }
    }

    var failWithError: Error?
    var delay: TimeInterval = 0

    func persist(_ data: Data, fileName: String) throws {
        if delay > 0 {
            usleep(UInt32(delay * 1_000_000))
        }
        guard failWithError == nil else { throw failWithError! }
        storage[fileName] = data
    }

    func loadData(named fileName: String) throws -> Data {
        guard failWithError == nil else { throw failWithError! }
        guard let data = storage[fileName] else { throw CocoaError.init(.fileReadNoSuchFile) }
        return data
    }

    func hasData(for fileName: String) -> Bool {
        storage[fileName] != nil
    }

    func remove(_ fileName: String) {
        storage[fileName] = nil
    }
}
