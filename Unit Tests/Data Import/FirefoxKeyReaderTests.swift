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
    
    func testDBOpen() {
        let path = resourcesURLWithoutPassword().appendingPathComponent("key3-firefox46.db").path
        FirefoxBerkeleyDatabaseReader.readDatabase(path)
    }

    func testWhenReadingValidKey4Database_AndNoPrimaryPasswordIsSet_ThenKeyIsRead() {
        let path = resourcesURLWithoutPassword().appendingPathComponent("key4.db").path
        let reader = FirefoxEncryptionKeyReader()
        let result = reader.getEncryptionKey(withDatabaseAt: path, primaryPassword: "")
        
        if case let .success(data) = result {
            XCTAssertEqual(data.count, 24)
        } else {
            XCTFail("Failed to read decryption key")
        }
    }
    
    func testFirefox59_WhenReadingValidKey4Database_AndNoPrimaryPasswordIsSet_ThenKeyIsRead() {
        let path = resourcesURLWithoutPassword().appendingPathComponent("key4-firefox59.db").path
        let reader = FirefoxEncryptionKeyReader()
        let result = reader.getEncryptionKey(withDatabaseAt: path, primaryPassword: "")
        
        if case let .success(data) = result {
            XCTAssertEqual(data.count, 24)
        } else {
            XCTFail("Failed to read decryption key")
        }
    }
    
    func testWhenReadingValidKey4Database_AndPrimaryPasswordIsProvided_ThenKeyIsRead() {
        let path = resourcesURLWithPassword().appendingPathComponent("key4-encrypted.db").path
        let reader = FirefoxEncryptionKeyReader()
        let result = reader.getEncryptionKey(withDatabaseAt: path, primaryPassword: "testpassword")
        
        if case let .success(data) = result {
            XCTAssertEqual(data.count, 24)
        } else {
            XCTFail("Failed to read decryption key")
        }
    }
    
    func testWhenReadingValidKey4Database_AndPrimaryPasswordIsNotProvided_ThenKeyIsNotRead() {
        let path = resourcesURLWithPassword().appendingPathComponent("key4-encrypted.db").path
        let reader = FirefoxEncryptionKeyReader()
        let result = reader.getEncryptionKey(withDatabaseAt: path, primaryPassword: "")
        
        if case let .failure(error) = result {
            XCTAssertEqual(error, .requiresPrimaryPassword)
        } else {
            XCTFail("Failed to read decryption key")
        }
    }
    
    private func resourcesURLWithPassword() -> URL {
        let bundle = Bundle(for: FirefoxLoginReaderTests.self)
        return bundle.resourceURL!.appendingPathComponent("Data Import Resources/Test Firefox Data/Primary Password")
    }
    
    private func resourcesURLWithoutPassword() -> URL {
        let bundle = Bundle(for: FirefoxLoginReaderTests.self)
        return bundle.resourceURL!.appendingPathComponent("Data Import Resources/Test Firefox Data/No Primary Password")
    }
    
}
