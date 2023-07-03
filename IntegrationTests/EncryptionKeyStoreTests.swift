//
//  EncryptionKeyStoreTests.swift
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

import XCTest
import CryptoKit
@testable import DuckDuckGo_Privacy_Browser

final class EncryptionKeyStoreTests: XCTestCase {
    private let account = "com.duckduckgo.macos.browser.unit-test-encryption-key"
    private let generator = EncryptionKeyGenerator()

    override func setUp() {
        super.setUp()
        removeTestKeys()
        UserDefaultsWrapper<Any>.clearAll()
    }

    override func tearDown() {
        super.tearDown()
        removeTestKeys()
        UserDefaultsWrapper<Any>.clearAll()
    }

    func testStoringKeys() {
        let store = EncryptionKeyStore(generator: generator, account: account)
        let key = generator.randomKey()

        XCTAssertNoThrow(try store.store(key: key))
    }

    func testDeletingKeys() {
        let store = EncryptionKeyStore(generator: generator, account: account)
        let key = generator.randomKey()

        XCTAssertNoThrow(try store.store(key: key))
        XCTAssertNoThrow(try store.deleteKey())
    }

    func testAttemptingToDeleteKeyWhichDoesNotExist() {
        // It's fine to try and delete a key which doesn't exist, so no error should throw.
        let store = EncryptionKeyStore(generator: generator, account: account)
        XCTAssertNoThrow(try store.deleteKey())
    }

    func testReadingKeysWithNoneInTheKeychainGeneratesNewKey() {
        let mockGenerator = MockEncryptionKeyGenerator()
        let store = EncryptionKeyStore(generator: mockGenerator, account: account)

        let firstReadKey = try? store.readKey()
        let secondReadKey = try? store.readKey()

        XCTAssertNotNil(firstReadKey)
        XCTAssertNotNil(secondReadKey)
        XCTAssertEqual(mockGenerator.numberOfKeysGenerated, 1)
        XCTAssertEqual(firstReadKey, secondReadKey)
    }

    func testThatIfWhenThereIsAKeySavedInRowFormatTheSameKeyIsReadInBase64() {
        let originalKey = generator.randomKey()
        let store = EncryptionKeyStore(generator: generator, account: account)

        try? storeWithOldMechanism(key: originalKey)
        let readKey = try? store.readKey()

        XCTAssertEqual(originalKey, readKey)
    }

    private func removeTestKeys() {
        let store = EncryptionKeyStore(generator: generator, account: account)
        try? store.deleteKey()
    }

    private func storeWithOldMechanism(key: SymmetricKey) throws {
        var query = oldDefaultKeychainQueryAttributes
        query[kSecAttrService as String] = EncryptionKeyStore.Constants.encryptionKeyService
         query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
         query[kSecValueData as String] = key.dataRepresentation

         let status = SecItemAdd(query as CFDictionary, nil)

         guard status == errSecSuccess else {
             throw EncryptionKeyStoreError.storageFailed(status)
         }
     }

    private var oldDefaultKeychainQueryAttributes: [String: Any] {
        return [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecUseDataProtectionKeychain: true
        ] as [String: Any]
    }

}
