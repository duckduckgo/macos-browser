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

enum EncryptionKeyStoreError: Error, ErrorWithParameters {
    case storageFailed(OSStatus)
    case readFailed(OSStatus)
    case deletionFailed(OSStatus)
    case cannotTrasformDataToString(OSStatus)
    case cannotTrasfrotmStringToBase64Data(OSStatus)

    var errorParameters: [String: String] {
        switch self {
        case .storageFailed(let status):
            return [Pixel.Parameters.keychainErrorCode: "\(status)"]
        case .readFailed(let status):
            return [Pixel.Parameters.keychainErrorCode: "\(status)"]
        case .deletionFailed(let status):
            return [Pixel.Parameters.keychainErrorCode: "\(status)"]
        case .cannotTrasformDataToString(let status):
            return [Pixel.Parameters.keychainErrorCode: "\(status)"]
        case .cannotTrasfrotmStringToBase64Data(let status):
            return [Pixel.Parameters.keychainErrorCode: "\(status)"]
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
    }

    private let generator: EncryptionKeyGenerating
    private let account: String

    /// Needed to change how we save the key to be removed in the future
    @UserDefaultsWrapper(key: .isEncryptionKeyResaved, defaultValue: false)
    private var isEncryptionKeyResaved: Bool

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
         var attributes: [String: Any] = [
             kSecClass as String: kSecClassGenericPassword,
             kSecAttrAccount as String: account,
             kSecValueData as String: key.dataRepresentation.base64EncodedString(),
             kSecAttrService as String: Constants.encryptionKeyService,
             kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
         ]

         // Add the login item to the keychain
         let status = SecItemAdd(attributes as CFDictionary, nil)

         guard status == errSecSuccess else {
             throw EncryptionKeyStoreError.storageFailed(status)
         }
        /// Needed to change how we save the key to be removed in the future
        isEncryptionKeyResaved = true
     }

    func readKey() throws -> SymmetricKey {
        /// Needed to change how we save the key to be removed in the future
        if !isEncryptionKeyResaved {
            try resaveKey()
        }

        if let key = try readBase64KeyFromKeychain(account: account) {
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

    /// To be removed in the future
    private func resaveKey() throws {
        if let key = try readKeyFromKeychain(account: account) {
            try deleteKey()
            try store(key: key)
        }
    }

    /// Deprecated (To be removed in the future)
    private func readKeyFromKeychain(account: String) throws -> SymmetricKey? {
        var query = defaultKeychainQueryAttributes
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw EncryptionKeyStoreError.readFailed(status)
            }

            return SymmetricKey(data: data)
        case errSecItemNotFound:
            return nil
        default:
            throw EncryptionKeyStoreError.readFailed(status)
        }
    }

    private func readBase64KeyFromKeychain(account: String) throws -> SymmetricKey? {
        var query = defaultKeychainQueryAttributes
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw EncryptionKeyStoreError.readFailed(status)
            }
            guard let base64String = String(data: data, encoding: .utf8) else {
                throw EncryptionKeyStoreError.cannotTrasformDataToString(status)
            }
            guard let keyData = Data(base64Encoded: base64String) else {
                throw EncryptionKeyStoreError.cannotTrasfrotmStringToBase64Data(status)
            }

            return SymmetricKey(data: keyData)
        case errSecItemNotFound:
            return nil
        default:
            throw EncryptionKeyStoreError.readFailed(status)
        }
    }

}
