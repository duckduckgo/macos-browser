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
        return CommonCryptoUtilities.decryptPBKDF2(password: password,
                                                   salt: "saltysalt".data(using: .utf8)!,
                                                   keyByteCount: 16,
                                                   rounds: 1003,
                                                   kdf: .sha1)
    }

    // Step 3: Decrypt password values from the credential database.
    private func decrypt(passwordData: Data, with key: Data) -> String? {
        let trimmedPasswordData = passwordData[3...]
        let iv = String(repeating: " ", count: 16).data(using: .utf8)!

        guard let decrypted = CommonCryptoUtilities.decryptAESCBC(data: trimmedPasswordData, key: key, iv: iv) else {
            return nil
        }

        return String(data: decrypted, encoding: .utf8)!
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

// MARK: - CommonCrypto Utilities

struct CommonCryptoUtilities {

    enum KDF {
        case sha1
        case sha256
    }

    static func decryptPBKDF2(password: String, salt: Data, keyByteCount: Int, rounds: Int, kdf: KDF) -> Data? {
        // TODO: Fix Chrome import, which used to rely on .utf8 here
        guard let passwordData = Data(base64Encoded: password) else { return nil }

        var derivedKeyData = Data(repeating: 0, count: keyByteCount)
        let derivedCount = derivedKeyData.count

        let derivationStatus: OSStatus = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            let derivedKeyRawBytes = derivedKeyBytes.bindMemory(to: UInt8.self).baseAddress

            let keyDerivationAlgorithm: CCPBKDFAlgorithm

            switch kdf {
            case .sha1: keyDerivationAlgorithm = CCPBKDFAlgorithm(kCCPRFHmacAlgSHA1)
            case .sha256: keyDerivationAlgorithm = CCPBKDFAlgorithm(kCCPRFHmacAlgSHA256)
            }

            return salt.withUnsafeBytes { saltBytes in
                let rawBytes = saltBytes.bindMemory(to: UInt8.self).baseAddress
                return CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    password,
                    passwordData.count,
                    rawBytes,
                    salt.count,
                    keyDerivationAlgorithm,
                    UInt32(rounds),
                    derivedKeyRawBytes,
                    derivedCount)
            }
        }

        return derivationStatus == kCCSuccess ? derivedKeyData : nil
    }

    static func decryptAESCBC(data: Data, key: Data, iv: Data) -> Data? {
        var outLength = Int(0)
        var outBytes = [UInt8](repeating: 0, count: data.count)
        var status: CCCryptorStatus = CCCryptorStatus(kCCSuccess)

        data.withUnsafeBytes { dataBytes in
            let dataRawBytes = dataBytes.bindMemory(to: UInt8.self).baseAddress

            iv.withUnsafeBytes { ivBytes in
                let ivRawBytes = ivBytes.bindMemory(to: UInt8.self).baseAddress

                key.withUnsafeBytes { keyBytes in
                    let keyRawBytes = keyBytes.bindMemory(to: UInt8.self).baseAddress

                    status = CCCrypt(CCOperation(kCCDecrypt),
                                     CCAlgorithm(kCCAlgorithmAES128),
                                     CCOptions(kCCOptionPKCS7Padding),
                                     keyRawBytes,
                                     key.count,
                                     ivRawBytes,
                                     dataRawBytes,
                                     data.count,
                                     &outBytes,
                                     outBytes.count,
                                     &outLength)
                }
            }
        }

        guard status == kCCSuccess else {
            return nil
        }

        return Data(bytes: &outBytes, count: outLength)
    }

    static func decrypt3DES(data: Data, key: Data, iv: Data) -> Data? {
        var outLength = Int(0)
        var outBytes = [UInt8](repeating: 0, count: data.count + kCCBlockSize3DES)
        var status: CCCryptorStatus = CCCryptorStatus(kCCSuccess)

        data.withUnsafeBytes { dataBytes in
            let dataRawBytes = dataBytes.bindMemory(to: UInt8.self).baseAddress

            iv.withUnsafeBytes { ivBytes in
                let ivRawBytes = ivBytes.bindMemory(to: UInt8.self).baseAddress

                key.withUnsafeBytes { keyBytes in
                    let keyRawBytes = keyBytes.bindMemory(to: UInt8.self).baseAddress

                    status = CCCrypt(CCOperation(kCCDecrypt),
                                     CCAlgorithm(kCCAlgorithm3DES),
                                     CCOptions(kCCOptionPKCS7Padding),
                                     keyRawBytes,
                                     key.count,
                                     ivRawBytes,
                                     dataRawBytes,
                                     data.count,
                                     &outBytes,
                                     outBytes.count + kCCBlockSize3DES,
                                     &outLength)
                }
            }
        }

        guard status == kCCSuccess else {
            return nil
        }

        return Data(bytes: &outBytes, count: outLength)
    }

}
