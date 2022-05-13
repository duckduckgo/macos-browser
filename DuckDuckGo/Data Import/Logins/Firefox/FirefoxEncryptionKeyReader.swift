//
//  FirefoxEncryptionKeyReader.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

protocol FirefoxEncryptionKeyReading {
    
    func getEncryptionKey(databaseURL: URL, primaryPassword: String) -> Result<Data, FirefoxLoginReader.ImportError>

}

final class FirefoxEncryptionKeyReader: FirefoxEncryptionKeyReading {
    
    // swiftlint:disable:next function_body_length
    func getEncryptionKey(databaseURL: URL, primaryPassword: String) -> Result<Data, FirefoxLoginReader.ImportError> {
        let temporaryFileHandler = TemporaryFileHandler(fileURL: databaseURL)
        
        defer {
            temporaryFileHandler.deleteTemporarilyCopiedFile()
        }
        
        guard case let .success(temporaryDatabaseURL) = temporaryFileHandler.copyFileToTemporaryDirectory() else {
            return .failure(.failedToTemporarilyCopyFile)
        }
        
        var key: Data?
        var error: FirefoxLoginReader.ImportError?

        do {
            let queue = try DatabaseQueue(path: temporaryDatabaseURL.path)

            try queue.read { database in
                guard let metadataRow = try? Row.fetchOne(database, sql: "SELECT item1, item2 FROM metadata WHERE id = 'password'") else {
                    error = .databaseAccessFailed
                    return
                }

                let globalSalt: Data = metadataRow["item1"]
                let item2: Data = metadataRow["item2"]

                guard let decodedItem2 = try? ASN1Parser.parse(data: item2),
                      let iv = extractInitializationVector(from: decodedItem2),
                      let decryptedItem2 = aesDecrypt(tlv: decodedItem2, iv: iv, globalSalt: globalSalt, primaryPassword: primaryPassword) else {
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

                key = aesDecrypt(tlv: decodedA11, iv: finalIV, globalSalt: globalSalt, primaryPassword: primaryPassword)
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
    
    private func aesDecrypt(tlv: ASN1Parser.Node,
                            iv: Data,
                            globalSalt: Data,
                            primaryPassword: String) -> Data? {
        guard let data = extractCiphertext(from: tlv),
              let entrySalt = extractEntrySalt(from: tlv),
              let iterationCount = extractIterationCount(from: tlv),
              let keyLength = extractKeyLength(from: tlv) else { return nil }

        assert(keyLength == 32)

        let passwordData = globalSalt + primaryPassword.data(using: .utf8)!
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
