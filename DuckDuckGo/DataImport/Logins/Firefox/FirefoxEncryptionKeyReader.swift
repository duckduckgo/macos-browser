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
import BrowserServicesKit

protocol FirefoxEncryptionKeyReading {

    func getEncryptionKey(key3DatabaseURL: URL, primaryPassword: String) -> DataImportResult<Data>
    func getEncryptionKey(key4DatabaseURL: URL, primaryPassword: String) -> DataImportResult<Data>

}

final class FirefoxEncryptionKeyReader: FirefoxEncryptionKeyReading {

    typealias KeyReaderFileLineError = FileLineError<FirefoxEncryptionKeyReader>

    private enum Constants {
        static let passwordCheckStr = "password-check"
        static let passwordCheckLength = 16
        static let key3length = 24
    }

    init() {
    }

    func getEncryptionKey(key3DatabaseURL: URL, primaryPassword: String) -> DataImportResult<Data> {
        var operationType: FirefoxLoginReader.ImportError.OperationType = .key3readerStage1
        do {
            let data = try getEncryptionKey(key3DatabaseURL: key3DatabaseURL, primaryPassword: primaryPassword, operationType: &operationType)
            return .success(data)
        } catch let error as FirefoxLoginReader.ImportError {
            return .failure(error)
        } catch {
            return .failure(FirefoxLoginReader.ImportError(type: operationType, underlyingError: error))
        }
    }

    private func getEncryptionKey(key3DatabaseURL: URL, primaryPassword: String, operationType: inout FirefoxLoginReader.ImportError.OperationType) throws -> Data {

        let result = try FirefoxBerkeleyDatabaseReader.readDatabase(at: key3DatabaseURL.path)

        let globalSalt = try result["global-salt"] ?? { throw KeyReaderFileLineError() }()
        var asnData = try result["data"] ?? { throw KeyReaderFileLineError() }()
        guard asnData.count > 4 else { throw KeyReaderFileLineError() }
        asnData = asnData[4...] // Drop the first 4 bytes, they aren't required for decryption and can be ignored

        // decrypted password-check should match "password-check"
        if let passwordCheck = result[Constants.passwordCheckStr] {
            guard passwordCheck.count > Constants.passwordCheckLength else { throw KeyReaderFileLineError() }
            let entrySaltLength = Int(passwordCheck[1])
            guard entrySaltLength > 0 else { throw KeyReaderFileLineError() }
            guard passwordCheck.count >= Constants.passwordCheckLength + 3 + entrySaltLength else { throw KeyReaderFileLineError() }
            let entrySalt = passwordCheck[3..<(entrySaltLength + 3)]
            let passwordCheckCiphertext = passwordCheck[(passwordCheck.count - Constants.passwordCheckLength)...]

            do {
                let decryptedCiphertext = try tripleDesDecrypt(ciphertext: passwordCheckCiphertext,
                                                               globalSalt: globalSalt,
                                                               entrySalt: entrySalt,
                                                               primaryPassword: primaryPassword)
                guard decryptedCiphertext.utf8String() == Constants.passwordCheckStr else { throw KeyReaderFileLineError() }
            } catch {
                throw FirefoxLoginReader.ImportError(type: .requiresPrimaryPassword, underlyingError: nil)
            }
        }

        // Part 1: Take the data from the database and decrypt it.

        let decodedASNData = try ASN1Parser.parse(data: asnData)
        let entrySalt = try extractKey3EntrySalt(from: decodedASNData)
        let ciphertext = try extractCiphertext(from: decodedASNData)

        let decryptedData = try tripleDesDecrypt(ciphertext: ciphertext,
                                                 globalSalt: globalSalt,
                                                 entrySalt: entrySalt,
                                                 primaryPassword: primaryPassword)

        // Part 2: Take the decrypted ASN1 data, parse it, and extract the key.
        operationType = .key3readerStage2
        let decryptedASNData = try ASN1Parser.parse(data: decryptedData)
        let extractedASNData = try extractKey3DecryptedASNData(from: decryptedASNData)

        operationType = .key3readerStage3
        let keyContainerASNData = try ASN1Parser.parse(data: extractedASNData)
        let key = try extractKey3Key(from: keyContainerASNData)

        return key
    }

