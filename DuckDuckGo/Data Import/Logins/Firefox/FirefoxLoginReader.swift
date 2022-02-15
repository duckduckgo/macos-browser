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
import GRDB

final class FirefoxLoginReader {

    enum ImportError: Error {
        case requiresPrimaryPassword
        case databaseAccessFailed
        case couldNotFindProfile
        case couldNotGetDecryptionKey
        case couldNotReadLoginsFile
        case decryptionFailed
    }

    private enum Constants {
        static let defaultKeyDatabaseName = "key4.db"
        static let defaultLoginsFileNane = "logins.json"
    }

    private let primaryPassword: String?
    private let keyDatabaseName: String
    private let loginsFileName: String

    private let firefoxProfileURL: URL

    /// Initialize a FirefoxLoginReader with a profile path and optional primary password.
    ///
    /// - Parameter firefoxProfileURL: The path to the profile being imported from. This should be the base path of the profile, containing the `key4.db` and `logins.json` files.
    /// - Parameter primaryPassword: The password used to decrypt the login data. This is optional, as Firefox's primary password feature is optional.
    init(firefoxProfileURL: URL,
         primaryPassword: String? = nil,
         databaseFileName: String = Constants.defaultKeyDatabaseName,
         loginsFileName: String = Constants.defaultLoginsFileNane) {

        self.primaryPassword = primaryPassword
        self.keyDatabaseName = databaseFileName
        self.loginsFileName = loginsFileName
        self.firefoxProfileURL = firefoxProfileURL
    }

    func readLogins() -> Result<[ImportedLoginCredential], FirefoxLoginReader.ImportError> {
        let databasePath = firefoxProfileURL.appendingPathComponent(keyDatabaseName).path

        let loginsPath = firefoxProfileURL.appendingPathComponent(loginsFileName).path
        
        // If there isn't a file where logins are expected, consider it a successful import of 0 logins
        // to avoid showing an error state.
        guard FileManager.default.fileExists(atPath: loginsPath) else {
            return .success([])
        }
        
        guard let logins = readLoginsFile(from: loginsPath) else {
            return .failure(.couldNotReadLoginsFile)
        }

        let encryptionKeyResult = getEncryptionKey(withDatabaseAt: databasePath)

        switch encryptionKeyResult {
        case .success(let keyData):
            let decryptedLogins = decrypt(logins: logins, with: keyData)
            return .success(decryptedLogins)
        case .failure(let error):
            return .failure(error)
        }
    }

    private func getEncryptionKey(withDatabaseAt databasePath: String) -> Result<Data, FirefoxLoginReader.ImportError> {
        var key: Data?
        var error: FirefoxLoginReader.ImportError?

        do {
            let queue = try DatabaseQueue(path: databasePath)

            try queue.read { database in
                guard let metadataRow = try? Row.fetchOne(database, sql: "SELECT item1, item2 FROM metadata WHERE id = 'password'") else {
                    error = .databaseAccessFailed
                    return
                }

                let globalSalt: Data = metadataRow["item1"]
                let item2: Data = metadataRow["item2"]

                guard let decodedItem2 = try? ASN1Parser.parse(data: item2),
                      let iv = extractInitializationVector(from: decodedItem2),
                      let decryptedItem2 = aesDecrypt(tlv: decodedItem2, iv: iv, globalSalt: globalSalt) else {
                    error = .decryptionFailed
                    return
                }

                let string = String(data: decryptedItem2, encoding: .utf8)

                // The password check is technically "password-check\x02\x02", it's converted to UTF-8 and checked here for simplicity
                if string != "password-check" {
                    error = .requiresPrimaryPassword
                }

                guard let nssPrivateRow = try? Row.fetchOne(database, sql: "SELECT a11, a102 FROM nssPrivate;") else {
                    error = .decryptionFailed
                    return
                }

                let a11: Data = nssPrivateRow["a11"]
                let a102: Data = nssPrivateRow["a102"]

                assert(a102 == Data([248, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]))

                guard let decodedA11 = try? ASN1Parser.parse(data: a11), let finalIV = extractInitializationVector(from: decodedA11) else {
                    error = .decryptionFailed
                    return
                }

                key = aesDecrypt(tlv: decodedA11, iv: finalIV, globalSalt: globalSalt)
            }
        } catch {
            return .failure(.databaseAccessFailed)
        }

        if let error = error {
            return .failure(error)
        } else if let key = key {
            return .success(key)
        } else {
            return .failure(.databaseAccessFailed)
        }
    }

