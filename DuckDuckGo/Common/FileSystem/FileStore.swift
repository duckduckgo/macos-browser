//
//  FileStore.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import CryptoKit

public protocol FileStoring {
    func persist(_ data: Data, fileName: String) throws
    func loadData(named fileName: String) throws -> Data
    func hasData(for fileName: String) -> Bool
    func remove(_ fileName: String)
}

public class FileStore: FileStoring {
    private let encryptionKey: SymmetricKey?

    init(encryptionKey: SymmetricKey? = nil) {
        self.encryptionKey = encryptionKey
    }

    public func persist(_ data: Data, fileName: String) throws {
        let dataToWrite: Data

        if let key = self.encryptionKey {
            dataToWrite = try DataEncryption.encrypt(data: data, key: key)
        } else {
            dataToWrite = data
        }

        try dataToWrite.write(to: persistenceLocation(for: fileName))
    }

    public func loadData(named fileName: String) throws -> Data {
        let data = try Data(contentsOf: persistenceLocation(for: fileName))

        guard let key = self.encryptionKey else {
            return data
        }

        return try DataEncryption.decrypt(data: data, key: key)
    }

    public func hasData(for fileName: String) -> Bool {
        let path = persistenceLocation(for: fileName).path
        var isDir: ObjCBool = false
        return FileManager().fileExists(atPath: path, isDirectory: &isDir) && !isDir.boolValue
    }

    public func remove(_ fileName: String) {
        let url = persistenceLocation(for: fileName)
        var isDir: ObjCBool = false
        guard FileManager().fileExists(atPath: url.path, isDirectory: &isDir) && !isDir.boolValue else { return }
        try? FileManager().removeItem(at: url)
    }

    func persistenceLocation(for fileName: String) -> URL {
        let applicationSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return applicationSupportPath.appendingPathComponent(fileName)
    }

}
