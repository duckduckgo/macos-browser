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

class DownloadsPreferencesTests: XCTestCase {

    static let defaultTestDirectoryName = "DownloadsPreferencesTests"
    
    // swiftlint:disable:next implicitly_unwrapped_optional
    var persistor: DownloadsPreferencesPersistorMock!

    override func setUpWithError() throws {
        try super.setUpWithError()

        persistor = DownloadsPreferencesPersistorMock()
        persistor.alwaysRequestDownloadLocation = false
        persistor.defaultDownloadLocation = FileManager.default.temporaryDirectory
        persistor.isDownloadLocationValidClosure = { _ in true }

        deleteTemporaryTestDirectory()
    }

    func testWhenSettingNilDownloadLocationThenDefaultDownloadLocationIsReturned() {
        let testDirectory = createTemporaryTestDirectory()
        let preferences = DownloadsPreferences(persistor: persistor)

        preferences.selectedDownloadLocation = testDirectory
        XCTAssertEqual(preferences.effectiveDownloadLocation, testDirectory)

        preferences.selectedDownloadLocation = nil
        XCTAssertEqual(preferences.effectiveDownloadLocation, DownloadsPreferences.defaultDownloadLocation())
    }

    func testWhenDownloadLocationIsNotPersistedThenDefaultDownloadLocationIsReturned() {
        let preferences = DownloadsPreferences(persistor: persistor)

        XCTAssertEqual(preferences.effectiveDownloadLocation, DownloadsPreferences.defaultDownloadLocation())
    }

    func testWhenDownloadLocationIsNotWritableThenDefaultDownloadLocationIsReturned() {
        let testDirectory = createTemporaryTestDirectory()
        persistor.selectedDownloadLocation = testDirectory.absoluteString
        let preferences = DownloadsPreferences(persistor: persistor)

        let invalidDownloadLocationURL = FileManager.default.temporaryDirectory.appendingPathComponent("InvalidDownloadLocation")

        preferences.selectedDownloadLocation = invalidDownloadLocationURL

        XCTAssertEqual(preferences.effectiveDownloadLocation, testDirectory)
    }

    func testWhenGettingSelectedDownloadLocationAndSelectedLocationIsInaccessibleThenDefaultDownloadLocationIsReturned() {
        let testDirectory = createTemporaryTestDirectory()
        persistor.selectedDownloadLocation = testDirectory.absoluteString
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
