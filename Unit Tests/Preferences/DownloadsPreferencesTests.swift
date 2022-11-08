//
//  DownloadsPreferencesTests.swift
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
    var lastUsedCustomDownloadLocation: String?

    // swiftlint:disable:next identifier_name
    var _isDownloadLocationValid: (URL) -> Bool

    func isDownloadLocationValid(_ location: URL) -> Bool {
        _isDownloadLocationValid(location)
    }

    init(
        selectedDownloadLocation: String? = nil,
        alwaysRequestDownloadLocation: Bool = false,
        defaultDownloadLocation: URL? = FileManager.default.temporaryDirectory,
        lastUsedCustomDownloadLocation: String? = nil,
        isDownloadLocationValid: @escaping (URL) -> Bool = { _ in true }
    ) {
        self.selectedDownloadLocation = selectedDownloadLocation
        self.alwaysRequestDownloadLocation = alwaysRequestDownloadLocation
        self.defaultDownloadLocation = defaultDownloadLocation
        self.lastUsedCustomDownloadLocation = lastUsedCustomDownloadLocation
        self._isDownloadLocationValid = isDownloadLocationValid
    }
}

class DownloadsPreferencesTests: XCTestCase {

    static let defaultTestDirectoryName = "DownloadsPreferencesTests"

    override func setUpWithError() throws {
        try super.setUpWithError()

        deleteTemporaryTestDirectory()
    }
  
    func testWhenAlwaysAskIsOnAndCustomLocationWasSetThenEffectiveDownloadLocationIsReturned() {
        let testDirectory = createTemporaryTestDirectory()
        let persistor = DownloadsPreferencesPersistorMock(selectedDownloadLocation: nil, alwaysRequestDownloadLocation: true)
        let preferences = DownloadsPreferences(persistor: persistor)

        preferences.lastUsedCustomDownloadLocation = testDirectory

        XCTAssertEqual(preferences.effectiveDownloadLocation, testDirectory)
    }
    
    func testWhenAlwaysAskIsOnAndCustomLocationWasNotSetThenEffectiveDownloadLocationIsReturned() {
        let testDirectory = createTemporaryTestDirectory()
        let persistor = DownloadsPreferencesPersistorMock(selectedDownloadLocation: nil, alwaysRequestDownloadLocation: true)
        let preferences = DownloadsPreferences(persistor: persistor)

        XCTAssertEqual(preferences.effectiveDownloadLocation, DownloadsPreferences.defaultDownloadLocation())
    }
    
    func testWhenAlwaysAskIsOnAndCustomLocationWasSetAndRemovedFromDiskThenEffectiveDownloadLocationIsReturned() {
        let testDirectory = createTemporaryTestDirectory()
        let persistor = DownloadsPreferencesPersistorMock(selectedDownloadLocation: nil, alwaysRequestDownloadLocation: true)
        let preferences = DownloadsPreferences(persistor: persistor)

        preferences.lastUsedCustomDownloadLocation = testDirectory
        deleteTemporaryTestDirectory()
        
        XCTAssertEqual(preferences.effectiveDownloadLocation, DownloadsPreferences.defaultDownloadLocation())
    }
    
    func testWhenSettingNilDownloadLocationThenDefaultDownloadLocationIsReturned() {
        let testDirectory = createTemporaryTestDirectory()
        let persistor = DownloadsPreferencesPersistorMock(selectedDownloadLocation: nil)
        let preferences = DownloadsPreferences(persistor: persistor)

        preferences.selectedDownloadLocation = testDirectory
        XCTAssertEqual(preferences.effectiveDownloadLocation, testDirectory)

        preferences.selectedDownloadLocation = nil
        XCTAssertEqual(preferences.effectiveDownloadLocation, DownloadsPreferences.defaultDownloadLocation())
    }

    func testWhenDownloadLocationIsNotPersistedThenDefaultDownloadLocationIsReturned() {
        let persistor = DownloadsPreferencesPersistorMock(selectedDownloadLocation: nil)
        let preferences = DownloadsPreferences(persistor: persistor)

        XCTAssertEqual(preferences.effectiveDownloadLocation, DownloadsPreferences.defaultDownloadLocation())
    }

    func testWhenDownloadLocationIsNotWritableThenDefaultDownloadLocationIsReturned() {
        let testDirectory = createTemporaryTestDirectory()
        let persistor = DownloadsPreferencesPersistorMock(selectedDownloadLocation: testDirectory.absoluteString)
        let preferences = DownloadsPreferences(persistor: persistor)

        let invalidDownloadLocationURL = FileManager.default.temporaryDirectory.appendingPathComponent("InvalidDownloadLocation")

        preferences.selectedDownloadLocation = invalidDownloadLocationURL

        XCTAssertEqual(preferences.effectiveDownloadLocation, testDirectory)
    }

    func testWhenGettingSelectedDownloadLocationAndSelectedLocationIsInaccessibleThenDefaultDownloadLocationIsReturned() {
        let testDirectory = createTemporaryTestDirectory()
        let persistor = DownloadsPreferencesPersistorMock(selectedDownloadLocation: testDirectory.absoluteString)
        let preferences = DownloadsPreferences(persistor: persistor)

        deleteTemporaryTestDirectory()

        XCTAssertEqual(preferences.effectiveDownloadLocation, DownloadsPreferences.defaultDownloadLocation())
    }

    private func createTemporaryTestDirectory(named name: String = DownloadsPreferencesTests.defaultTestDirectoryName) -> URL {
        let baseTemporaryDirectoryURL = FileManager.default.temporaryDirectory
        let testTemporaryDirectoryURL = baseTemporaryDirectoryURL.appendingPathComponent(name)

        do {
            try FileManager.default.createDirectory(at: testTemporaryDirectoryURL, withIntermediateDirectories: false, attributes: nil)
        } catch {
            XCTFail("Failed to create temporary test directory: \(error)")
        }

        return testTemporaryDirectoryURL
    }

    private func deleteTemporaryTestDirectory(named name: String = DownloadsPreferencesTests.defaultTestDirectoryName) {
        let baseTemporaryDirectoryURL = FileManager.default.temporaryDirectory

        try? FileManager.default.removeItem(at: baseTemporaryDirectoryURL.appendingPathComponent(name))
    }
}
