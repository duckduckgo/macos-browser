//
//  ChromiumLoginReaderTests.swift
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

private struct ChromiumLoginStore {
    static let legacy: Self = .init(directory: "Legacy", decryptionKey: "0geUdf5dTuZmIrtd8Omf/Q==")
    static let legacyExcluded: Self = .init(directory: "Legacy Excluded", decryptionKey: "0geUdf5dTuZmIrtd8Omf/Q==")
    static let v32: Self = .init(directory: "v32", decryptionKey: "IcBAbGhvYp70AP+5W5ojcw==")
    static let v32Excluded: Self = .init(directory: "v32 Excluded", decryptionKey: "IcBAbGhvYp70AP+5W5ojcw==")

    let directory: String
    let decryptionKey: String

    var databaseDirectoryURL: URL {
        let bundle = Bundle(for: ChromiumLoginReaderTests.self)
        return bundle.resourceURL!
            .appendingPathComponent("DataImportResources/TestChromeData")
            .appendingPathComponent(directory)
    }
}

class ChromiumLoginReaderTests: XCTestCase {

    func testImportFromVersion32() throws {
        let reader = ChromiumLoginReader(
            chromiumDataDirectoryURL: ChromiumLoginStore.v32.databaseDirectoryURL,
            source: .chrome,
            decryptionKey: ChromiumLoginStore.v32.decryptionKey
        )

        let loginsResult = reader.readLogins()

        let logins = try XCTUnwrap(loginsResult.get())
            .sorted(by: { $0.username < $1.username })

        XCTAssertEqual(logins.count, 3)

        XCTAssertEqual(logins[0].url, "news.ycombinator.com")
        XCTAssertEqual(logins[0].username, "username32")
        XCTAssertEqual(logins[0].password, "newerpassword")

        XCTAssertEqual(logins[1].url, "news.ycombinator.com")
        XCTAssertEqual(logins[1].username, "username32cloud")
        XCTAssertEqual(logins[1].password, "password")

        XCTAssertEqual(logins[2].url, "news.ycombinator.com")
        XCTAssertEqual(logins[2].username, "username32local")
        XCTAssertEqual(logins[2].password, "password")
    }

    func testImportFromVersion32_WithOnlyExcludedSites_IgnoresExcludedCredentials() throws {
        // Given
        let expectedResult: DataImportResult<[ImportedLoginCredential]> = .success([])
        let reader = ChromiumLoginReader(
            chromiumDataDirectoryURL: ChromiumLoginStore.v32Excluded.databaseDirectoryURL,
            source: .chrome,
            decryptionKey: ChromiumLoginStore.v32Excluded.decryptionKey
        )

        // When
        let actualResult = reader.readLogins()

        // Then
        XCTAssertEqual(expectedResult, actualResult)
    }

    func testImportFromLegacyVersion() throws {

        let reader = ChromiumLoginReader(
            chromiumDataDirectoryURL: ChromiumLoginStore.legacy.databaseDirectoryURL,
            source: .chrome,
            decryptionKey: ChromiumLoginStore.legacy.decryptionKey
        )

        let loginsResult = reader.readLogins()

        let logins = try XCTUnwrap(loginsResult.get())

        XCTAssertEqual(logins.count, 1)

        XCTAssertEqual(logins[0].url, "news.ycombinator.com")
        XCTAssertEqual(logins[0].username, "username")
        XCTAssertEqual(logins[0].password, "password")
    }

    func testImportFromLegacyVersion_WithOnlyExcludedSites_IgnoresExcludedCredentials() {
        // Given
        let expectedResult: DataImportResult<[ImportedLoginCredential]> = .success([])
        let reader = ChromiumLoginReader(
            chromiumDataDirectoryURL: ChromiumLoginStore.legacyExcluded.databaseDirectoryURL,
            source: .chrome,
            decryptionKey: ChromiumLoginStore.legacyExcluded.decryptionKey
        )

        // When
        let actualResult = reader.readLogins()

        // Then
        XCTAssertEqual(expectedResult, actualResult)
    }

    func testWhenImportingChromiumData_AndTheUserCancelsTheKeychainPrompt_ThenAnErrorIsReturned() {
        let mockPrompt = MockChromiumPrompt(returnValue: .userDeniedKeychainPrompt)
        let reader = ChromiumLoginReader(
            chromiumDataDirectoryURL: ChromiumLoginStore.legacy.databaseDirectoryURL,
            source: .chrome,
            decryptionKeyPrompt: mockPrompt
        )

        let result = reader.readLogins()

        switch result {
        case .failure(let error as ChromiumLoginReader.ImportError):
            XCTAssertEqual(error.type, .userDeniedKeychainPrompt)
        default:
            XCTFail("Received unexpected \(result)")
        }
    }

    func testWhenImportingChromiumData_AndTheKeychainCausesAnError_ThenTheStatusCodeIsReturned() {
        let mockPrompt = MockChromiumPrompt(returnValue: .keychainError(123))
        let reader = ChromiumLoginReader(
            chromiumDataDirectoryURL: ChromiumLoginStore.legacy.databaseDirectoryURL,
            source: .chrome,
            decryptionKeyPrompt: mockPrompt
        )

        let result = reader.readLogins()

        switch result {
        case .failure(let error as ChromiumLoginReader.ImportError):
            XCTAssertEqual(error.type, .decryptionKeyAccessFailed)
            XCTAssertEqual((error.underlyingError as NSError?)?.code, 123)
        default:
            XCTFail("Received unexpected \(result)")
        }
    }

}

private class MockChromiumPrompt: ChromiumKeychainPrompting {

    var returnValue: ChromiumKeychainPromptResult

    init(returnValue: ChromiumKeychainPromptResult) {
        self.returnValue = returnValue
    }

    func promptForChromiumPasswordKeychainAccess(processName: String) -> ChromiumKeychainPromptResult {
        returnValue
    }

}