    func getEncryptionKey(key4DatabaseURL: URL, primaryPassword: String) -> DataImportResult<Data> {
        var operationType: FirefoxLoginReader.ImportError.OperationType = .key4readerStage1
        do {
            return try key4DatabaseURL.withTemporaryFile { temporaryDatabaseURL in
                let data = try getKey(key4DatabaseURL: temporaryDatabaseURL, primaryPassword: primaryPassword, operationType: &operationType)
                return .success(data)
            }
        } catch let error as FirefoxLoginReader.ImportError {
            return .failure(error)
        } catch {
            return .failure(FirefoxLoginReader.ImportError(type: operationType, underlyingError: error))
        }
    }

    private func getKey(key4DatabaseURL databaseURL: URL, primaryPassword: String, operationType: inout FirefoxLoginReader.ImportError.OperationType) throws -> Data {
        let queue = try DatabaseQueue(path: databaseURL.path)

        return try queue.read { database in
            guard let metadataRow = try MetadataRow.fetchOne(database, sql: "SELECT item1, item2 FROM metadata WHERE id = 'password'") else { throw KeyReaderFileLineError() }

            let decodedASNData = try ASN1Parser.parse(data: metadataRow.item2)

            operationType = .key4readerStage2
            if let tripleDesData = try extractKeyUsing3DES(from: decodedASNData,
                                                           globalSalt: metadataRow.globalSalt,
                                                           primaryPassword: primaryPassword,
                                                           database: database) {

                return tripleDesData
            }

            operationType = .key4readerStage3
            return try extractKeyUsingAES(from: decodedASNData,
                                          globalSalt: metadataRow.globalSalt,
                                          primaryPassword: primaryPassword,
                                          database: database)
        }
    }

    fileprivate struct MetadataRow: FetchableRecord {
        let globalSalt: Data
        let item2: Data

        init(row: Row) throws {
            globalSalt = try row["item1"] ?? { throw FetchableRecordError<MetadataRow>(column: 0) }()
            item2 = try row["item2"] ?? { throw FetchableRecordError<MetadataRow>(column: 1) }()
        }
    }

    // MARK: - Key3 Database Parsing

    private func extractKey3EntrySalt(from tlv: ASN1Parser.Node) throws -> Data {
        var lineError = KeyReaderFileLineError.nextLine()
        guard case let .sequence(outerSequence) = tlv, lineError.next(),
              let firstSequence = outerSequence[safe: 0], lineError.next(),
              case let .sequence(secondSequence) = firstSequence, lineError.next(),
              let penultimateSequence = secondSequence[safe: 1], lineError.next(),
              case let .sequence(finalSequence) = penultimateSequence, lineError.next(),
              let octetString = finalSequence[safe: 0], lineError.next(),
              case let .octetString(data: data) = octetString else {
            throw lineError
        }

        return data
    }

    private func extractKey3DecryptedASNData(from node: ASN1Parser.Node) throws -> Data {
        var lineError = KeyReaderFileLineError.nextLine()
        guard case let .sequence(outerSequence) = node, lineError.next(),
              let octetString = outerSequence[safe: 2], lineError.next(),
              case let .octetString(data: data) = octetString else {
            throw lineError
        }

        return data
    }

