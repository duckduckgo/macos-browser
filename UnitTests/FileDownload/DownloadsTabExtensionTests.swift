//
//  DownloadsTabExtensionTests.swift
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

import Combine
import XCTest
import UniformTypeIdentifiers

@testable import DuckDuckGo_Privacy_Browser

final class DownloadsTabExtensionTests: XCTestCase {
    private var testData: Data!
    private let filename = "Document.pdf"
    private let fileManager = FileManager.default
    private var testDirectory: URL!
    private var cancellables: Set<AnyCancellable>!

    override func setUpWithError() throws {
        try super.setUpWithError()

        testData = try XCTUnwrap("test".data(using: .utf8))
        testDirectory = fileManager.temporaryDirectory
        cancellables = []
    }

    override func tearDownWithError() throws {
        testData = nil
        testDirectory = nil
        cancellables = nil
        try super.tearDownWithError()
    }

    @MainActor
    func testWhenAlwaysRequestDownloadLocationIsTrueThenShouldAskDownloadsTabExtensionToSaveData() throws {
        // GIVEN
        let expectedURL = testDirectory.appendingPathComponent(filename)
        let sut = makeSUT(downloadLocation: testDirectory, alwaysRequestDownloadLocation: true)
        XCTAssertFalse(fileManager.fileExists(atPath: expectedURL.path))

        // WHEN
        sut.saveDownloaded(data: testData, suggestedFilename: filename, mimeType: "application/pdf")
        sut.$savePanelDialogRequest
            .sink { request in
                request?.submit( (url: expectedURL, fileType: nil))
            }
            .store(in: &cancellables)

        // THEN
        XCTAssertTrue(fileManager.fileExists(atPath: expectedURL.path))
    }

    @MainActor
    func testWhenSaveDataAndFileExistThenURLShouldIncrementIndex() throws {
        // GIVEN
        let destURL = testDirectory.appendingPathComponent(filename)
        let sut = makeSUT(downloadLocation: testDirectory, alwaysRequestDownloadLocation: false)
        let expectedFilename = "Document 1.pdf"
        let expectedDestURL = testDirectory.appendingPathComponent(expectedFilename)
        try testData.write(to: destURL)
        XCTAssertFalse(fileManager.fileExists(atPath: expectedDestURL.path))

        // WHEN
        sut.saveDownloaded(data: testData, suggestedFilename: filename, mimeType: "application/pdf")

        // THEN
        XCTAssertTrue(fileManager.fileExists(atPath: expectedDestURL.path))
    }

    @MainActor
    func testWhenSaveDataAndFileDoesNotExistThenURLShouldNotIncrementIndex() throws {
        // GIVEN
        let destURL = testDirectory.appendingPathComponent(filename)
        let sut = makeSUT(downloadLocation: testDirectory, alwaysRequestDownloadLocation: false)
        XCTAssertFalse(fileManager.fileExists(atPath: destURL.path))

        // WHEN
        sut.saveDownloaded(data: testData, suggestedFilename: filename, mimeType: "application/pdf")

        // THEN
        XCTAssertTrue(fileManager.fileExists(atPath: destURL.path))
    }

}

private extension DownloadsTabExtensionTests {

    func makeSUT(downloadLocation: URL, alwaysRequestDownloadLocation: Bool) -> DownloadsTabExtension {
        let preferencesPersistorMock = DownloadsPreferencesPersistorMock(
            selectedDownloadLocation: downloadLocation.absoluteString,
            alwaysRequestDownloadLocation: alwaysRequestDownloadLocation
        )
        let downloadPreferences = DownloadsPreferences(persistor: preferencesPersistorMock)
        return DownloadsTabExtension(downloadManager: FileDownloadManagerMock(), isBurner: false, downloadsPreferences: downloadPreferences)
    }
}
