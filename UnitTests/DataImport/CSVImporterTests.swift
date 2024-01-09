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

    func testWhenImportingCSVFileWithHeader_AndHeaderHasBitwardenFormat_ThenHeaderRowIsExcluded() {
        let csvFileContents = """
        name,login_uri,login_username,login_password
        Some Title,duck.com,username,p4ssw0rd
        """

        let logins = CSVImporter.extractLogins(from: csvFileContents)
        XCTAssertEqual(logins, [ImportedLoginCredential(title: "Some Title", url: "duck.com", username: "username", password: "p4ssw0rd")])
    }

    func testWhenImportingCSVFileWithHeader_ThenHeaderColumnPositionsAreRespected() {
        let csvFileContents = """
        Password,Title,Username,Url
        p4ssw0rd,"Some Title",username,duck.com
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

    func testWhenImportingCSVDataFromTheFileSystem_AndNoTitleIsIncluded_ThenLoginCredentialsAreImported() async {
        let mockLoginImporter = MockLoginImporter()
        let file = "https://example.com/,username,password"
        let savedFileURL = temporaryFileCreator.persist(fileContents: file.data(using: .utf8)!, named: "test.csv")!
        let csvImporter = CSVImporter(fileURL: savedFileURL, loginImporter: mockLoginImporter, defaultColumnPositions: nil)

        let result = await csvImporter.importData(types: [.passwords]).task.value

        XCTAssertEqual(result, [.passwords: .success(.init(successful: 1, duplicate: 0, failed: 0))])
    }

    func testWhenImportingCSVDataFromTheFileSystem_AndTitleIsIncluded_ThenLoginCredentialsAreImported() async {
        let mockLoginImporter = MockLoginImporter()
        let file = "title,https://example.com/,username,password"
        let savedFileURL = temporaryFileCreator.persist(fileContents: file.data(using: .utf8)!, named: "test.csv")!
        let csvImporter = CSVImporter(fileURL: savedFileURL, loginImporter: mockLoginImporter, defaultColumnPositions: nil)

        let result = await csvImporter.importData(types: [.passwords]).task.value

        XCTAssertEqual(result, [.passwords: .success(.init(successful: 1, duplicate: 0, failed: 0))])
    }

    func testWhenInferringColumnPostions_AndColumnsAreValid_AndTitleIsIncluded_ThenPositionsAreCalculated() {
        let csvValues = ["url", "username", "password", "title"]
        let inferred = CSVImporter.ColumnPositions(csvValues: csvValues)

        XCTAssertEqual(inferred?.urlIndex, 0)
        XCTAssertEqual(inferred?.usernameIndex, 1)
        XCTAssertEqual(inferred?.passwordIndex, 2)
        XCTAssertEqual(inferred?.titleIndex, 3)
    }

    func testWhenInferringColumnPostions_AndColumnsAreValid_AndTitleIsNotIncluded_ThenPositionsAreCalculated() {
        let csvValues = ["url", "username", "password"]
        let inferred = CSVImporter.ColumnPositions(csvValues: csvValues)

        XCTAssertEqual(inferred?.urlIndex, 0)
        XCTAssertEqual(inferred?.usernameIndex, 1)
        XCTAssertEqual(inferred?.passwordIndex, 2)
        XCTAssertNil(inferred?.titleIndex)
    }

    func testWhenInferringColumnPostions_AndColumnsAreInvalidThenPositionsAreCalculated() {
        let csvValues = ["url", "username", "title"] // `password` is required, this test verifies that the inference fails when it's missing
        let inferred = CSVImporter.ColumnPositions(csvValues: csvValues)

        XCTAssertNil(inferred)
    }

}

extension CSVImporter.ColumnPositions {

    init?(csvValues: [String]) {
        self.init(csv: [csvValues, Array(repeating: "", count: csvValues.count)])
    }

}
