//
//  CSVImporterTests.swift
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

class CSVImporterTests: XCTestCase {

    let temporaryFileCreator = TemporaryFileCreator()

    override func tearDown() {
        super.tearDown()
        temporaryFileCreator.deleteCreatedTemporaryFiles()
    }

    func testWhenImportingCSVFileWithHeader_ThenHeaderRowIsExcluded() {
        let csvFileContents = """
        title,url,username,password
        Some Title,duck.com,username,p4ssw0rd
        """

        let logins = CSVImporter.extractLogins(from: csvFileContents)
        XCTAssertEqual(logins, [ImportedLoginCredential(title: "Some Title", url: "duck.com", username: "username", password: "p4ssw0rd")])
    }

    func testWhenImportingCSVFileWithoutHeader_ThenNoRowsAreExcluded() {
        let csvFileContents = """
        Some Title,duck.com,username,p4ssw0rd
        """

        let logins = CSVImporter.extractLogins(from: csvFileContents)
        XCTAssertEqual(logins, [ImportedLoginCredential(title: "Some Title", url: "duck.com", username: "username", password: "p4ssw0rd")])
    }

    func testWhenImportingCSVDataFromTheFileSystem_AndNoTitleIsIncluded_ThenLoginCredentialsAreImported() {
        let mockLoginImporter = MockLoginImporter()
        let file = "https://example.com/,username,password"
        let savedFileURL = temporaryFileCreator.persist(fileContents: file.data(using: .utf8)!, named: "test.csv")!
        let csvImporter = CSVImporter(fileURL: savedFileURL, loginImporter: mockLoginImporter)

        let expectation = expectation(description: #function)
        csvImporter.importData(types: [.logins]) { result in
            switch result {
            case .success(let summary):
                let expectedSummary = DataImport.Summary.logins(successfulImports: ["username"], duplicateImports: [], failedImports: [])
                XCTAssertEqual(summary, [expectedSummary])
                XCTAssertEqual(mockLoginImporter.importedLogins, expectedSummary)
            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0, handler: nil)
    }

    func testWhenImportingCSVDataFromTheFileSystem_AndTitleIsIncluded_ThenLoginCredentialsAreImported() {
        let mockLoginImporter = MockLoginImporter()
        let file = "title,https://example.com/,username,password"
        let savedFileURL = temporaryFileCreator.persist(fileContents: file.data(using: .utf8)!, named: "test.csv")!
        let csvImporter = CSVImporter(fileURL: savedFileURL, loginImporter: mockLoginImporter)

        let expectation = expectation(description: #function)
        csvImporter.importData(types: [.logins]) { result in
            switch result {
            case .success(let summary):
                let expectedSummary = DataImport.Summary.logins(successfulImports: ["username"], duplicateImports: [], failedImports: [])
                XCTAssertEqual(summary, [expectedSummary])
                XCTAssertEqual(mockLoginImporter.importedLogins, expectedSummary)
            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0, handler: nil)
    }

}
