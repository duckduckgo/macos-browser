//
//  FirefoxLoginReader.swift
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
import CryptoKit

final class FirefoxLoginReader {

    enum ImportError: Error {
        case requiresPrimaryPassword
        case databaseAccessFailed
        case couldNotFindProfile
        case couldNotGetDecryptionKey
        case couldNotFindLoginsFile
        case couldNotReadLoginsFile
        case decryptionFailed
        case failedToTemporarilyCopyFile
    }

    /// Enumerates the supported Firefox login database formats.
    /// The importer will infer which format is present based on the contents of the user's Firefox profile, doing so by iterating over these formats and inspecting the file system.
    /// These are deliberately listed from newest to oldest, so that the importer tries the latest format first.
    enum DataFormat: CaseIterable {
        case version3
        case version2

        var formatFileNames: (databaseName: String, loginFileName: String) {
            switch self {
            case .version3: return (databaseName: "key4.db", loginFileName: "logins.json")
            case .version2: return (databaseName: "key3.db", loginFileName: "logins.json")
            }
        }
    }

    private let keyReader: FirefoxEncryptionKeyReading
    private let primaryPassword: String?
    private let firefoxProfileURL: URL

    /// Initialize a FirefoxLoginReader with a profile path and optional primary password.
    ///
    /// - Parameter firefoxProfileURL: The path to the profile being imported from. This should be the base path of the profile, containing the database and JSON files.
    /// - Parameter primaryPassword: The password used to decrypt the login data. This is optional, as Firefox's primary password feature is optional.
    init(firefoxProfileURL: URL,
         keyReader: FirefoxEncryptionKeyReading = FirefoxEncryptionKeyReader(),
         primaryPassword: String? = nil) {

        self.keyReader = keyReader
        self.primaryPassword = primaryPassword
        self.firefoxProfileURL = firefoxProfileURL
    }

    func readLogins(dataFormat: DataFormat?) -> Result<[ImportedLoginCredential], FirefoxLoginReader.ImportError> {
        var detectedFormat: DataFormat?
        var foundKeyDatabaseWithoutLoginFile = false

        if let dataFormat = dataFormat {
            detectedFormat = dataFormat
        } else {
            let detectionResult = detectLoginFormat(withProfileURL: firefoxProfileURL)
            detectedFormat = detectionResult.dataFormat
            foundKeyDatabaseWithoutLoginFile = detectionResult.foundKeyDatabaseButNoLoginsFile
        }

        // There's a legitimate case where the key database exists, but there's no logins file. This happens when the user has never
        // saved a login. To avoid showing them an error, we check for the existence of the SQLite database but no logins file.
        if foundKeyDatabaseWithoutLoginFile {
            return .success([])
        }

        guard let detectedFormat = detectedFormat else {
            return .failure(.couldNotFindLoginsFile)
        }

        let databaseURL = firefoxProfileURL.appendingPathComponent(detectedFormat.formatFileNames.databaseName)
        let loginsFileURL = firefoxProfileURL.appendingPathComponent(detectedFormat.formatFileNames.loginFileName)

        // If there isn't a file where logins are expected, consider it a successful import of 0 logins
        // to avoid showing an error state.
        guard FileManager.default.fileExists(atPath: loginsFileURL.path) else {
            return .success([])
        }

        guard let logins = readLoginsFile(from: loginsFileURL.path) else {
            return .failure(.couldNotReadLoginsFile)
        }

        let encryptionKeyResult: Result<Data, FirefoxLoginReader.ImportError>

        switch detectedFormat {
        case .version2: encryptionKeyResult = keyReader.getEncryptionKey(key3DatabaseURL: databaseURL, primaryPassword: primaryPassword ?? "")
        case .version3: encryptionKeyResult = keyReader.getEncryptionKey(key4DatabaseURL: databaseURL, primaryPassword: primaryPassword ?? "")
        }

        switch encryptionKeyResult {
        case .success(let keyData):
            let decryptedLogins = decrypt(logins: logins, with: keyData)
            return .success(decryptedLogins)
        case .failure(let error):
            return .failure(error)
        }
    }

    private func detectLoginFormat(withProfileURL firefoxProfileURL: URL) -> (dataFormat: DataFormat?, foundKeyDatabaseButNoLoginsFile: Bool) {
        var foundKeyDatabaseWithoutLoginFile = false

        for potentialFormat in DataFormat.allCases {
            let potentialDatabaseURL = firefoxProfileURL.appendingPathComponent(potentialFormat.formatFileNames.databaseName)
            let potentialLoginsFileURL = firefoxProfileURL.appendingPathComponent(potentialFormat.formatFileNames.loginFileName)

            if FileManager.default.fileExists(atPath: potentialDatabaseURL.path) {
                if FileManager.default.fileExists(atPath: potentialLoginsFileURL.path) {
                    return (potentialFormat, false)
                } else {
                    foundKeyDatabaseWithoutLoginFile = true
                }
            }
        }

        return (nil, foundKeyDatabaseWithoutLoginFile)
    }

    private func readLoginsFile(from loginsFilePath: String) -> EncryptedFirefoxLogins? {
        guard let loginsFileData = try? Data(contentsOf: URL(fileURLWithPath: loginsFilePath)) else {
            return nil
        }

        return try? JSONDecoder().decode(EncryptedFirefoxLogins.self, from: loginsFileData)
    }

    private func decrypt(logins: EncryptedFirefoxLogins, with key: Data) -> [ImportedLoginCredential] {
        var credentials = [ImportedLoginCredential]()

        // Filter out rows that are used by the Firefox sync service.
        let loginsToImport = logins.logins.filter { $0.hostname != "chrome://FirefoxAccounts" }

        for login in loginsToImport {
            let decryptedUsername = decrypt(credential: login.encryptedUsername, key: key)
            let decryptedPassword = decrypt(credential: login.encryptedPassword, key: key)

            if let username = decryptedUsername, let password = decryptedPassword {
                credentials.append(ImportedLoginCredential(url: login.hostname, username: username, password: password))
            }
        }

        return credentials
    }

    private func decrypt(credential: String, key: Data) -> String? {
        guard let base64Decoded = Data(base64Encoded: credential) else {
            return nil
        }

        let asn1Decoded = try? ASN1Parser.parse(data: base64Decoded)

        guard case let .sequence(topLevelValues) = asn1Decoded,
              case let .sequence(initializationVectorValues) = topLevelValues[1],
              case let .octetString(initializationVector) = initializationVectorValues[1],
              case let .octetString(ciphertext) = topLevelValues[2] else {
            return nil
        }

        guard let decryptedData = Cryptography.decrypt3DES(data: ciphertext, key: key, iv: initializationVector) else {
            return nil
        }

        return String(data: decryptedData, encoding: .utf8)
    }

}

/// Represents the logins.json file found in the Firefox profile directory
private struct EncryptedFirefoxLogins: Decodable {

    struct Login: Decodable {
        let hostname: String
        let encryptedUsername: String
        let encryptedPassword: String
    }

    let logins: [Login]

}
