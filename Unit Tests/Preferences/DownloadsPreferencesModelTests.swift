//
//  DownloadsPreferencesModelTests.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

struct DownloadsPreferencesPersistorMock: DownloadsPreferencesPersistor {
    var selectedDownloadLocation: String?
    var alwaysRequestDownloadLocation: Bool
    var defaultDownloadLocation: URL?
    // swiftlint:disable:next identifier_name
    var _isDownloadLocationValid: (URL) -> Bool

    func isDownloadLocationValid(_ location: URL) -> Bool {
        _isDownloadLocationValid(location)
    }

    init(
        selectedDownloadLocation: String? = nil,
        alwaysRequestDownloadLocation: Bool = false,
        defaultDownloadLocation: URL? = FileManager.default.temporaryDirectory,
        isDownloadLocationValid: @escaping (URL) -> Bool = { _ in true }
    ) {
        self.selectedDownloadLocation = selectedDownloadLocation
        self.alwaysRequestDownloadLocation = alwaysRequestDownloadLocation
        self.defaultDownloadLocation = defaultDownloadLocation
        self._isDownloadLocationValid = isDownloadLocationValid
    }
}

class DownloadsPreferencesModelTests: XCTestCase {

    static let defaultTestDirectoryName = "DownloadsPreferencesModelTests"

    override func setUpWithError() throws {
        try super.setUpWithError()

        deleteTemporaryTestDirectory()
    }

    func testWhenSettingNilDownloadLocationThenDefaultDownloadLocationIsReturned() {
        let testDirectory = createTemporaryTestDirectory()
        let persistor = DownloadsPreferencesPersistorMock(selectedDownloadLocation: nil)
        let preferences = DownloadsPreferencesModel(persistor: persistor)

        preferences.selectedDownloadLocation = testDirectory
        XCTAssertEqual(preferences.effectiveDownloadLocation, testDirectory)

        preferences.selectedDownloadLocation = nil
        XCTAssertEqual(preferences.effectiveDownloadLocation, DownloadsPreferencesModel.defaultDownloadLocation())
    }

    func testWhenDownloadLocationIsNotPersistedThenDefaultDownloadLocationIsReturned() {
        let persistor = DownloadsPreferencesPersistorMock(selectedDownloadLocation: nil)
        let preferences = DownloadsPreferencesModel(persistor: persistor)

        XCTAssertEqual(preferences.effectiveDownloadLocation, DownloadsPreferencesModel.defaultDownloadLocation())
    }

    func testWhenDownloadLocationIsNotWritableThenDefaultDownloadLocationIsReturned() {
        let testDirectory = createTemporaryTestDirectory()
        let persistor = DownloadsPreferencesPersistorMock(selectedDownloadLocation: testDirectory.absoluteString)
        let preferences = DownloadsPreferencesModel(persistor: persistor)

        let invalidDownloadLocationURL = FileManager.default.temporaryDirectory.appendingPathComponent("InvalidDownloadLocation")

        preferences.selectedDownloadLocation = invalidDownloadLocationURL

        XCTAssertEqual(preferences.effectiveDownloadLocation, testDirectory)
    }

    func testWhenGettingSelectedDownloadLocationAndSelectedLocationIsInaccessibleThenDefaultDownloadLocationIsReturned() {
        let testDirectory = createTemporaryTestDirectory()
        let persistor = DownloadsPreferencesPersistorMock(selectedDownloadLocation: testDirectory.absoluteString)
        let preferences = DownloadsPreferencesModel(persistor: persistor)

        deleteTemporaryTestDirectory()

        XCTAssertEqual(preferences.effectiveDownloadLocation, DownloadsPreferencesModel.defaultDownloadLocation())
    }

    private func createTemporaryTestDirectory(named name: String = DownloadsPreferencesModelTests.defaultTestDirectoryName) -> URL {
        let baseTemporaryDirectoryURL = FileManager.default.temporaryDirectory
        let testTemporaryDirectoryURL = baseTemporaryDirectoryURL.appendingPathComponent(name)

        do {
            try FileManager.default.createDirectory(at: testTemporaryDirectoryURL, withIntermediateDirectories: false, attributes: nil)
        } catch {
            XCTFail("Failed to create temporary test directory: \(error)")
        }

        return testTemporaryDirectoryURL
    }

    private func deleteTemporaryTestDirectory(named name: String = DownloadsPreferencesModelTests.defaultTestDirectoryName) {
        let baseTemporaryDirectoryURL = FileManager.default.temporaryDirectory

        try? FileManager.default.removeItem(at: baseTemporaryDirectoryURL.appendingPathComponent(name))
    }
}
