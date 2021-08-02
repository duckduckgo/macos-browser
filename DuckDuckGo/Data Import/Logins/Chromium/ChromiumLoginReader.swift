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
import CommonCrypto
import GRDB

final class ChromiumLoginReader {

    enum ImportError: Error {
        case databaseAccessFailed
        case decryptionFailed
    }

    private let chromiumLoginDirectoryPath: String
    private let processName: String
    private let decryptionKey: String?

    init(chromiumDataDirectoryPath: String, processName: String, decryptionKey: String? = nil) {
        self.chromiumLoginDirectoryPath = chromiumDataDirectoryPath + "/Login Data"
        self.processName = processName
        self.decryptionKey = decryptionKey
    }

    func readLogins() -> Result<[ImportedLoginCredential], ChromiumLoginReader.ImportError> {
        guard let key = self.decryptionKey ?? promptForChromiumPasswordKeychainAccess(), let derivedKey = deriveKey(from: key) else {
            return .failure(.decryptionFailed)
        }

        var importedLogins = [ImportedLoginCredential]()

        do {
            let queue = try DatabaseQueue(path: chromiumLoginDirectoryPath)

            try queue.read { database in
                let loginRows = try ChromiumCredential.fetchAll(database, sql: "SELECT signon_realm, username_value, password_value FROM logins;")

                for row in loginRows {
                    guard let decryptedPassword = decrypt(passwordData: row.encryptedPassword, with: derivedKey) else {
                        continue
                    }

                    let credential = ImportedLoginCredential(
                        url: row.url,
                        username: row.username,
                        password: decryptedPassword
                    )

                    importedLogins.append(credential)
                }
            }
        } catch {
            return .failure(.databaseAccessFailed)
        }

        return .success(importedLogins)
    }

    // Step 1: Prompt for permission to access the user's Chromium Safe Storage key.
    //         This value is stored in the keychain under "[BROWSER] Safe Storage", e.g. "Chrome Safe Storage".
    private func promptForChromiumPasswordKeychainAccess() -> String? {
        let key = "\(processName) Safe Storage"

        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrLabel as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne] as [String: Any]

        var dataFromKeychain: AnyObject?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataFromKeychain)

        if status == noErr, let passwordData = dataFromKeychain as? Data, let password = String(data: passwordData, encoding: .utf8) {
            return password
        } else {
            return nil
        }
    }

    // Step 2: Derive the decryption key from the Chromium Safe Storage key.
    //         This step uses fixed salt and iteration values that are hardcoded in Chromium.
    private func deriveKey(from password: String) -> Data? {
        return Cryptography.decryptPBKDF2(password: .utf8(password),
                                          salt: "saltysalt".data(using: .utf8)!,
                                          keyByteCount: 16,
                                          rounds: 1003,
                                          kdf: .sha1)
    }

    // Step 3: Decrypt password values from the credential database.
    private func decrypt(passwordData: Data, with key: Data) -> String? {
        let trimmedPasswordData = passwordData[3...]
        let iv = String(repeating: " ", count: 16).data(using: .utf8)!

        guard let decrypted = Cryptography.decryptAESCBC(data: trimmedPasswordData, key: key, iv: iv) else {
            return nil
        }
        
        return String(data: decrypted, encoding: .utf8)
    }

}

// MARK: - GRDB Fetchable Records

private struct ChromiumCredential {

    let url: String
    var username: String
    var encryptedPassword: Data

}

extension ChromiumCredential: FetchableRecord {

    init(row: Row) {
        url = row["signon_realm"]
        username = row["username_value"]
        encryptedPassword = row["password_value"]
    }

}
