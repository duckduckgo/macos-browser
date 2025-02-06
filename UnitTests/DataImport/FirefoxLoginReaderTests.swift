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
import BrowserServicesKit

class FirefoxLoginReaderTests: XCTestCase {

    private let rootDirectoryName = UUID().uuidString

    func testWhenImportingFirefox46LoginsWithNoPrimaryPassword_ThenImportSucceeds() throws {
        let database = resourcesURLWithoutPassword().appendingPathComponent("key3-firefox46.db")
        let logins = resourcesURLWithoutPassword().appendingPathComponent("logins-firefox46.json")

        let structure = FileSystem(rootDirectoryName: rootDirectoryName) {
            File("key3.db", contents: .copy(database))
            File("logins.json", contents: .copy(logins))
        }

        try structure.writeToTemporaryDirectory()
        let profileDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(rootDirectoryName)

        let firefoxLoginReader = FirefoxLoginReader(firefoxProfileURL: profileDirectoryURL)
        let result = firefoxLoginReader.readLogins(dataFormat: nil)

        if case let .success(logins) = result {
            XCTAssertEqual(logins.count, 4)
        } else {
            XCTFail("Failed to decrypt Firefox logins")
        }

        try structure.removeCreatedFileSystemStructure()
    }

    func testWhenImportingLoginsWithNoPrimaryPassword_ThenImportSucceeds() throws {
        let database = resourcesURLWithoutPassword().appendingPathComponent("key4.db")
        let logins = resourcesURLWithoutPassword().appendingPathComponent("logins.json")

        let structure = FileSystem(rootDirectoryName: rootDirectoryName) {
            File("key4.db", contents: .copy(database))
            File("logins.json", contents: .copy(logins))
        }

        try structure.writeToTemporaryDirectory()
        let profileDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(rootDirectoryName)

        let firefoxLoginReader = FirefoxLoginReader(firefoxProfileURL: profileDirectoryURL)
        let result = firefoxLoginReader.readLogins(dataFormat: nil)

        if case let .success(logins) = result {
            XCTAssertEqual(logins, [ImportedLoginCredential(url: "example.com", username: "testusername", password: "testpassword")])
        } else {
            XCTFail("Failed to decrypt Firefox logins")
        }

        try structure.removeCreatedFileSystemStructure()
    }

    func testWhenImportingLoginsWithPrimaryPassword_AndNoPrimaryPasswordIsProvided_ThenImportFails() throws {
        let database = resourcesURLWithPassword().appendingPathComponent("key4-encrypted.db")
        let logins = resourcesURLWithPassword().appendingPathComponent("logins-encrypted.json")

        let structure = FileSystem(rootDirectoryName: rootDirectoryName) {
            File("key4.db", contents: .copy(database))
            File("logins.json", contents: .copy(logins))
        }

        try structure.writeToTemporaryDirectory()
        let profileDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(rootDirectoryName)

        let firefoxLoginReader = FirefoxLoginReader(firefoxProfileURL: profileDirectoryURL)
        let result = firefoxLoginReader.readLogins(dataFormat: nil)

        switch result {
        case .failure(let error as FirefoxLoginReader.ImportError):
            XCTAssertEqual(error.type, .requiresPrimaryPassword)
        default:
            XCTFail("Received unexpected \(result)")
        }

        try structure.removeCreatedFileSystemStructure()
    }

    func testWhenImportingLoginsWithPrimaryPassword_AndPrimaryPasswordIsProvided_ThenImportSucceeds() throws {
        let database = resourcesURLWithPassword().appendingPathComponent("key4-encrypted.db")
        let logins = resourcesURLWithPassword().appendingPathComponent("logins-encrypted.json")

        let structure = FileSystem(rootDirectoryName: rootDirectoryName) {
            File("key4.db", contents: .copy(database))
            File("logins.json", contents: .copy(logins))
        }

        try structure.writeToTemporaryDirectory()
        let profileDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(rootDirectoryName)

        let firefoxLoginReader = FirefoxLoginReader(firefoxProfileURL: profileDirectoryURL, primaryPassword: "testpassword")
        let result = firefoxLoginReader.readLogins(dataFormat: nil)

        if case let .success(logins) = result {
            XCTAssertEqual(logins, [ImportedLoginCredential(url: "example.com", username: "testusername", password: "testpassword")])
        } else {
            XCTFail("Failed to decrypt Firefox logins")
        }
    }

