//
//  DataEncryptionTests.swift
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

final class DataEncryptionTests: XCTestCase {

    func testSuccessfulEncryption() {
        let key = SymmetricKey(size: .bits256)
        let data = "Hello, World".data(using: .utf8)!
        let encryptedData = try? DataEncryption.encrypt(data: data, key: key)

        XCTAssertNotNil(encryptedData)
        XCTAssertNotEqual(data, encryptedData)
    }

    func testSuccessfulDecryption() {
        let key = SymmetricKey(size: .bits256)
        let testString = "Hello, World"
        let data = testString.data(using: .utf8)!
        let encryptedData = try? DataEncryption.encrypt(data: data, key: key)
        let decryptedData = try? DataEncryption.decrypt(data: encryptedData!, key: key)

        XCTAssertNotNil(decryptedData)
        XCTAssertEqual(data, decryptedData)
    }

    func testDecryptionWithTheWrongKeyFails() {
        let correctKey = EncryptionKeyGenerator().randomKey()
        let incorrectKey = EncryptionKeyGenerator().randomKey()

        let testString = "Hello, World"
        let data = testString.data(using: .utf8)!
        let encryptedData = try? DataEncryption.encrypt(data: data, key: correctKey)
        let decryptedData = try? DataEncryption.decrypt(data: encryptedData!, key: incorrectKey)

        XCTAssertNil(decryptedData)
        XCTAssertNotEqual(data, decryptedData)
    }

    func testDecryptingInvalidDataThrowsInvalidDataError() {
        let randomData = "Random Data".data(using: .utf8)!
        let key = SymmetricKey(size: .bits256)

        do {
            _ = try DataEncryption.decrypt(data: randomData, key: key)
            XCTFail("Decrypting random data should throw an error")
        } catch {
            let error = error as? DataEncryptionError
            XCTAssertEqual(error, DataEncryptionError.invalidData)
        }
    }

}
