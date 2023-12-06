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

    struct ImportError: DataImportError {
        enum OperationType: Int {
            case requiresPrimaryPassword = -1

            case couldNotFindLoginsFile
            case couldNotReadLoginsFile

            case key3readerStage1
            case key3readerStage2
            case key3readerStage3

            case key4readerStage1
            case key4readerStage2
            case key4readerStage3

            case decryptUsername
            case decryptPassword
        }

        var action: DataImportAction { .logins }
        var source: DataImport.Source { .firefox }
        let type: OperationType
        let underlyingError: Error?
    }

    typealias LoginReaderFileLineError = FileLineError<FirefoxLoginReader>

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
    private var currentOperationType: ImportError.OperationType = .requiresPrimaryPassword

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

    func readLogins(dataFormat: DataFormat?) -> DataImportResult<[ImportedLoginCredential]> {
        do {
            let result = try reallyReadLogins(dataFormat: dataFormat)
            return .success(result)
        } catch let error as ImportError {
            return .failure(error)
        } catch {
            return .failure(ImportError(type: currentOperationType, underlyingError: error))
        }
    }

    private func reallyReadLogins(dataFormat: DataFormat?) throws -> [ImportedLoginCredential] {
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
            return []
        }

        guard let detectedFormat else { throw ImportError(type: .couldNotFindLoginsFile, underlyingError: nil) }

        let databaseURL = firefoxProfileURL.appendingPathComponent(detectedFormat.formatFileNames.databaseName)
        let loginsFileURL = firefoxProfileURL.appendingPathComponent(detectedFormat.formatFileNames.loginFileName)

        // If there isn't a file where logins are expected, consider it a successful import of 0 logins
        // to avoid showing an error state.
        guard FileManager.default.fileExists(atPath: loginsFileURL.path) else {
            return []
        }

        currentOperationType = .couldNotReadLoginsFile
        let logins = try readLoginsFile(from: loginsFileURL.path)

        let encryptionKeyResult: DataImportResult<Data>

        switch detectedFormat {
        case .version2: encryptionKeyResult = keyReader.getEncryptionKey(key3DatabaseURL: databaseURL, primaryPassword: primaryPassword ?? "")
        case .version3: encryptionKeyResult = keyReader.getEncryptionKey(key4DatabaseURL: databaseURL, primaryPassword: primaryPassword ?? "")
        }

        let keyData = try encryptionKeyResult.get()
        let decryptedLogins = try decrypt(logins: logins, with: keyData)
        return decryptedLogins
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

    private func readLoginsFile(from loginsFilePath: String) throws -> EncryptedFirefoxLogins {
        let loginsFileData = try Data(contentsOf: URL(fileURLWithPath: loginsFilePath))

        return try JSONDecoder().decode(EncryptedFirefoxLogins.self, from: loginsFileData)
    }

    private func decrypt(logins: EncryptedFirefoxLogins, with key: Data) throws -> [ImportedLoginCredential] {
        var credentials = [ImportedLoginCredential]()

        // Filter out rows that are used by the Firefox sync service.
        let loginsToImport = logins.logins.filter { $0.hostname != "chrome://FirefoxAccounts" }

        var lastError: Error?
        for login in loginsToImport {
            do {
                currentOperationType = .decryptUsername
                let decryptedUsername = try decrypt(credential: login.encryptedUsername, key: key)
                currentOperationType = .decryptPassword
                let decryptedPassword = try decrypt(credential: login.encryptedPassword, key: key)

                credentials.append(ImportedLoginCredential(url: login.hostname, username: decryptedUsername, password: decryptedPassword))
            } catch {
                lastError = error
            }
        }

        if let lastError, credentials.isEmpty {
            throw lastError
        }
        return credentials
    }

    private func decrypt(credential: String, key: Data) throws -> String {
        guard let base64Decoded = Data(base64Encoded: credential) else { throw LoginReaderFileLineError() }

        let asn1Decoded = try ASN1Parser.parse(data: base64Decoded)

        var lineError = LoginReaderFileLineError.nextLine()
        guard case let .sequence(topLevelValues) = asn1Decoded, lineError.next(),
              case let .sequence(initializationVectorValues) = topLevelValues[1], lineError.next(),
              case let .octetString(initializationVector) = initializationVectorValues[1], lineError.next(),
              case let .octetString(ciphertext) = topLevelValues[2] else {
            throw lineError
        }

        let decryptedData = try Cryptography.decrypt3DES(data: ciphertext, key: key, iv: initializationVector)

        return try String(data: decryptedData, encoding: .utf8) ?? { throw LoginReaderFileLineError() }()
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
