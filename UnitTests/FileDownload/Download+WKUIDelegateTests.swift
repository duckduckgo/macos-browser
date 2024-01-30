//
//  Download+WKUIDelegate.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
@testable import DuckDuckGo_Privacy_Browser

final class DownloadWKUIDelegateTests: XCTestCase {
    private var testData: Data!
    private let filename = "Document.pdf"
    private let fileManager = FileManager.default

    override func setUpWithError() throws {
        try super.setUpWithError()

        testData = try XCTUnwrap("test".data(using: .utf8))
    }

    override func tearDownWithError() throws {
        testData = nil
        try super.tearDownWithError()
    }

    @MainActor
    func testWhenWebViewDownloadPDFAndFileExistThenURLShouldIncrementIndex() throws {
        // GIVEN
        let testDirectory = fileManager.temporaryDirectory
        let preferencesPersistorMock = DownloadsPreferencesPersistorMock(selectedDownloadLocation: testDirectory.absoluteString)
        let downloadPreferences = DownloadsPreferences(persistor: preferencesPersistorMock)
        let tab = Tab(content: .none, downloadsPreferences: downloadPreferences)
        let expectedFilename = "Document 1.pdf"
        let originatingURL = try XCTUnwrap(URL(string: "www.duckduckgo.com"))
        let destURL = testDirectory.appendingPathComponent(filename)
        let expectedDestURL = testDirectory.appendingPathComponent(expectedFilename)
        try testData.write(to: destURL)
        XCTAssertFalse(fileManager.fileExists(atPath: expectedDestURL.path))

        // WHEN
        tab.webView(WKWebView(), saveDataToFile: testData, suggestedFilename: filename, mimeType: "application/pdf", originatingURL: originatingURL)

        // THEN
        XCTAssertTrue(fileManager.fileExists(atPath: expectedDestURL.path))
    }

    @MainActor
    func testWhenWebViewDownloadPDFAndFileDoesNotExistThenURLShouldNotIncrementIndex() throws {
        // GIVEN
        let testDirectory = fileManager.temporaryDirectory
        let preferencesPersistorMock = DownloadsPreferencesPersistorMock(selectedDownloadLocation: testDirectory.absoluteString)
        let downloadPreferences = DownloadsPreferences(persistor: preferencesPersistorMock)
        let tab = Tab(content: .none, downloadsPreferences: downloadPreferences)
        let expectedFilename = "Document.pdf"
        let originatingURL = try XCTUnwrap(URL(string: "www.duckduckgo.com"))
        let expectedDestURL = testDirectory.appendingPathComponent(expectedFilename)
        XCTAssertFalse(fileManager.fileExists(atPath: expectedDestURL.path))

        // WHEN
        tab.webView(WKWebView(), saveDataToFile: testData, suggestedFilename: filename, mimeType: "application/pdf", originatingURL: originatingURL)

        // THEN
        XCTAssertTrue(fileManager.fileExists(atPath: expectedDestURL.path))
    }
}
