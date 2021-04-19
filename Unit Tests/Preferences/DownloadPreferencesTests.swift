//
//  DownloadPreferencesTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class DownloadPreferencesTests: XCTestCase {

    private let testGroupName = "test"
    private let testDownloadDirectoryURL: URL = {
        let baseTemporaryDirectoryURL = FileManager.default.temporaryDirectory
        return baseTemporaryDirectoryURL.appendingPathComponent("DownloadPreferencesTests")
    }()

    override func setUp() {
        super.setUp()

        deleteTemporaryTestDirectory(at: testDownloadDirectoryURL)
        UserDefaultsWrapper<Any>.clearAll()
        UserDefaults(suiteName: testGroupName)?.removePersistentDomain(forName: testGroupName)
    }

    override func tearDown() {
        deleteTemporaryTestDirectory(at: testDownloadDirectoryURL)

        super.tearDown()
    }

    func testWhenSettingNilDownloadLocationThenDefaultDownloadLocationIsReturned() {
        var preferences = createDownloadPreferences()
        let testDirectory = createTemporaryTestDirectory()

        preferences.selectedDownloadLocation = testDirectory
        XCTAssertEqual(preferences.selectedDownloadLocation, testDirectory)

        preferences.selectedDownloadLocation = nil
        XCTAssertEqual(preferences.selectedDownloadLocation, preferences.defaultDownloadLocation())
    }

    func testWhenGettingSelectedDownloadLocationThenDefaultDownloadLocationIsReturned() {
        let preferences = createDownloadPreferences()
        let defaultURL = preferences.selectedDownloadLocation

        XCTAssertNotNil(defaultURL)
        XCTAssertEqual(defaultURL, preferences.defaultDownloadLocation())
    }

    func testWhenSettingDownloadLocationThatDoesNotExistThenDefaultDownloadLocationIsReturned() {
        var preferences = createDownloadPreferences()
        let invalidDownloadLocationURL = FileManager.default.temporaryDirectory.appendingPathComponent("InvalidDownloadLocation")

        preferences.selectedDownloadLocation = invalidDownloadLocationURL
        XCTAssertEqual(preferences.selectedDownloadLocation, preferences.defaultDownloadLocation())
    }

    func testWhenGettingSelectedDownloadLocationAndSelectedLocationIsInaccessibleThenDefaultDownloadLocationIsReturned() {
        var preferences = createDownloadPreferences()
        let testDirectory = createTemporaryTestDirectory()

        preferences.selectedDownloadLocation = testDirectory
        XCTAssertEqual(preferences.selectedDownloadLocation, testDirectory)

        deleteTemporaryTestDirectory(at: testDirectory)
        XCTAssertEqual(preferences.selectedDownloadLocation, preferences.defaultDownloadLocation())
    }

    private func createDownloadPreferences() -> DownloadPreferences {
        let testUserDefaults = UserDefaults(suiteName: testGroupName)
        return DownloadPreferences(userDefaults: testUserDefaults!)
    }

    private func createTemporaryTestDirectory(named name: String = "DownloadPreferencesTests") -> URL {
        let baseTemporaryDirectoryURL = FileManager.default.temporaryDirectory
        let testTemporaryDirectoryURL = baseTemporaryDirectoryURL.appendingPathComponent(name)

        do {
            try FileManager.default.createDirectory(at: testTemporaryDirectoryURL, withIntermediateDirectories: false, attributes: nil)
        } catch {
            XCTFail("Failed to create temporary test directory: \(error)")
        }

        return testTemporaryDirectoryURL
    }

    private func deleteTemporaryTestDirectory(at url: URL) {
        let baseTemporaryDirectoryURL = FileManager.default.temporaryDirectory
        assert(url.absoluteString.hasPrefix(baseTemporaryDirectoryURL.absoluteString))

        try? FileManager.default.removeItem(at: url)
    }

}
