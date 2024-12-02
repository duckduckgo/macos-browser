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
    private var testOriginatingURL: URL!
    private let filename = "Document.pdf"
    private let fileManager = FileManager.default
    private var testDirectory: URL!
    private var cancellables: Set<AnyCancellable>!

    override func setUpWithError() throws {
        try super.setUpWithError()

        testData = try XCTUnwrap("test".data(using: .utf8))
        testDirectory = fileManager.temporaryDirectory
        testOriginatingURL = testDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        try testData.write(to: testOriginatingURL)

        cancellables = []
    }

    override func tearDownWithError() throws {
        testData = nil
        testDirectory = nil
        cancellables = nil
        try super.tearDownWithError()
    }

    func testWhenAlwaysRequestDownloadLocationIsTrueThenShouldAskDownloadsTabExtensionToSaveData() async throws {
        // GIVEN
        let expectedURL = testDirectory.appendingPathComponent(filename)
        let sut = makeSUT(downloadLocation: testDirectory, alwaysRequestDownloadLocation: true)
        XCTAssertFalse(fileManager.fileExists(atPath: expectedURL.path))

        // WHEN
        sut.$savePanelDialogRequest
            .sink { request in
                request?.submit( (url: expectedURL, fileType: nil))
            }
            .store(in: &cancellables)
        _=try await sut.saveDownloadedData(testData, suggestedFilename: filename, mimeType: "application/pdf",
                                           originatingURL: testOriginatingURL.appendingPathExtension("fake"))

        // THEN
        XCTAssertTrue(fileManager.fileExists(atPath: expectedURL.path))
    }

    func testWhenAlwaysRequestDownloadLocationIsTrueAndNoDataProvidedAndOriginatingFileURLProvidedThenShouldAskDownloadsTabExtensionToSaveData() async throws {
        // GIVEN
        let expectedURL = testDirectory.appendingPathComponent(filename)
        let sut = makeSUT(downloadLocation: testDirectory, alwaysRequestDownloadLocation: true)
        XCTAssertFalse(fileManager.fileExists(atPath: expectedURL.path))

        // WHEN
        sut.$savePanelDialogRequest
            .sink { request in
                request?.submit( (url: expectedURL, fileType: nil))
            }
            .store(in: &cancellables)
        _=try await sut.saveDownloadedData(nil, suggestedFilename: filename, mimeType: "application/pdf", originatingURL: testOriginatingURL)

        // THEN
        XCTAssertTrue(fileManager.fileExists(atPath: expectedURL.path))
    }

    func testWhenSaveDataAndFileExistThenURLShouldIncrementIndex() async throws {
        // GIVEN
        let destURL = testDirectory.appendingPathComponent(filename)
        let sut = makeSUT(downloadLocation: testDirectory, alwaysRequestDownloadLocation: false)
        let expectedFilename = "Document 1.pdf"
        let expectedDestURL = testDirectory.appendingPathComponent(expectedFilename)
        try testData.write(to: destURL)
        XCTAssertFalse(fileManager.fileExists(atPath: expectedDestURL.path))

        // WHEN
        _=try await sut.saveDownloadedData(testData, suggestedFilename: filename, mimeType: "application/pdf",
                                           originatingURL: testOriginatingURL.appendingPathExtension("fake"))

        // THEN
        XCTAssertTrue(fileManager.fileExists(atPath: expectedDestURL.path))
    }

    func testWhenNoDataProvidedAndOriginatingFileURLProvidedAndFileExistsThenFileShouldBeCopiedIncrementingIndex() async throws {
        // GIVEN
        let destURL = testDirectory.appendingPathComponent(filename)
        let sut = makeSUT(downloadLocation: testDirectory, alwaysRequestDownloadLocation: false)
        let expectedFilename = "Document 1.pdf"
        let expectedDestURL = testDirectory.appendingPathComponent(expectedFilename)
        try testData.write(to: destURL)
        XCTAssertFalse(fileManager.fileExists(atPath: expectedDestURL.path))

        // WHEN
        _=try await sut.saveDownloadedData(nil, suggestedFilename: filename, mimeType: "application/pdf", originatingURL: testOriginatingURL)

        // THEN
        XCTAssertTrue(fileManager.fileExists(atPath: expectedDestURL.path))
    }

    func testWhenSaveDataAndFileDoesNotExistThenURLShouldNotIncrementIndex() async throws {
        // GIVEN
        let destURL = testDirectory.appendingPathComponent(filename)
        let sut = makeSUT(downloadLocation: testDirectory, alwaysRequestDownloadLocation: false)
        XCTAssertFalse(fileManager.fileExists(atPath: destURL.path))

        // WHEN
        _=try await sut.saveDownloadedData(testData, suggestedFilename: filename, mimeType: "application/pdf",
                                           originatingURL: testOriginatingURL.appendingPathExtension("fake"))

        // THEN
        XCTAssertTrue(fileManager.fileExists(atPath: destURL.path))
    }

    func testNoDataProvidedAndOriginatingFileURLProvidedAndFileDoesNotExistThenFileShouldBeCopiedNotIncrementingIndex() async throws {
        // GIVEN
        let destURL = testDirectory.appendingPathComponent(filename)
        let sut = makeSUT(downloadLocation: testDirectory, alwaysRequestDownloadLocation: false)
        XCTAssertFalse(fileManager.fileExists(atPath: destURL.path))

        // WHEN
        _=try await sut.saveDownloadedData(nil, suggestedFilename: filename, mimeType: "application/pdf", originatingURL: testOriginatingURL)

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
