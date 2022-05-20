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
        case couldNotFindLoginData
        case failedToTemporarilyCopyDatabase
        case decryptionFailed
    }

    private let chromiumLocalLoginDirectoryURL: URL
    private let chromiumGoogleAccountLoginDirectoryURL: URL
    private let processName: String
    private let decryptionKey: String?

    private static let sqlSelectWithPasswordTimestamp = "SELECT signon_realm, username_value, password_value, date_password_modified FROM logins;"
    private static let sqlSelectWithCreatedTimestamp = "SELECT signon_realm, username_value, password_value, date_created FROM logins;"
    private static let sqlSelectWithoutTimestamp = "SELECT signon_realm, username_value, password_value FROM logins;"

    init(chromiumDataDirectoryURL: URL, processName: String, decryptionKey: String? = nil) {
        self.chromiumLocalLoginDirectoryURL = chromiumDataDirectoryURL.appendingPathComponent("/Login Data")
        self.chromiumGoogleAccountLoginDirectoryURL = chromiumDataDirectoryURL.appendingPathComponent("/Login Data For Account")
        self.processName = processName
        self.decryptionKey = decryptionKey
    }

    func readLogins() -> Result<[ImportedLoginCredential], ChromiumLoginReader.ImportError> {
        guard let key = self.decryptionKey ?? promptForChromiumPasswordKeychainAccess(), let derivedKey = deriveKey(from: key) else {
            return .failure(.decryptionFailed)
        }

        let loginFileURLs = [chromiumLocalLoginDirectoryURL, chromiumGoogleAccountLoginDirectoryURL]
            .filter { FileManager.default.fileExists(atPath: $0.path) }

        guard !loginFileURLs.isEmpty else {
            return .failure(.couldNotFindLoginData)
        }

        var loginRows = [ChromiumCredential.ID: ChromiumCredential]()

        for loginFileURL in loginFileURLs {
            let temporaryFileHandler = TemporaryFileHandler(fileURL: loginFileURL)
            defer { temporaryFileHandler.deleteTemporarilyCopiedFile() }
            
            guard let temporaryDatabaseURL = try? temporaryFileHandler.copyFileToTemporaryDirectory() else {
                return .failure(.failedToTemporarilyCopyDatabase)
            }
            
            do {
                let queue = try DatabaseQueue(path: temporaryDatabaseURL.path)
                var rows = [ChromiumCredential]()

                try queue.read { database in
                    rows = try fetchCredentials(from: database)
                }

                for row in rows {
                    let existingRowTimestamp = loginRows[row.id]?.passwordModifiedAt
                    let newRowTimestamp = row.passwordModifiedAt

                    switch (newRowTimestamp, existingRowTimestamp) {
                    case let (.some(new), .some(existing)) where new > existing:
                        loginRows[row.id] = row
                    case (_, .none):
                        loginRows[row.id] = row
                    default:
                        break
                    }
                }

            } catch {
                return .failure(.databaseAccessFailed)
            }
        }

        let importedLogins = createImportedLoginCredentials(from: loginRows.values, decryptionKey: derivedKey)
        return .success(importedLogins)
    }
    
    private func createImportedLoginCredentials(from credentials: Dictionary<ChromiumCredential.ID, ChromiumCredential>.Values,
                                                decryptionKey: Data) -> [ImportedLoginCredential] {
        return credentials.compactMap { row -> ImportedLoginCredential? in
            guard let decryptedPassword = decrypt(passwordData: row.encryptedPassword, with: decryptionKey) else {
                return nil
            }
            
            return ImportedLoginCredential(
                url: row.url,
                username: row.username,
                password: decryptedPassword
            )
        }
    }
    
    private func fetchCredentials(from database: GRDB.Database) throws -> [ChromiumCredential] {
        do {
            return try ChromiumCredential.fetchAll(database, sql: Self.sqlSelectWithPasswordTimestamp)
        } catch let databaseError as DatabaseError {
            guard databaseError.isMissingColumnError else {
                throw databaseError
            }

            do {
                return try ChromiumCredential.fetchAll(database, sql: Self.sqlSelectWithCreatedTimestamp)
            } catch let databaseError as DatabaseError {
                guard databaseError.isMissingColumnError else {
                    throw databaseError
                }

                return try ChromiumCredential.fetchAll(database, sql: Self.sqlSelectWithoutTimestamp)
            }
        }
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
        guard passwordData.count >= 4 else {
            return nil
        }

        let trimmedPasswordData = passwordData[3...]

        guard let iv = String(repeating: " ", count: 16).data(using: .utf8),
              let decrypted = Cryptography.decryptAESCBC(data: trimmedPasswordData, key: key, iv: iv),
              passwordData.count >= 4 else {
            return nil
        }

        return String(data: decrypted, encoding: .utf8)
    }

}

// MARK: - GRDB Fetchable Records

private struct ChromiumCredential: Identifiable {

    var id: String {
        url + username
    }

    let url: String
    let username: String
    let encryptedPassword: Data
    let passwordModifiedAt: Int64?
}

extension ChromiumCredential: FetchableRecord {

    init(row: Row) {
        url = row["signon_realm"]
        username = row["username_value"]
        encryptedPassword = row["password_value"]
        passwordModifiedAt = row["date_password_modified"]
    }

}

fileprivate extension DatabaseError {
    var isMissingColumnError: Bool {
        guard let message = message else {
            return false
        }
        return message.hasPrefix("no such column")
    }
}
