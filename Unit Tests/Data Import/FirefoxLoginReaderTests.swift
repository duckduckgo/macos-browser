//
//  FirefoxLoginReaderTests.swift
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
import XCTest
@testable import DuckDuckGo_Privacy_Browser

class FirefoxLoginReaderTests: XCTestCase {

    func testWhenImportingFirefox46LoginsWithNoPrimaryPassword_ThenImportSucceeds() {
        let firefoxLoginReader = FirefoxLoginReader(firefoxProfileURL: resourcesURLWithoutPassword(),
                                                    databaseFileName: "key3-firefox46.db",
                                                    loginsFileName: "logins-firefox46.json")
        let result = firefoxLoginReader.readLogins(dataFormat: .version2)

        if case let .success(logins) = result {
            XCTAssertEqual(logins.count, 4)
        } else {
            XCTFail("Failed to decrypt Firefox logins")
        }
    }
    
    func testWhenImportingLoginsWithNoPrimaryPassword_ThenImportSucceeds() {
        let firefoxLoginReader = FirefoxLoginReader(firefoxProfileURL: resourcesURLWithoutPassword(),
                                                    databaseFileName: "key4.db",
                                                    loginsFileName: "logins.json")
        let result = firefoxLoginReader.readLogins(dataFormat: .version3)

        if case let .success(logins) = result {
            XCTAssertEqual(logins, [ImportedLoginCredential(url: "example.com", username: "testusername", password: "testpassword")])
        } else {
            XCTFail("Failed to decrypt Firefox logins")
        }
    }

    func testWhenImportingLoginsWithPrimaryPassword_AndNoPrimaryPasswordIsProvided_ThenImportFails() {
        let firefoxLoginReader = FirefoxLoginReader(firefoxProfileURL: resourcesURLWithPassword(),
                                                    databaseFileName: "key4-encrypted.db",
                                                    loginsFileName: "logins-encrypted.json")
        let result = firefoxLoginReader.readLogins(dataFormat: .version3)

        if case let .failure(error) = result {
            XCTAssertEqual(error, .requiresPrimaryPassword)
        } else {
            XCTFail("Expected to fail when decrypting a database that is protected with a Primary Password")
        }
    }

    func testWhenImportingLoginsWithPrimaryPassword_AndPrimaryPasswordIsProvided_ThenImportSucceeds() {
        let firefoxLoginReader = FirefoxLoginReader(firefoxProfileURL: resourcesURLWithPassword(),
                                                    primaryPassword: "testpassword",
                                                    databaseFileName: "key4-encrypted.db",
                                                    loginsFileName: "logins-encrypted.json")
        let result = firefoxLoginReader.readLogins(dataFormat: .version3)

        if case let .success(logins) = result {
            XCTAssertEqual(logins, [ImportedLoginCredential(url: "example.com", username: "testusername", password: "testpassword")])
        } else {
            XCTFail("Failed to decrypt Firefox logins")
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
