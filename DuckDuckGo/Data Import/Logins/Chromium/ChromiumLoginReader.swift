//
//  ChromiumLoginReader.swift
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
import CryptoSwift // TODO: Get rid of this in favor of stdlib APIs
import GRDB

final class ChromiumLoginReader {

    enum ImportError: Error {
        case failedToAccessDatabase
    }

    private let chromiumLoginDirectoryPath: String
    private let processName: String

    init(chromiumDataDirectoryPath: String, processName: String) {
        self.chromiumLoginDirectoryPath = chromiumDataDirectoryPath + "/Login Data"
        self.processName = processName
    }

    func readLogins() -> Result<[ImportedLoginCredential], ChromiumLoginReader.ImportError> {
        let chromiumDecryptionKey = shell("security find-generic-password -wa '\(processName)'").replacingOccurrences(of: "\n", with: "")
        let derivedKey = deriveKey(from: chromiumDecryptionKey)

        var importedLogins = [ImportedLoginCredential]()

        do {
            let queue = try DatabaseQueue(path: chromiumLoginDirectoryPath)

            try queue.read { database in
                let loginsRows = (try? Row.fetchAll(database, sql: "SELECT signon_realm, username_value, password_value FROM logins;")) ?? []

                for row in loginsRows {
                    let url: String = row["signon_realm"]!
                    let username: String = row["username_value"]!
                    let encryptedPassword: Data = row["password_value"]!
                    let decryptedPassword = decrypt(passwordData: encryptedPassword, with: derivedKey)

                    importedLogins.append(ImportedLoginCredential(url: url, username: username, password: decryptedPassword))
                }
            }
        } catch {
            return .failure(.failedToAccessDatabase)
        }

        return .success(importedLogins)
    }

    // Step 1: Derive the key from the value stored in the Keychain under "Chrome Safe Storage".
    //         This step uses fixed salt and iteration values, hardcoded by Google.
    private func deriveKey(from password: String) -> [UInt8] {
        let key = try? PKCS5.PBKDF2(password: password.bytes,
                                    salt: "saltysalt".bytes,
                                    iterations: 1003,
                                    keyLength: 16,
                                    variant: .sha1)
        let calculatedKey = try? key!.calculate()

        return calculatedKey!
    }

    // Step 2: Decrypt password values from the credential database.
    private func decrypt(passwordData: Data, with key: [UInt8]) -> String {
        let iv = String(repeating: " ", count: 16).data(using: .utf8)!
        let blockMode = CBC(iv: iv.bytes)
        let trimmedPasswordData = passwordData[3...]

        let aes = try? CryptoSwift.AES(key: key, blockMode: blockMode)
        let decrypted = try? aes?.decrypt(trimmedPasswordData.bytes)

        let decryptedData = Data(decrypted!)

        return String(data: decryptedData, encoding: .utf8)!
    }

    private func shell(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        task.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!

        return output
    }

}
