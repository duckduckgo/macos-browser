//
//  EncryptionKeyStore.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import CryptoKit
import PixelKit

enum EncryptionKeyStoreError: Error, ErrorWithPixelParameters {
    case storageFailed(OSStatus)
    case readFailed(OSStatus)
    case deletionFailed(OSStatus)
    case cannotTransformDataToString(OSStatus)
    case cannotTransfrotmStringToBase64Data(OSStatus)

    var errorParameters: [String: String] {
        switch self {
        case .storageFailed(let status):
            return [PixelKit.Parameters.keychainErrorCode: "\(status)"]
        case .readFailed(let status):
            return [PixelKit.Parameters.keychainErrorCode: "\(status)"]
        case .deletionFailed(let status):
            return [PixelKit.Parameters.keychainErrorCode: "\(status)"]
        case .cannotTransformDataToString(let status):
            return [PixelKit.Parameters.keychainErrorCode: "\(status)"]
        case .cannotTransfrotmStringToBase64Data(let status):
            return [PixelKit.Parameters.keychainErrorCode: "\(status)"]
        }
    }
}

final class EncryptionKeyStore: EncryptionKeyStoring {

    enum Constants {
#if APPSTORE
        static let encryptionKeyAccount = "com.duckduckgo.mobile.ios"
#else
        static let encryptionKeyAccount = "com.duckduckgo.macos.browser"
#endif
        static let encryptionKeyService = "DuckDuckGo Privacy Browser Data Encryption Key"

        static let encryptionKeyServiceBase64 = "DuckDuckGo Privacy Browser Encryption Key v2"
    }

    private let generator: EncryptionKeyGenerating
    private let account: String

    private var defaultKeychainQueryAttributes: [String: Any] {
        return [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account
        ] as [String: Any]
    }

    init(generator: EncryptionKeyGenerating, account: String = Constants.encryptionKeyAccount) {
        self.generator = generator
        self.account = account
    }

    convenience init() {
        self.init(generator: EncryptionKeyGenerator())
    }

    // MARK: - Keychain

    func store(key: SymmetricKey) throws {
         let attributes: [String: Any] = [
             kSecClass as String: kSecClassGenericPassword,
             kSecAttrAccount as String: account,
             kSecValueData as String: key.dataRepresentation.base64EncodedString(),
             kSecAttrService as String: Constants.encryptionKeyServiceBase64,
             kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
         ]

         // Add the login item to the keychain
         let status = SecItemAdd(attributes as CFDictionary, nil)

         guard status == errSecSuccess else {
             throw EncryptionKeyStoreError.storageFailed(status)
         }
     }

    func readKey() throws -> SymmetricKey {
        /// Needed to change how we save the key
        /// Checks if the base64 non iCloud key already exist
        /// if so we return
        if let key = try? readKeyFromKeychain(account: account, format: .base64) {
            return key
        }
        /// If the base64 key does not exist we check if we have the legacy key
        /// if so we store it as base64 local item key
        if let key = try readKeyFromKeychain(account: account, format: .raw) {
            try store(key: key)
        }

        /// We try again to retrieve the base64 non iCloud key
        /// if so we return the key
        /// otherwise we generate a new one and store it
        if let key = try readKeyFromKeychain(account: account, format: .base64) {
            return key
        } else {
            let generatedKey = generator.randomKey()
            try store(key: generatedKey)
            return generatedKey
        }
    }

    func deleteKey() throws {
        let status = SecItemDelete(defaultKeychainQueryAttributes as CFDictionary)

        switch status {
        case errSecItemNotFound, errSecSuccess: break
        default:
            throw EncryptionKeyStoreError.deletionFailed(status)
        }
    }

    // MARK: - Private

    private enum KeyFormat {
        case raw
        case base64
    }

    private func readKeyFromKeychain(account: String, format: KeyFormat) throws -> SymmetricKey? {
        var query = defaultKeychainQueryAttributes
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        switch format {
        case .raw:
            query[kSecAttrService as String] = Constants.encryptionKeyService
        case .base64:
            query[kSecAttrService as String] = Constants.encryptionKeyServiceBase64
        }
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw EncryptionKeyStoreError.readFailed(status)
            }

            let finalData: Data
            switch format {
            case .raw:
                finalData = data
            case .base64:
                guard let base64String = String(data: data, encoding: .utf8) else {
                    throw EncryptionKeyStoreError.cannotTransformDataToString(status)
                }
                guard let keyData = Data(base64Encoded: base64String) else {
                    throw EncryptionKeyStoreError.cannotTransfrotmStringToBase64Data(status)
                }
                finalData = keyData
            }
            return SymmetricKey(data: finalData)
        case errSecItemNotFound:
            return nil
        default:
            throw EncryptionKeyStoreError.readFailed(status)
        }
    }
}
