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
import PixelKit

protocol FileStore {
    func persist(_ data: Data, url: URL) -> Bool
    func loadData(at url: URL) -> Data?
    func loadData(at url: URL, decryptIfNeeded: Bool) -> Data?
    func decrypt(_ data: Data) -> Data?
    func hasData(at url: URL) -> Bool
    func directoryContents(at path: String) throws -> [String]
    func remove(fileAtURL url: URL)
    func move(fileAt from: URL, to: URL)
}

extension FileStore {
    func loadData(at url: URL) -> Data? {
        loadData(at: url, decryptIfNeeded: true)
    }
}

final class EncryptedFileStore: FileStore {

    private let encryptionKey: SymmetricKey?

    init(encryptionKey: SymmetricKey? = nil) {
        self.encryptionKey = encryptionKey
    }

    func persist(_ data: Data, url: URL) -> Bool {
        do {
            let dataToWrite: Data

            if let key = self.encryptionKey {
                dataToWrite = try DataEncryption.encrypt(data: data, key: key)
            } else {
                dataToWrite = data
            }

            try dataToWrite.write(to: url)

            return true
        } catch {
            PixelKit.fire(DebugEvent(GeneralPixel.fileStoreWriteFailed, error: error),
                       withAdditionalParameters: ["config": url.lastPathComponent])
            return false
        }
    }

    func loadData(at url: URL, decryptIfNeeded: Bool) -> Data? {
        let data = try? Data(contentsOf: url)
        return decryptIfNeeded ? data.flatMap(decrypt(_:)) : data
    }

    func decrypt(_ data: Data) -> Data? {
        if let key = self.encryptionKey {
            return try? DataEncryption.decrypt(data: data, key: key)
        }
        return data
    }

    func hasData(at url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }

    func directoryContents(at path: String) throws -> [String] {
        return try FileManager.default.contentsOfDirectory(atPath: path)
    }

    func remove(fileAtURL url: URL) {
        var isDir: ObjCBool = false
        let fileManager = FileManager()
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && !isDir.boolValue else { return }
        try? fileManager.removeItem(at: url)
    }

    func move(fileAt from: URL, to: URL) {
        try? FileManager.default.moveItem(at: from, to: to)
    }

}

extension FileManager: FileStore {

    func persist(_ data: Data, url: URL) -> Bool {
        do {
            try data.write(to: url)
            return true
        } catch {
            return false
        }
    }

    func loadData(at url: URL, decryptIfNeeded: Bool) -> Data? {
        let data = try? Data(contentsOf: url)
        return decryptIfNeeded ? data.flatMap(decrypt(_:)) : data
    }

    func decrypt(_ data: Data) -> Data? {
        data
    }

    func hasData(at url: URL) -> Bool {
        return fileExists(atPath: url.path)
    }

    func directoryContents(at path: String) throws -> [String] {
        return try contentsOfDirectory(atPath: path)
    }

    func remove(fileAtURL url: URL) {
        try? removeItem(at: url)
    }

    func move(fileAt from: URL, to: URL) {
        try? moveItem(at: from, to: to)
    }

}
