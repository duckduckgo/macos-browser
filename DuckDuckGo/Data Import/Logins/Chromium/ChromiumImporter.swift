//
//  ChromiumImporter.swift
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
import CryptoSwift
import GRDB

internal class ChromiumImporter: DataImporter {

    var processName: String {
        fatalError("Subclasses must provide their own process name")
    }

    private let applicationDataDirectoryPath: String

    private var loginDataPath: String {
        return applicationDataDirectoryPath + "/Login Data"
    }

    init(applicationDataDirectoryPath: String) {
        self.applicationDataDirectoryPath = applicationDataDirectoryPath
    }

    func importableTypes() -> [DataImport.DataType] {
        // TODO: Check if browser data exists at the application directory path
        return [.logins]
    }

    func importData(types: [DataImport.DataType], completion: @escaping (Result<[DataImport.Summary], DataImportError>) -> Void) {
        print("Importing from Chromium")
        importLogins()

        completion(.success([]))
    }

    // MARK: - Private

    func importLogins() {
        let chromiumDecryptionKey = shell("security find-generic-password -wa '\(processName)'").replacingOccurrences(of: "\n", with: "")
        let derivedKey = deriveKey(from: chromiumDecryptionKey)

        print(String(repeating: "=", count: 80))
        print("Decrypting \(processName) logins with original key: \(chromiumDecryptionKey), derived key: \(derivedKey.toHexString())")
        print("")

        do {
            let queue = try DatabaseQueue(path: loginDataPath)

            try queue.read { database in
                let loginsRows = (try? Row.fetchAll(database, sql: "SELECT action_url, username_value, password_value FROM logins;")) ?? []

                for row in loginsRows {
                    let url: String = row["action_url"]!
                    let username: String = row["username_value"]!
                    let encryptedPassword: Data = row["password_value"]!
                    let decryptedPassword = decrypt(passwordData: encryptedPassword, with: derivedKey)

                    print("• \(processName) Credential (\(url)): Username = \(username), Password = \(decryptedPassword)")
                }
            }
        } catch {
            print("Failed to read database, with error: \(error)")
        }

        print(String(repeating: "=", count: 80))
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
