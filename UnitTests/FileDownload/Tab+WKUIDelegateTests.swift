//
//  Tab+WKUIDelegateTests.swift
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
import UniformTypeIdentifiers

@testable import DuckDuckGo_Privacy_Browser

final class TabWKUIDelegateTests: XCTestCase {
    private var testData: Data!
    private var originatingURL: URL!
    private let filename = "Document.pdf"
    private let fileManager = FileManager.default
    private var testDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testData = try XCTUnwrap("test".data(using: .utf8))
        testDirectory = fileManager.temporaryDirectory
        originatingURL = URL(string: "https://www.duckduckgo.com")!
    }

    override func tearDownWithError() throws {
        testData = nil
        testDirectory = nil
        originatingURL = nil
        try super.tearDownWithError()
    }

    @MainActor
    func testWebViewDownloadDataThenShouldAskDownloadsTabExtensionToSaveData() throws {
        // GIVEN
        let downloadExtensionMock = DownloadsTabExtensionMock()
        let extensionBuilder = TestTabExtensionsBuilder(load: [DownloadsTabExtensionMock.self]) { builder in { _, _ in
            builder.override {
                downloadExtensionMock
            }
        }}
        let sut = Tab(content: .none, extensionsBuilder: extensionBuilder)
        let filename = "Test Document.pdf"
        XCTAssertFalse(downloadExtensionMock.didCallSaveDownloadedData)
        XCTAssertNil(downloadExtensionMock.capturedSavedDownloadData)
        XCTAssertNil(downloadExtensionMock.capturedMimeType)

        let eDidCallSaveDownloadedData = expectation(description: "didCallSaveDownloadedData")
        let c = downloadExtensionMock.$didCallSaveDownloadedData.sink { didCall in
            if didCall {
                eDidCallSaveDownloadedData.fulfill()
            }
        }

        // WHEN
        sut.webView(WKWebView(), saveDataToFile: testData, suggestedFilename: filename, mimeType: "application/pdf", originatingURL: originatingURL)

        // THEN
        waitForExpectations(timeout: 1)
        XCTAssertEqual(downloadExtensionMock.capturedSavedDownloadData, testData)
        XCTAssertNotNil(downloadExtensionMock.capturedMimeType, "application/pdf")

        withExtendedLifetime(c) {}
    }

}