    private func extractKey3Key(from node: ASN1Parser.Node) throws -> Data {
        var lineError = KeyReaderFileLineError.nextLine()
        guard case let .sequence(outerSequence) = node, lineError.next(),
              let integer = outerSequence[safe: 3], lineError.next(),
              case let .integer(data: data) = integer, lineError.next(),
              data.count >= Constants.key3length else {
            throw lineError
        }

        return data.dropFirst(data.count - Constants.key3length)
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
    private func tripleDesDecrypt(ciphertext: Data, globalSalt: Data, entrySalt: Data, primaryPassword: String) throws -> Data {
        let primaryPasswordData = primaryPassword.utf8data
        var pes = Data(count: 20)
        let len = min(entrySalt.count, pes.count)
        pes.replaceSubrange(0..<len, with: entrySalt[entrySalt.startIndex..<entrySalt.index(entrySalt.startIndex, offsetBy: len)])

        let hp = SHA.from(data: globalSalt + primaryPasswordData)
        let chp = SHA.from(data: hp + entrySalt)
        let k1 = calculateHMAC(key: chp, message: (pes + entrySalt))
        let tk = calculateHMAC(key: chp, message: pes as Data)
        let k2 = calculateHMAC(key: chp, message: (tk + entrySalt))
        let k = k1 + k2

        let key = k.prefix(Constants.key3length)
        let iv = k.suffix(8)

        return try Cryptography.decrypt3DES(data: ciphertext, key: key, iv: iv)
    }

    private func calculateHMAC(key: Data, message: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let authentication = CryptoKit.HMAC<Insecure.SHA1>.authenticationCode(for: message, using: symmetricKey)

        return Data(authentication)
    }

    // MARK: - Key4 Database Parsing

    private func extractKey4EntrySalt(from tlv: ASN1Parser.Node) throws -> Data {
        var lineError = KeyReaderFileLineError.nextLine()
        guard case let .sequence(values1) = tlv, lineError.next(),
              let firstValue = values1[safe: 0], lineError.next(),
              case let .sequence(values2) = firstValue, lineError.next(),
              let secondValue = values2[safe: 1], lineError.next(),
              case let .sequence(values3) = secondValue, lineError.next(),
              let thirdValue = values3[safe: 0], lineError.next(),
              case let .sequence(values4) = thirdValue, lineError.next(),
              let fourthValue = values4[safe: 1], lineError.next(),
              case let .sequence(values5) = fourthValue, lineError.next(),
              let fifthValue = values5[safe: 0], lineError.next(),
              case let .octetString(data: data) = fifthValue else {
            throw lineError
        }

        return data
    }

    private func extractIterationCount(from tlv: ASN1Parser.Node) throws -> Int {
        var lineError = KeyReaderFileLineError.nextLine()
        guard case let .sequence(values1) = tlv, lineError.next(),
              let firstValue = values1[safe: 0], lineError.next(),
              case let .sequence(values2) = firstValue, lineError.next(),
              let secondValue = values2[safe: 1], lineError.next(),
              case let .sequence(values3) = secondValue, lineError.next(),
              let thirdValue = values3[safe: 0], lineError.next(),
              case let .sequence(values4) = thirdValue, lineError.next(),
              let fourthValue = values4[safe: 1], lineError.next(),
              case let .sequence(values5) = fourthValue, lineError.next(),
              let fifthValue = values5[safe: 1], lineError.next(),
              case let .integer(data: data) = fifthValue else {
            throw lineError
        }

        return data.integer
    }

    private func extractKeyLength(from tlv: ASN1Parser.Node) throws -> Int {
        var lineError = KeyReaderFileLineError.nextLine()
        guard case let .sequence(values1) = tlv, lineError.next(),
              let firstValue = values1[safe: 0], lineError.next(),
              case let .sequence(values2) = firstValue, lineError.next(),
              let secondValue = values2[safe: 1], lineError.next(),
              case let .sequence(values3) = secondValue, lineError.next(),
              let thirdValue = values3[safe: 0], lineError.next(),
              case let .sequence(values4) = thirdValue, lineError.next(),
              let fourthValue = values4[safe: 1], lineError.next(),
              case let .sequence(values5) = fourthValue, lineError.next(),
              let fifthValue = values5[safe: 2], lineError.next(),
              case let .integer(data: data) = fifthValue else {
            throw lineError
        }

        return data.integer
    }

    private func extractInitializationVector(from tlv: ASN1Parser.Node) throws -> Data {
        var lineError = KeyReaderFileLineError.nextLine()
        guard case let .sequence(values1) = tlv, lineError.next(),
              let firstValue = values1[safe: 0], lineError.next(),
              case let .sequence(values2) = firstValue, lineError.next(),
              let secondValue = values2[safe: 1], lineError.next(),
              case let .sequence(values3) = secondValue, lineError.next(),
              let thirdValue = values3[safe: 1], lineError.next(),
              case let .sequence(values4) = thirdValue, lineError.next(),
              let fourthValue = values4[safe: 1], lineError.next(),
              case let .octetString(data: data) = fourthValue else {
            throw lineError
        }

        return data
    }

    private func extractCiphertext(from tlv: ASN1Parser.Node) throws -> Data {
        var lineError = KeyReaderFileLineError.nextLine()
        guard case let .sequence(values) = tlv, lineError.next(),
              case let .octetString(data: data) = values[safe: 1] else {
            throw lineError
        }

        return data
    }

    private func aesDecrypt(tlv: ASN1Parser.Node,
                            iv: Data,
                            globalSalt: Data,
                            primaryPassword: String) throws -> Data {
        let data = try extractCiphertext(from: tlv)
        let entrySalt = try extractKey4EntrySalt(from: tlv)
        let iterationCount = try extractIterationCount(from: tlv)
        let keyLength = try extractKeyLength(from: tlv)
        let primaryPasswordData = primaryPassword.utf8data

        assert(keyLength == 32)

        let passwordData = globalSalt + primaryPasswordData
        let hashData = SHA.from(data: passwordData)

        let commonCryptoKey = try Cryptography.decryptPBKDF2(password: .base64(hashData.base64EncodedString()),
                                                             salt: entrySalt,
                                                             keyByteCount: keyLength,
                                                             rounds: iterationCount,
                                                             kdf: .sha256)

        let iv = Data([4, 14]) + iv
        let decryptedData = try Cryptography.decryptAESCBC(data: data, key: commonCryptoKey.dataRepresentation, iv: iv)

        return decryptedData
    }

    // MARK: - ASN Key Extraction

    private func extractKeyUsing3DES(from node: ASN1Parser.Node, globalSalt: Data, primaryPassword: String, database: GRDB.Database) throws -> Data? {
        guard let decryptedCiphertext: Data = {
            guard let entrySalt = try? extractKey3EntrySalt(from: node),
                  let passwordCheckCiphertext = try? extractCiphertext(from: node) else { return nil }

            return try? tripleDesDecrypt(ciphertext: passwordCheckCiphertext,
                                         globalSalt: globalSalt,
                                         entrySalt: entrySalt,
                                         primaryPassword: primaryPassword)
        }() else { return nil }

        let passwordCheckString = String(data: decryptedCiphertext, encoding: .utf8)

        guard passwordCheckString == Constants.passwordCheckStr else { throw FirefoxLoginReader.ImportError(type: .requiresPrimaryPassword, underlyingError: nil) }

        guard let nssPrivateRow = try NssPrivateRow.fetchOne(database, sql: "SELECT a11, a102 FROM nssPrivate;") else { throw KeyReaderFileLineError() }

        assert(nssPrivateRow.a102 == Data([248, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]))

        let decodedA11 = try ASN1Parser.parse(data: nssPrivateRow.a11)
        let entrySalt = try extractKey3EntrySalt(from: decodedA11)
        let ciphertext = try extractCiphertext(from: decodedA11)

        let data = try tripleDesDecrypt(ciphertext: ciphertext, globalSalt: globalSalt, entrySalt: entrySalt, primaryPassword: primaryPassword)
        return data
    }

    private func extractKeyUsingAES(from node: ASN1Parser.Node, globalSalt: Data, primaryPassword: String, database: GRDB.Database) throws -> Data {
        let iv = try extractInitializationVector(from: node)
        let decryptedItem2 = try aesDecrypt(tlv: node, iv: iv, globalSalt: globalSalt, primaryPassword: primaryPassword)

        let passwordCheckString = String(data: decryptedItem2, encoding: .utf8)

        // The password check is technically "password-check\x02\x02", it's converted to UTF-8 and checked here for simplicity
        guard passwordCheckString == Constants.passwordCheckStr else { throw FirefoxLoginReader.ImportError(type: .requiresPrimaryPassword, underlyingError: nil) }

        guard let nssPrivateRow = try NssPrivateRow.fetchOne(database, sql: "SELECT a11, a102 FROM nssPrivate;") else { throw KeyReaderFileLineError() }

        assert(nssPrivateRow.a102 == Data([248, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]))

        let decodedA11 = try ASN1Parser.parse(data: nssPrivateRow.a11)
        let finalIV = try extractInitializationVector(from: decodedA11)

        return try aesDecrypt(tlv: decodedA11, iv: finalIV, globalSalt: globalSalt, primaryPassword: primaryPassword)
    }

    fileprivate struct NssPrivateRow: FetchableRecord {
        let a11: Data
        let a102: Data

        init(row: Row) throws {
            a11 = try row["a11"] ?? { throw FetchableRecordError<NssPrivateRow>(column: 0) }()
            a102 = try row["a102"] ?? { throw FetchableRecordError<NssPrivateRow>(column: 1) }()
        }
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
