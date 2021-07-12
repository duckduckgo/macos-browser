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

protocol FileStoring {
    func persist(_ data: Data, fileName: String) -> Bool
    func loadData(named fileName: String) -> Data?
    func hasData(for fileName: String) -> Bool
    func remove(_ fileName: String)
}

final class FileStore: FileStoring {

    private let encryptionKey: SymmetricKey?

    init(encryptionKey: SymmetricKey? = nil) {
        self.encryptionKey = encryptionKey
    }

    func persist(_ data: Data, fileName: String) -> Bool {
        do {
            let dataToWrite: Data

            if let key = self.encryptionKey {
                dataToWrite = try DataEncryption.encrypt(data: data, key: key)
            } else {
                dataToWrite = data
            }

            try dataToWrite.write(to: persistenceLocation(for: fileName))

            return true
        } catch {
            Pixel.fire(.debug(event: .fileStoreWriteFailed, error: error),
                       withAdditionalParameters: ["config": fileName])
            return false
        }
    }

    func loadData(named fileName: String) -> Data? {
        guard let data = try? Data(contentsOf: persistenceLocation(for: fileName)) else {
            return nil
        }

        if let key = self.encryptionKey {
            return try? DataEncryption.decrypt(data: data, key: key)
        } else {
            return data
        }
    }

    func hasData(for fileName: String) -> Bool {
        let path = persistenceLocation(for: fileName).path
        return FileManager.default.fileExists(atPath: path)
    }

    func remove(_ fileName: String) {
        let url = persistenceLocation(for: fileName)
        var isDir: ObjCBool = false
        let fileManager = FileManager()
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && !isDir.boolValue else { return }
        try? fileManager.removeItem(at: url)
    }

    func persistenceLocation(for fileName: String) -> URL {
        let applicationSupportPath = URL.sandboxApplicationSupportURL
        return applicationSupportPath.appendingPathComponent(fileName)
    }

}
