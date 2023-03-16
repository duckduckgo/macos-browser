//
//  EncryptionMocks.swift
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

final class MockEncryptionKeyGenerator: EncryptionKeyGenerating {

    var numberOfKeysGenerated: Int = 0

    func randomKey() -> SymmetricKey {
        numberOfKeysGenerated += 1
        return SymmetricKey(size: .bits256)
    }

}

@objc(MockEncryptionKeyStore)
final class MockEncryptionKeyStore: NSObject, EncryptionKeyStoring {

    private(set) var storedKeys: [String: SymmetricKey] = [:]
    private let generator: EncryptionKeyGenerating
    private let account: String

    init(generator: EncryptionKeyGenerating, account: String) {
        self.generator = generator
        self.account = account
    }

    override convenience init() {
        self.init(generator: EncryptionKeyGenerator(), account: "mock-account")
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

// Value transformers are created by Core Data when required, and as such it's tricky to unit test them.
final class MockValueTransformer: ValueTransformer {
    var numberOfTransformations = 0
    private let prefix = "Transformed: "

    override class func transformedValueClass() -> AnyClass {
        NSString.self
    }

    override class func allowsReverseTransformation() -> Bool {
        true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        numberOfTransformations += 1

        guard let value = value as? NSString else { return nil }

        let transformedValue = "\(prefix)\(value)" as NSString
        return try? NSKeyedArchiver.archivedData(withRootObject: transformedValue, requiringSecureCoding: true)
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else {
            return nil
        }

        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: data)
    }

}
