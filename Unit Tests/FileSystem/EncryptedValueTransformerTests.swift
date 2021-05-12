//
//  EncryptedValueTransformerTests.swift
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

final class EncryptedValueTransformerTests: XCTestCase {

    func testTransformingValues() {
        let value = "Hello, World"
        let store = MockEncryptionKeyStore(generator: MockEncryptionKeyGenerator(), account: "mock-account")
        let key = try? store.readKey()
        let transformer = EncryptedValueTransformer<NSString>(encryptionKey: key!)
        let transformedValue = transformer.transformedValue(value)

        XCTAssertTrue(transformedValue is Data)
        XCTAssertNotEqual(value.data(using: .utf8), transformedValue as? Data)
    }

    func testReverseTransformingValues() {
        let value = "Hello, World"
        let store = MockEncryptionKeyStore(generator: MockEncryptionKeyGenerator(), account: "mock-account")
        let key = try? store.readKey()
        let transformer = EncryptedValueTransformer<NSString>(encryptionKey: key!)
        let transformedValue = transformer.transformedValue(value)
        let reverseTransformedValue = transformer.reverseTransformedValue(transformedValue)

        XCTAssertTrue(reverseTransformedValue is String)
        XCTAssertEqual(reverseTransformedValue as? String, value)
    }

}