    func testWhenImportingLoginsFromADirectory_AndNoMatchingFilesAreFound_ThenImportFails() throws {
        let structure = FileSystem(rootDirectoryName: rootDirectoryName) {
            File("unrelated-file", contents: .string(""))
        }

        try structure.writeToTemporaryDirectory()
        let profileDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(rootDirectoryName)

        let firefoxLoginReader = FirefoxLoginReader(firefoxProfileURL: profileDirectoryURL)
        let result = firefoxLoginReader.readLogins(dataFormat: nil)

        switch result {
        case .failure(let error as FirefoxLoginReader.ImportError):
            XCTAssertEqual(error.type, .couldNotFindKeyDB)
        default:
            XCTFail("Received unexpected \(result)")
        }

        try structure.removeCreatedFileSystemStructure()
    }

    func testWhenImportingFirefox70LoginsWithNoPrimaryPassword_ThenImportSucceeds() throws {
        let database = resourcesURLWithoutPassword().appendingPathComponent("key4-firefox70.db")
        let logins = resourcesURLWithoutPassword().appendingPathComponent("logins-firefox70.json")

        let structure = FileSystem(rootDirectoryName: rootDirectoryName) {
            File("key4.db", contents: .copy(database))
            File("logins.json", contents: .copy(logins))
        }

        try structure.writeToTemporaryDirectory()
        let profileDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(rootDirectoryName)

        let firefoxLoginReader = FirefoxLoginReader(firefoxProfileURL: profileDirectoryURL, primaryPassword: "")
        let result = firefoxLoginReader.readLogins(dataFormat: nil)

        if case let .success(logins) = result {
            XCTAssertEqual(logins, [ImportedLoginCredential(url: "www.example.com", username: "test", password: "test")])
        } else {
            XCTFail("Failed to decrypt Firefox logins")
        }
    }

    func testWhenImportingFirefox70LoginsWithPrimaryPassword_AndPrimaryPasswordIsProvided_ThenImportSucceeds() throws {
        let database = resourcesURLWithPassword().appendingPathComponent("key4-firefox70.db")
        let logins = resourcesURLWithPassword().appendingPathComponent("logins-firefox70.json")

        let structure = FileSystem(rootDirectoryName: rootDirectoryName) {
            File("key4.db", contents: .copy(database))
            File("logins.json", contents: .copy(logins))
        }

        try structure.writeToTemporaryDirectory()
        let profileDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(rootDirectoryName)

        let firefoxLoginReader = FirefoxLoginReader(firefoxProfileURL: profileDirectoryURL, primaryPassword: "test")
        let result = firefoxLoginReader.readLogins(dataFormat: nil)

        if case let .success(logins) = result {
            XCTAssertEqual(logins, [ImportedLoginCredential(url: "www.example.com", username: "test", password: "test")])
        } else {
            XCTFail("Failed to decrypt Firefox logins")
        }
    }

    func testWhenImportingFirefox70LoginsWithPrimaryPassword_AndNoPrimaryPasswordIsProvided_ThenImportFails() throws {
        let database = resourcesURLWithPassword().appendingPathComponent("key4-firefox70.db")
        let logins = resourcesURLWithPassword().appendingPathComponent("logins-firefox70.json")

        let structure = FileSystem(rootDirectoryName: rootDirectoryName) {
            File("key4.db", contents: .copy(database))
            File("logins.json", contents: .copy(logins))
        }

        try structure.writeToTemporaryDirectory()
        let profileDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(rootDirectoryName)

        let firefoxLoginReader = FirefoxLoginReader(firefoxProfileURL: profileDirectoryURL, primaryPassword: "")
        let result = firefoxLoginReader.readLogins(dataFormat: nil)

        switch result {
        case .failure(let error as FirefoxLoginReader.ImportError):
            XCTAssertEqual(error.type, .requiresPrimaryPassword)
        default:
            XCTFail("Received unexpected \(result)")
        }
    }

