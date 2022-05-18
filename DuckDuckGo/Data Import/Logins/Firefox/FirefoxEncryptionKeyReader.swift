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

    func getEncryptionKey(key3DatabaseURL: URL, primaryPassword: String) -> Result<Data, FirefoxLoginReader.ImportError>
    func getEncryptionKey(key4DatabaseURL: URL, primaryPassword: String) -> Result<Data, FirefoxLoginReader.ImportError>

}

// swiftlint:disable:next type_body_length
final class FirefoxEncryptionKeyReader: FirefoxEncryptionKeyReading {
    
    func getEncryptionKey(key3DatabaseURL: URL, primaryPassword: String) -> Result<Data, FirefoxLoginReader.ImportError> {
        guard let result = FirefoxBerkeleyDatabaseReader.readDatabase(key3DatabaseURL.path) else {
            return .failure(.databaseAccessFailed)
        }
        
        guard let globalSalt = result["global-salt"],
              let asnData = result["data"]?[4...] else { // Drop the first 4 bytes, they aren't required for decryption and can be ignored
            return .failure(.decryptionFailed)
        }
        
        // Part 1: Take the data from the database and decrypt it.
        
        guard let decodedASNData = try? ASN1Parser.parse(data: asnData),
              let entrySalt = extractKey3EntrySalt(from: decodedASNData),
              let ciphertext = extractCiphertext(from: decodedASNData)else {
            return .failure(.decryptionFailed)
        }
        
        guard let decryptedData = tripleDesDecrypt(ciphertext: ciphertext,
                                                   globalSalt: globalSalt,
                                                   entrySalt: entrySalt,
                                                   primaryPassword: primaryPassword) else {
            return .failure(.decryptionFailed)
        }
        
        // Part 2: Take the decrypted ASN1 data, parse it, and extract the key.
        
        guard let decryptedASNData = try? ASN1Parser.parse(data: decryptedData) else {
            return .failure(.decryptionFailed)
        }
        
        guard let extractedASNData = extractKey3DecryptedASNData(from: decryptedASNData) else {
            return .failure(.decryptionFailed)
        }
        
        guard let keyContainerASNData = try? ASN1Parser.parse(data: extractedASNData) else {
            return .failure(.decryptionFailed)
        }
        
        guard let key = extractKey3Key(from: keyContainerASNData) else {
            return .failure(.decryptionFailed)
        }
        
        return .success(key)
    }
    
    // swiftlint:disable:next function_body_length
    func getEncryptionKey(key4DatabaseURL: URL, primaryPassword: String) -> Result<Data, FirefoxLoginReader.ImportError> {
        let temporaryFileHandler = TemporaryFileHandler(fileURL: key4DatabaseURL)
        
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

    // MARK: - Key3 Database Parsing
    
    private func extractKey3EntrySalt(from tlv: ASN1Parser.Node) -> Data? {
        guard case let .sequence(outerSequence) = tlv else {
            return nil
        }

        let firstSequence = outerSequence[0]
        
        guard case let .sequence(secondSequence) = firstSequence else {
            return nil
        }
        
        let penultimateSequence = secondSequence[1]
        
        guard case let .sequence(finalSequence) = penultimateSequence else {
            return nil
        }
        
        let octetString = finalSequence[0]
        
        guard case let .octetString(data: data) = octetString else {
            return nil
        }
        
        return data
    }
    
    private func extractKey3DecryptedASNData(from node: ASN1Parser.Node) -> Data? {
        guard case let .sequence(outerSequence) = node else {
            return nil
        }
        
        let octetString = outerSequence[2]
        
        guard case let .octetString(data: data) = octetString else {
            return nil
        }
        
        return data
    }
    
    private func extractKey3Key(from node: ASN1Parser.Node) -> Data? {
        guard case let .sequence(outerSequence) = node else {
            return nil
        }
        
        let integer = outerSequence[3]
        
        guard case let .integer(data: data) = integer else {
            return nil
        }
        
        return data
    }
    
    /// HP = SHA1( global-salt | PrimaryPassword )
    /// CHP = SHA1( HP | ES )
    /// k1 = HMAC-SHA1( key=CHP, msg= (PES | ES) )
    /// tk = HMAC-SHA1( CHP, PES )
    /// k2 = HMAC-SHA1( CHP, tk | ES )
    /// k = k1 | k2
    /// key = k[:24] # first 24 bytes (EDE keying, also called 3TDEA)
    /// iv = k[-8:]  # last 8 bytes
    /// clearText = DES3.new(key, DES3.CBC, iv).decrypt(cipherText)
    private func tripleDesDecrypt(ciphertext: Data, globalSalt: Data, entrySalt: Data, primaryPassword: String) -> Data? {
        guard let primaryPasswordData = primaryPassword.data(using: .utf8), let pes = NSMutableData(length: 20) else {
            return nil
        }

        entrySalt.withUnsafeBytes { rawBufferPointer in
            let pointer = rawBufferPointer.baseAddress!
            pes.replaceBytes(in: NSRange(location: 0, length: entrySalt.count), withBytes: pointer)
        }
        
        let hp = SHA.from(data: globalSalt + primaryPasswordData)
        let chp = SHA.from(data: hp + entrySalt)
        let k1 = HMAC.digestSHA1(key: chp, message: (pes + entrySalt))
        let tk = HMAC.digestSHA1(key: chp, message: pes as Data)
        let k2 = HMAC.digestSHA1(key: chp, message: (tk + entrySalt))
        let k = k1 + k2

        let key = k.prefix(24)
        let iv = k.suffix(8)
        
        return Cryptography.decrypt3DES(data: ciphertext, key: key, iv: iv)
    }

    // MARK: - Key4 Database Parsing
    
    private func extractKey4EntrySalt(from tlv: ASN1Parser.Node) -> Data? {
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
    
    private func aesDecrypt(tlv: ASN1Parser.Node,
                            iv: Data,
                            globalSalt: Data,
                            primaryPassword: String) -> Data? {
        guard let data = extractCiphertext(from: tlv),
              let entrySalt = extractKey4EntrySalt(from: tlv),
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
