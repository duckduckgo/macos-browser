//
//  MockEncryptionKeyGenerator.swift
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

class MockEncryptionKeyGenerator: EncryptionKeyGenerating {

    var numberOfKeysGenerated: Int = 0

    func randomKey() -> SymmetricKey {
        numberOfKeysGenerated += 1
        return SymmetricKey(size: .bits256)
    }

}

class MockEncryptionKeyStore: EncryptionKeyStoring {

    private(set) var storedKeys: [String: SymmetricKey] = [:]
    private let generator: EncryptionKeyGenerating
    private let account: String

    init(generator: EncryptionKeyGenerating, account: String) {
        self.generator = generator
        self.account = account
    }

    func store(key: SymmetricKey) throws {
        storedKeys[account] = key
    }

    func readKey() throws -> SymmetricKey {
        if let key = storedKeys[account] {
            return key
        } else {
            let newKey = generator.randomKey()
            storedKeys[account] = newKey

            return newKey
        }
    }

    func deleteKey() throws {
        storedKeys = [:]
    }

}
