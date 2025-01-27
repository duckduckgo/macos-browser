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
import BrowserServicesKit

final class FirefoxLoginReader {

    struct ImportError: DataImportError {
        enum OperationType: Int {
            case requiresPrimaryPassword = -1

            case couldNotDetermineFormat = -2

            case couldNotFindLoginsFile = 0
            case couldNotReadLoginsFile

            case key3readerStage1
            case key3readerStage2
            case key3readerStage3

            case key4readerStage1
            case key4readerStage2
            case key4readerStage3

            case decryptUsername
            case decryptPassword

            case couldNotFindKeyDB
        }

        var action: DataImportAction { .passwords }
        let type: OperationType
        let underlyingError: Error?

        var errorType: DataImport.ErrorType {
            switch type {
            case .couldNotFindLoginsFile, .couldNotFindKeyDB, .couldNotReadLoginsFile: .noData
            case .key3readerStage1, .key3readerStage2, .key3readerStage3, .key4readerStage1, .key4readerStage2, .key4readerStage3, .decryptUsername, .decryptPassword: .decryptionError
            case .couldNotDetermineFormat: .dataCorrupted
            case .requiresPrimaryPassword: .other
            }
        }
    }

    typealias LoginReaderFileLineError = FileLineError<FirefoxLoginReader>

    /// Enumerates the supported Firefox login database formats.
    /// The importer will infer which format is present based on the contents of the user's Firefox profile, doing so by iterating over these formats and inspecting the file system.
    /// These are deliberately listed from newest to oldest, so that the importer tries the latest format first.
    enum DataFormat: CaseIterable {
        case version3
        case version2

        var formatFileNames: (databaseName: String, loginsFileName: String) {
            switch self {
            case .version3: return (databaseName: "key4.db", loginsFileName: "logins.json")
            case .version2: return (databaseName: "key3.db", loginsFileName: "logins.json")
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
         keyReader: FirefoxEncryptionKeyReading? = nil,
         primaryPassword: String? = nil) {

        self.keyReader = keyReader ?? FirefoxEncryptionKeyReader()
        self.primaryPassword = primaryPassword
        self.firefoxProfileURL = firefoxProfileURL
    }

    func readLogins(dataFormat: DataFormat?) -> DataImportResult<[ImportedLoginCredential]> {
        var currentOperationType: ImportError.OperationType = .couldNotFindLoginsFile
        do {
            let dataFormat = try dataFormat ?? detectLoginFormat() ?? { throw ImportError(type: .couldNotFindKeyDB, underlyingError: nil) }()
            let keyData = try getEncryptionKey(dataFormat: dataFormat)
            let result = try reallyReadLogins(dataFormat: dataFormat, keyData: keyData, currentOperationType: &currentOperationType)
            return .success(result)
        } catch let error as ImportError {
            return .failure(error)
        } catch {
            return .failure(ImportError(type: currentOperationType, underlyingError: error))
        }
    }

    func getEncryptionKey() throws -> Data {
        let dataFormat = try detectLoginFormat() ?? { throw ImportError(type: .couldNotFindKeyDB, underlyingError: nil) }()
        return try getEncryptionKey(dataFormat: dataFormat)
    }

    private func getEncryptionKey(dataFormat: DataFormat) throws -> Data {
        let databaseURL = firefoxProfileURL.appendingPathComponent(dataFormat.formatFileNames.databaseName)

        switch dataFormat {
        case .version2:
            return try keyReader.getEncryptionKey(key3DatabaseURL: databaseURL, primaryPassword: primaryPassword ?? "").get()
        case .version3:
            return try keyReader.getEncryptionKey(key4DatabaseURL: databaseURL, primaryPassword: primaryPassword ?? "").get()
        }
    }

    private func reallyReadLogins(dataFormat: DataFormat, keyData: Data, currentOperationType: inout ImportError.OperationType) throws -> [ImportedLoginCredential] {
        let loginsFileURL = firefoxProfileURL.appendingPathComponent(dataFormat.formatFileNames.loginsFileName)

        currentOperationType = .couldNotReadLoginsFile
        let logins = try readLoginsFile(from: loginsFileURL.path)

        let decryptedLogins = try decrypt(logins: logins, with: keyData, currentOperationType: &currentOperationType)
        return decryptedLogins
    }

    private func detectLoginFormat() throws -> DataFormat? {
        for potentialFormat in DataFormat.allCases {
            let databaseURL = firefoxProfileURL.appendingPathComponent(potentialFormat.formatFileNames.databaseName)
            let loginsURL = firefoxProfileURL.appendingPathComponent(potentialFormat.formatFileNames.loginsFileName)

            if FileManager.default.fileExists(atPath: databaseURL.path) {
                guard FileManager.default.fileExists(atPath: loginsURL.path) else {
                    throw ImportError(type: .couldNotFindLoginsFile, underlyingError: nil)
                }
                return potentialFormat
            }
        }

        return nil
    }

    private func readLoginsFile(from loginsFilePath: String) throws -> EncryptedFirefoxLogins {
        let loginsFileData = try Data(contentsOf: URL(fileURLWithPath: loginsFilePath))

        return try JSONDecoder().decode(EncryptedFirefoxLogins.self, from: loginsFileData)
    }

    private func decrypt(logins: EncryptedFirefoxLogins, with key: Data, currentOperationType: inout ImportError.OperationType) throws -> [ImportedLoginCredential] {
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

                credentials.append(ImportedLoginCredential(url: login.hostname, username: decryptedUsername, password: decryptedPassword, notes: nil))
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
