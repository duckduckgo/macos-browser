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
        originatingURL = try XCTUnwrap(URL(string: "www.duckduckgo.com"))
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
        XCTAssertNil(downloadExtensionMock.capturedSavedDownloadURL)

        // WHEN
        sut.webView(WKWebView(), saveDataToFile: testData, suggestedFilename: filename, mimeType: "application/pdf", originatingURL: originatingURL)

        // THEN
        XCTAssertTrue(downloadExtensionMock.didCallSaveDownloadedData)
        XCTAssertEqual(downloadExtensionMock.capturedSavedDownloadData, testData)
        XCTAssertNotNil(downloadExtensionMock.capturedSavedDownloadURL?.absoluteString.contains(filename))
    }

    @MainActor
    func testWhenAlwaysRequestDownloadLocationIsFalseThenShouldAskDownloadsTabExtensionToSaveData() throws {
        // GIVEN
        let preferencesPersistorMock = DownloadsPreferencesPersistorMock(
            selectedDownloadLocation: testDirectory.absoluteString,
            alwaysRequestDownloadLocation: false
        )
        let downloadPreferences = DownloadsPreferences(persistor: preferencesPersistorMock)
        let downloadExtensionMock = DownloadsTabExtensionMock()
        let extensionBuilder = TestTabExtensionsBuilder(load: [DownloadsTabExtensionMock.self]) { builder in { _, _ in
            builder.override {
                downloadExtensionMock
            }
        }}
        let tab = Tab(content: .none, downloadsPreferences: downloadPreferences, extensionsBuilder: extensionBuilder)
        XCTAssertFalse(downloadExtensionMock.didCallSaveDownloadedData)
        XCTAssertNil(downloadExtensionMock.capturedSavedDownloadData)
        XCTAssertNil(downloadExtensionMock.capturedSavedDownloadURL)

        // WHEN
        tab.webView(WKWebView(), saveDataToFile: testData, suggestedFilename: filename, mimeType: "application/pdf", originatingURL: originatingURL)

        // THEN
        XCTAssertTrue(downloadExtensionMock.didCallSaveDownloadedData)
        XCTAssertEqual(downloadExtensionMock.capturedSavedDownloadData, testData)
        XCTAssertEqual(downloadExtensionMock.capturedSavedDownloadURL, testDirectory.appendingPathComponent(filename))
    }

    @MainActor
    func testWhenAlwaysRequestDownloadLocationIsTrueThenShouldAskDownloadsTabExtensionToSaveData() throws {
        // GIVEN
        let preferencesPersistorMock = DownloadsPreferencesPersistorMock(
            selectedDownloadLocation: testDirectory.absoluteString,
            alwaysRequestDownloadLocation: true
        )
        let downloadPreferences = DownloadsPreferences(persistor: preferencesPersistorMock)
        let downloadExtensionMock = DownloadsTabExtensionMock()
        let extensionBuilder = TestTabExtensionsBuilder(load: [DownloadsTabExtensionMock.self]) { builder in { _, _ in
            builder.override {
                downloadExtensionMock
            }
        }}
        let savePanelDialogRequestFactoryMock = SavePanelDialogRequestFactoryMock()
        let tab = Tab(content: .none, downloadsPreferences: downloadPreferences, extensionsBuilder: extensionBuilder, savePanelDialogRequestFactory: savePanelDialogRequestFactoryMock)

        XCTAssertFalse(downloadExtensionMock.didCallSaveDownloadedData)
        XCTAssertNil(downloadExtensionMock.capturedSavedDownloadData)
        XCTAssertNil(downloadExtensionMock.capturedSavedDownloadURL)
        tab.webView(WKWebView(), saveDataToFile: testData, suggestedFilename: filename, mimeType: "application/pdf", originatingURL: originatingURL)
        let expectedURL = testDirectory.appendingPathComponent(filename)

        // WHEN
        savePanelDialogRequestFactoryMock.completionHandler?(.success((expectedURL, nil)))

        // THEN
        XCTAssertTrue(downloadExtensionMock.didCallSaveDownloadedData)
        XCTAssertEqual(downloadExtensionMock.capturedSavedDownloadData, testData)
        XCTAssertEqual(downloadExtensionMock.capturedSavedDownloadURL, expectedURL)
    }

}

final class SavePanelDialogRequestFactoryMock: SavePanelDialogRequestFactoryProtocol {

    var completionHandler: ((Result<(url: URL, fileType: UTType?)?, DuckDuckGo_Privacy_Browser.UserDialogRequestError>) -> Void)?

    func makeSavePanelDialogRequest(suggestedFilename: String, fileTypes: [UTType], completionHandler: @escaping (Result<(url: URL, fileType: UTType?)?, DuckDuckGo_Privacy_Browser.UserDialogRequestError>) -> Void) -> DuckDuckGo_Privacy_Browser.SavePanelDialogRequest {
        self.completionHandler = completionHandler

        return .init(.init(suggestedFilename: suggestedFilename, fileTypes: fileTypes), callback: completionHandler)
    }

}
