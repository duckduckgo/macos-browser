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
        
        guard let decryptedASNData = try? ASN1Parser.parse(data: decryptedData),
              let extractedASNData = extractKey3DecryptedASNData(from: decryptedASNData),
              let keyContainerASNData = try? ASN1Parser.parse(data: extractedASNData),
              let key = extractKey3Key(from: keyContainerASNData) else {
            return .failure(.decryptionFailed)
        }
        
        return .success(key)
    }
    
    func getEncryptionKey(key4DatabaseURL: URL, primaryPassword: String) -> Result<Data, FirefoxLoginReader.ImportError> {
        do {
            return try key4DatabaseURL.withTemporaryFile { temporaryDatabaseURL in
                do {
                    if let data = try getKey(key4DatabaseURL: temporaryDatabaseURL, primaryPassword: primaryPassword) {
                        return .success(data)
                    } else {
                        return .failure(.databaseAccessFailed)
                    }
                } catch {
                    if let importError = error as? FirefoxLoginReader.ImportError {
                        return .failure(importError)
                    } else {
                        return .failure(.couldNotGetDecryptionKey)
                    }
                }
            }
        } catch {
            return .failure(.failedToTemporarilyCopyFile)
        }
    }
    
    private func getKey(key4DatabaseURL databaseURL: URL, primaryPassword: String) throws -> Data? {
        let queue = try DatabaseQueue(path: databaseURL.path)

        return try queue.read { database in
            guard let metadataRow = try? Row.fetchOne(database, sql: "SELECT item1, item2 FROM metadata WHERE id = 'password'") else {
                throw FirefoxLoginReader.ImportError.databaseAccessFailed
            }

            let globalSalt: Data = metadataRow["item1"]
            let item2: Data = metadataRow["item2"]

            guard let decodedASNData = try? ASN1Parser.parse(data: item2) else {
                throw FirefoxLoginReader.ImportError.decryptionFailed
            }
            
            if let tripleDesData = try extractKeyUsing3DES(from: decodedASNData,
                                                           globalSalt: globalSalt,
                                                           primaryPassword: primaryPassword,
                                                           database: database) {
                return tripleDesData
            } else {
                return try extractKeyUsingAES(from: decodedASNData,
                                              globalSalt: globalSalt,
                                              primaryPassword: primaryPassword,
                                              database: database)
            }
        }
    }

    // MARK: - Key3 Database Parsing
    
    private func extractKey3EntrySalt(from tlv: ASN1Parser.Node) -> Data? {
        guard case let .sequence(outerSequence) = tlv,
              let firstSequence = outerSequence[safe: 0],
              case let .sequence(secondSequence) = firstSequence,
              let penultimateSequence = secondSequence[safe: 1],
              case let .sequence(finalSequence) = penultimateSequence,
              let octetString = finalSequence[safe: 0],
              case let .octetString(data: data) = octetString else {
            return nil
        }
        
        return data
    }
    
    private func extractKey3DecryptedASNData(from node: ASN1Parser.Node) -> Data? {
        guard case let .sequence(outerSequence) = node,
              let octetString = outerSequence[safe: 2],
              case let .octetString(data: data) = octetString else {
            return nil
        }
        
        return data
    }
    
    private func extractKey3Key(from node: ASN1Parser.Node) -> Data? {
        guard case let .sequence(outerSequence) = node,
              let integer = outerSequence[safe: 3],
              case let .integer(data: data) = integer else {
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
        let k1 = calculateHMAC(key: chp, message: (pes + entrySalt))
        let tk = calculateHMAC(key: chp, message: pes as Data)
        let k2 = calculateHMAC(key: chp, message: (tk + entrySalt))
        let k = k1 + k2

        let key = k.prefix(24)
        let iv = k.suffix(8)
        
        return Cryptography.decrypt3DES(data: ciphertext, key: key, iv: iv)
    }
    
    private func calculateHMAC(key: Data, message: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let authentication = CryptoKit.HMAC<Insecure.SHA1>.authenticationCode(for: message, using: symmetricKey)
        
        return Data(authentication)
    }

    // MARK: - Key4 Database Parsing
    
    private func extractKey4EntrySalt(from tlv: ASN1Parser.Node) -> Data? {
        guard case let .sequence(values1) = tlv,
              let firstValue = values1[safe: 0],
              case let .sequence(values2) = firstValue,
              let secondValue = values2[safe: 1],
              case let .sequence(values3) = secondValue,
              let thirdValue = values3[safe: 0],
              case let .sequence(values4) = thirdValue,
              let fourthValue = values4[safe: 1],
              case let .sequence(values5) = fourthValue,
              let fifthValue = values5[safe: 0],
              case let .octetString(data: data) = fifthValue else {
            return nil
        }

        return data
    }

    private func extractIterationCount(from tlv: ASN1Parser.Node) -> Int? {
        guard case let .sequence(values1) = tlv,
              let firstValue = values1[safe: 0],
              case let .sequence(values2) = firstValue,
              let secondValue = values2[safe: 1],
              case let .sequence(values3) = secondValue,
              let thirdValue = values3[safe: 0],
              case let .sequence(values4) = thirdValue,
              let fourthValue = values4[safe: 1],
              case let .sequence(values5) = fourthValue,
              let fifthValue = values5[safe: 1],
              case let .integer(data: data) = fifthValue else {
            return nil
        }

        return data.integer
    }

    private func extractKeyLength(from tlv: ASN1Parser.Node) -> Int? {
        guard case let .sequence(values1) = tlv,
              let firstValue = values1[safe: 0],
              case let .sequence(values2) = firstValue,
              let secondValue = values2[safe: 1],
              case let .sequence(values3) = secondValue,
              let thirdValue = values3[safe: 0],
              case let .sequence(values4) = thirdValue,
              let fourthValue = values4[safe: 1],
              case let .sequence(values5) = fourthValue,
              let fifthValue = values5[safe: 2],
              case let .integer(data: data) = fifthValue else {
            return nil
        }

        return data.integer
    }

    private func extractInitializationVector(from tlv: ASN1Parser.Node) -> Data? {
        guard case let .sequence(values1) = tlv,
              let firstValue = values1[safe: 0],
              case let .sequence(values2) = firstValue,
              let secondValue = values2[safe: 1],
              case let .sequence(values3) = secondValue,
              let thirdValue = values3[safe: 1],
              case let .sequence(values4) = thirdValue,
              let fourthValue = values4[safe: 1],
              case let .octetString(data: data) = fourthValue else {
            return nil
        }

        return data
    }

    private func extractCiphertext(from tlv: ASN1Parser.Node) -> Data? {
        guard case let .sequence(values) = tlv,
              case let .octetString(data: data) = values[safe: 1] else {
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
              let keyLength = extractKeyLength(from: tlv),
              let primaryPasswordData = primaryPassword.data(using: .utf8) else { return nil }

        assert(keyLength == 32)

        let passwordData = globalSalt + primaryPasswordData
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
    
    // MARK: - ASN Key Extraction
    
    private func extractKeyUsing3DES(from node: ASN1Parser.Node, globalSalt: Data, primaryPassword: String, database: GRDB.Database) throws -> Data? {
        guard let entrySalt = extractKey3EntrySalt(from: node), let passwordCheckCiphertext = extractCiphertext(from: node) else {
            return nil
        }
        
        guard let decryptedCiphertext = tripleDesDecrypt(ciphertext: passwordCheckCiphertext,
                                                         globalSalt: globalSalt,
                                                         entrySalt: entrySalt,
                                                         primaryPassword: primaryPassword) else {
            return nil
        }
        
        let passwordCheckString = String(data: decryptedCiphertext, encoding: .utf8)
        
        if passwordCheckString != "password-check" {
            throw FirefoxLoginReader.ImportError.requiresPrimaryPassword
        }
        
        guard let nssPrivateRow = try? Row.fetchOne(database, sql: "SELECT a11, a102 FROM nssPrivate;") else {
            throw FirefoxLoginReader.ImportError.decryptionFailed
        }

        let a11: Data = nssPrivateRow["a11"]
        let a102: Data = nssPrivateRow["a102"]
        
        assert(a102 == Data([248, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]))
        
        guard let decodedA11 = try? ASN1Parser.parse(data: a11),
              let entrySalt = extractKey3EntrySalt(from: decodedA11),
              let ciphertext = extractCiphertext(from: decodedA11) else {
            throw FirefoxLoginReader.ImportError.decryptionFailed
        }

        return tripleDesDecrypt(ciphertext: ciphertext, globalSalt: globalSalt, entrySalt: entrySalt, primaryPassword: primaryPassword)
    }
    
    private func extractKeyUsingAES(from node: ASN1Parser.Node, globalSalt: Data, primaryPassword: String, database: GRDB.Database) throws -> Data? {
        guard let iv = extractInitializationVector(from: node),
              let decryptedItem2 = aesDecrypt(tlv: node, iv: iv, globalSalt: globalSalt, primaryPassword: primaryPassword) else {
            throw FirefoxLoginReader.ImportError.decryptionFailed
        }

        let passwordCheckString = String(data: decryptedItem2, encoding: .utf8)

        // The password check is technically "password-check\x02\x02", it's converted to UTF-8 and checked here for simplicity
        if passwordCheckString != "password-check" {
            throw FirefoxLoginReader.ImportError.requiresPrimaryPassword
        }

        guard let nssPrivateRow = try? Row.fetchOne(database, sql: "SELECT a11, a102 FROM nssPrivate;") else {
            throw FirefoxLoginReader.ImportError.decryptionFailed
        }

        let a11: Data = nssPrivateRow["a11"]
        let a102: Data = nssPrivateRow["a102"]

        assert(a102 == Data([248, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]))

        guard let decodedA11 = try? ASN1Parser.parse(data: a11), let finalIV = extractInitializationVector(from: decodedA11) else {
            throw FirefoxLoginReader.ImportError.decryptionFailed
        }

        return aesDecrypt(tlv: decodedA11, iv: finalIV, globalSalt: globalSalt, primaryPassword: primaryPassword)
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