    private func readLoginsFile(from loginsFilePath: String) -> EncryptedFirefoxLogins? {
        guard let loginsFileData = try? Data(contentsOf: URL(fileURLWithPath: loginsFilePath)) else {
            return nil
        }

        return try? JSONDecoder().decode(EncryptedFirefoxLogins.self, from: loginsFileData)
    }

    private func aesDecrypt(tlv: ASN1Parser.Node,
                            iv: Data,
                            globalSalt: Data) -> Data? {
        guard let data = extractCiphertext(from: tlv),
              let entrySalt = extractEntrySalt(from: tlv),
              let iterationCount = extractIterationCount(from: tlv),
              let keyLength = extractKeyLength(from: tlv) else { return nil }

        assert(keyLength == 32)

        let passwordData = globalSalt + (primaryPassword ?? "").data(using: .utf8)!
        let hashData = SHA.from(data: passwordData)

        guard let commonCryptoKey = Cryptography.decryptPBKDF2(password: .base64(hashData.base64EncodedString()),
                                                               salt: entrySalt,
                                                               keyByteCount: keyLength,
                                                               rounds: iterationCount,
                                                               kdf: .sha256) else { return nil }

        let iv = Data([4, 14]) + iv
        guard let decryptedData = Cryptography.decryptAESCBC(data: data, key: commonCryptoKey.dataRepresentation, iv: iv) else {
            return nil
        }

        return Data(decryptedData)
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

extension FirefoxLoginReader {

    private func extractEntrySalt(from tlv: ASN1Parser.Node) -> Data? {
        guard case let .sequence(values1) = tlv else {
            return nil
        }

        let firstValue = values1[0]

        guard case let .sequence(values2) = firstValue else {
            return nil
        }

        let secondValue = values2[1]

        guard case let .sequence(values3) = secondValue else {
            return nil
        }

        let thirdValue = values3[0]

        guard case let .sequence(values4) = thirdValue else {
            return nil
        }

        let fourthValue = values4[1]

        guard case let .sequence(values5) = fourthValue else {
            return nil
        }

        let fifthValue = values5[0]

        guard case let .octetString(data: data) = fifthValue else {
            return nil
        }

        return data
    }

    private func extractIterationCount(from tlv: ASN1Parser.Node) -> Int? {
        guard case let .sequence(values1) = tlv else {
            return nil
        }

        let firstValue = values1[0]

        guard case let .sequence(values2) = firstValue else {
            return nil
        }

        let secondValue = values2[1]

        guard case let .sequence(values3) = secondValue else {
            return nil
        }

        let thirdValue = values3[0]

        guard case let .sequence(values4) = thirdValue else {
            return nil
        }

        let fourthValue = values4[1]

        guard case let .sequence(values5) = fourthValue else {
            return nil
        }

        let fifthValue = values5[1]

        guard case let .integer(data: data) = fifthValue else {
            return nil
        }

        return data.integer
    }

    private func extractKeyLength(from tlv: ASN1Parser.Node) -> Int? {
        guard case let .sequence(values1) = tlv else {
            return nil
        }

        let firstValue = values1[0]

        guard case let .sequence(values2) = firstValue else {
            return nil
        }

        let secondValue = values2[1]

        guard case let .sequence(values3) = secondValue else {
            return nil
        }

        let thirdValue = values3[0]

        guard case let .sequence(values4) = thirdValue else {
            return nil
        }

        let fourthValue = values4[1]

        guard case let .sequence(values5) = fourthValue else {
            return nil
        }

        let fifthValue = values5[2]

        guard case let .integer(data: data) = fifthValue else {
            return nil
        }

        return data.integer
    }

    private func extractInitializationVector(from tlv: ASN1Parser.Node) -> Data? {
        guard case let .sequence(values1) = tlv else {
            return nil
        }

        let firstValue = values1[0]

        guard case let .sequence(values2) = firstValue else {
            return nil
        }

        let secondValue = values2[1]

        guard case let .sequence(values3) = secondValue else {
            return nil
        }

        let thirdValue = values3[1]

        guard case let .sequence(values4) = thirdValue else {
            return nil
        }

        let fourthValue = values4[1]

        guard case let .octetString(data: data) = fourthValue else {
            return nil
        }

        return data
    }

    private func extractCiphertext(from tlv: ASN1Parser.Node) -> Data? {
        guard case let .sequence(values) = tlv else {
            return nil
        }

        guard case let .octetString(data: data) = values[1] else {
            return nil
        }

        return data
    }

}

private struct SHA {

    static func from(data: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))

        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }

        return Data(digest)
    }

}
