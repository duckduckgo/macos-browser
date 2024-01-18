//
//  FirefoxKeyReaderTests.swift
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
@testable import DuckDuckGo_Privacy_Browser
import XCTest
import CryptoKit

class FirefoxKeyReaderTests: XCTestCase {

    func testWhenReadingValidKey3Database_AndNoPrimaryPasswordIsSet_ThenKeyIsRead() {
        let databaseURL = resourcesURLWithoutPassword().appendingPathComponent("key3-firefox46.db")
        let reader = FirefoxEncryptionKeyReader()
        let result = reader.getEncryptionKey(key3DatabaseURL: databaseURL, primaryPassword: "")

        if case let .success(data) = result {
            XCTAssertEqual(data.count, 24)
        } else {
            XCTFail("Failed to read decryption key")
        }
    }

    func testWhenReadingValidKey3Database_AndPrimaryPasswordIsSet_AndPrimaryPasswordIsValid_ThenKeyIsRead() {
        let databaseURL = resourcesURLWithPassword().appendingPathComponent("key3-firefox46.db")
        let reader = FirefoxEncryptionKeyReader()
        let result = reader.getEncryptionKey(key3DatabaseURL: databaseURL, primaryPassword: "сЮЛОажс$4vz*VçàhxpfCbmwo")

        if case let .success(data) = result {
            XCTAssertEqual(data.count, 24)
        } else {
            XCTFail("Failed to read decryption key")
        }
    }

    func testWhenReadingValidKey3Database_AndPrimaryPasswordIsSet_AndPrimaryPasswordIsInvalid_ThenKeyIsNotRead() {
        let databaseURL = resourcesURLWithPassword().appendingPathComponent("key3-firefox46.db")
        let reader = FirefoxEncryptionKeyReader()
        let result = reader.getEncryptionKey(key3DatabaseURL: databaseURL, primaryPassword: "invalid-password")

        switch result {
        case .failure(let error as FirefoxLoginReader.ImportError):
            XCTAssertEqual(error.type, .requiresPrimaryPassword)
        default:
            XCTFail("Received unexpected \(result)")
        }
    }

    func testWhenReadingInvalidKey3Database_ThenKeyIsNotRead() {
        let databaseURL = resourcesURLWithoutPassword().appendingPathComponent("key3-firefox46-broken.db")
        let reader = FirefoxEncryptionKeyReader()
        let result = reader.getEncryptionKey(key3DatabaseURL: databaseURL, primaryPassword: "")

        switch result {
        case .failure(let error as FirefoxLoginReader.ImportError):
            XCTAssertEqual(error.type, .key3readerStage1)
            XCTAssertTrue(error.underlyingError is FirefoxEncryptionKeyReader.KeyReaderFileLineError)
        default:
            XCTFail("Received unexpected \(result)")
        }
    }

    func testWhenReadingValidKey4Database_AndNoPrimaryPasswordIsSet_ThenKeyIsRead() {
        let databaseURL = resourcesURLWithoutPassword().appendingPathComponent("key4.db")
        let reader = FirefoxEncryptionKeyReader()
        let result = reader.getEncryptionKey(key4DatabaseURL: databaseURL, primaryPassword: "")

        if case let .success(data) = result {
            XCTAssertEqual(data.count, 24)
        } else {
            XCTFail("Failed to read decryption key")
        }
    }

    func testFirefox59_WhenReadingValidKey4Database_AndNoPrimaryPasswordIsSet_ThenKeyIsRead() {
        let databaseURL = resourcesURLWithoutPassword().appendingPathComponent("key4-firefox59.db")
        let reader = FirefoxEncryptionKeyReader()
        let result = reader.getEncryptionKey(key4DatabaseURL: databaseURL, primaryPassword: "")

        if case let .success(data) = result {
            XCTAssertEqual(data.count, 24)
        } else {
            XCTFail("Failed to read decryption key")
        }
    }

    func testWhenReadingValidKey4Database_AndPrimaryPasswordIsProvided_ThenKeyIsRead() {
        let databaseURL = resourcesURLWithPassword().appendingPathComponent("key4-encrypted.db")
        let reader = FirefoxEncryptionKeyReader()
        let result = reader.getEncryptionKey(key4DatabaseURL: databaseURL, primaryPassword: "testpassword")

        if case let .success(data) = result {
            XCTAssertEqual(data.count, 24)
        } else {
            XCTFail("Failed to read decryption key")
        }
    }

    func testWhenReadingValidKey4Database_AndPrimaryPasswordIsNotProvided_ThenKeyIsNotRead() {
        let databaseURL = resourcesURLWithPassword().appendingPathComponent("key4-encrypted.db")
        let reader = FirefoxEncryptionKeyReader()
        let result = reader.getEncryptionKey(key4DatabaseURL: databaseURL, primaryPassword: "")

        switch result {
        case .failure(let error as FirefoxLoginReader.ImportError):
            XCTAssertEqual(error.type, .requiresPrimaryPassword)
        default:
            XCTFail("Received unexpected \(result)")
        }
    }

    private func resourcesURLWithPassword() -> URL {
        let bundle = Bundle(for: FirefoxLoginReaderTests.self)
        return bundle.resourceURL!.appendingPathComponent("DataImportResources/TestFirefoxData/Primary Password")
    }

    private func resourcesURLWithoutPassword() -> URL {
        let bundle = Bundle(for: FirefoxLoginReaderTests.self)
        return bundle.resourceURL!.appendingPathComponent("DataImportResources/TestFirefoxData/No Primary Password")
    }

}