    func testWhenImportingFirefox84LoginsWithNoPrimaryPassword_ThenImportSucceeds() throws {
        let database = resourcesURLWithoutPassword().appendingPathComponent("key4-firefox84.db")
        let logins = resourcesURLWithoutPassword().appendingPathComponent("logins-firefox84.json")

        let structure = FileSystem(rootDirectoryName: rootDirectoryName) {
            File("key4.db", contents: .copy(database))
            File("logins.json", contents: .copy(logins))
        }

        try structure.writeToTemporaryDirectory()
        let profileDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(rootDirectoryName)

        let firefoxLoginReader = FirefoxLoginReader(firefoxProfileURL: profileDirectoryURL, primaryPassword: "")
        let result = firefoxLoginReader.readLogins(dataFormat: nil)

        if case let .success(logins) = result {
            XCTAssertEqual(logins, [ImportedLoginCredential(url: "www.example.com", username: "test", password: "test")])
        } else {
            XCTFail("Failed to decrypt Firefox logins")
        }
    }

    func testWhenImportingFirefox84LoginsWithPrimaryPassword_AndPrimaryPasswordIsProvided_ThenImportSucceeds() throws {
        let database = resourcesURLWithPassword().appendingPathComponent("key4-firefox84.db")
        let logins = resourcesURLWithPassword().appendingPathComponent("logins-firefox84.json")

        let structure = FileSystem(rootDirectoryName: rootDirectoryName) {
            File("key4.db", contents: .copy(database))
            File("logins.json", contents: .copy(logins))
        }

        try structure.writeToTemporaryDirectory()
        let profileDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(rootDirectoryName)

        let firefoxLoginReader = FirefoxLoginReader(firefoxProfileURL: profileDirectoryURL, primaryPassword: "test")
        let result = firefoxLoginReader.readLogins(dataFormat: nil)

        if case let .success(logins) = result {
            XCTAssertEqual(logins, [ImportedLoginCredential(url: "www.example.com", username: "test", password: "test")])
        } else {
            XCTFail("Failed to decrypt Firefox logins")
        }
    }

    func testWhenImportingFirefox84LoginsWithPrimaryPassword_AndNoPrimaryPasswordIsProvided_ThenImportFails() throws {
        let database = resourcesURLWithPassword().appendingPathComponent("key4-firefox84.db")
        let logins = resourcesURLWithPassword().appendingPathComponent("logins-firefox84.json")

        let structure = FileSystem(rootDirectoryName: rootDirectoryName) {
            File("key4.db", contents: .copy(database))
            File("logins.json", contents: .copy(logins))
        }

        try structure.writeToTemporaryDirectory()
        let profileDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(rootDirectoryName)

        let firefoxLoginReader = FirefoxLoginReader(firefoxProfileURL: profileDirectoryURL, primaryPassword: "")
        let result = firefoxLoginReader.readLogins(dataFormat: nil)

        switch result {
        case .failure(let error as FirefoxLoginReader.ImportError):
            XCTAssertEqual(error.type, .requiresPrimaryPassword)
        default:
            XCTFail("Received unexpected \(result)")
        }
    }

    func testWhenImportingLogins_AndNoKeysDBExists_ThenImportFailsWithNoDBError() throws {
        // Given
        let logins = resourcesURLWithoutPassword().appendingPathComponent("logins.json")

        let structure = FileSystem(rootDirectoryName: rootDirectoryName) {
            File("logins.json", contents: .copy(logins))
        }

        try structure.writeToTemporaryDirectory()
        let profileDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(rootDirectoryName)

        let firefoxLoginReader = FirefoxLoginReader(firefoxProfileURL: profileDirectoryURL)

        // When
        let result = firefoxLoginReader.readLogins(dataFormat: nil)

        // Then
        XCTAssertEqual(result, .failure(FirefoxLoginReader.ImportError(type: .couldNotFindKeyDB, underlyingError: nil)))
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
