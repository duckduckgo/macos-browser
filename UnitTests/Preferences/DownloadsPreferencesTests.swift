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

class DownloadsPreferencesPersistorMock: DownloadsPreferencesPersistor {

    var selectedDownloadLocation: String?
    var alwaysRequestDownloadLocation: Bool
    var defaultDownloadLocation: URL?
    var lastUsedCustomDownloadLocation: String?
    var shouldOpenPopupOnCompletion: Bool

    var _isDownloadLocationValid: (URL) -> Bool

    func isDownloadLocationValid(_ location: URL) -> Bool {
        _isDownloadLocationValid(location)
    }

    init(
        selectedDownloadLocation: String? = nil,
        alwaysRequestDownloadLocation: Bool = false,
        shouldOpenPopupOnCompletion: Bool = true,
        defaultDownloadLocation: URL? = FileManager.default.temporaryDirectory,
        lastUsedCustomDownloadLocation: String? = nil,
        isDownloadLocationValid: @escaping (URL) -> Bool = { _ in true }
    ) {
        self.selectedDownloadLocation = selectedDownloadLocation
        self.alwaysRequestDownloadLocation = alwaysRequestDownloadLocation
        self.shouldOpenPopupOnCompletion = shouldOpenPopupOnCompletion
        self.defaultDownloadLocation = defaultDownloadLocation
        self.lastUsedCustomDownloadLocation = lastUsedCustomDownloadLocation
        self._isDownloadLocationValid = isDownloadLocationValid
    }

    func values() -> [String: any Equatable] {
        var result = [String: any Equatable]()
        for (label, value) in Mirror(reflecting: self).children {
            guard let label, let value = value as? any Equatable else { continue }
            result[label] = value
        }
        return result
    }
}
extension [String: any Equatable] {
    func difference(from other: Self) -> Set<String> {
        func areEqual<T: Equatable>(_ lhs: T, with rhs: any Equatable) -> Bool {
            guard let rhs = rhs as? T else { return false }
            return lhs == rhs
        }

        var result = Set(self.keys).symmetricDifference(other.keys)
        for (key, lhs) in self {
            guard let rhs = other[key] else { continue }
            if !areEqual(lhs, with: rhs) {
                result.insert(key)
            }
        }
        return result
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

        XCTAssertEqual(preferences.effectiveDownloadLocation, DownloadsPreferences.defaultDownloadLocation())
    }

    func testWhenGettingSelectedDownloadLocationAndSelectedLocationIsInaccessibleThenDefaultDownloadLocationIsReturned() {
        let testDirectory = createTemporaryTestDirectory()
        let persistor = DownloadsPreferencesPersistorMock(selectedDownloadLocation: testDirectory.absoluteString)
        let preferences = DownloadsPreferences(persistor: persistor)

        deleteTemporaryTestDirectory()

        XCTAssertEqual(preferences.effectiveDownloadLocation, DownloadsPreferences.defaultDownloadLocation())
    }

    func testShouldOpenPopupOnCompletionSetting() {
        let persistor1 = DownloadsPreferencesPersistorMock(shouldOpenPopupOnCompletion: true)
        var preferences = DownloadsPreferences(persistor: persistor1)
        XCTAssertTrue(preferences.shouldOpenPopupOnCompletion)

        let persistor2 = DownloadsPreferencesPersistorMock(shouldOpenPopupOnCompletion: false)
        preferences = DownloadsPreferences(persistor: persistor2)
        XCTAssertFalse(preferences.shouldOpenPopupOnCompletion)

        var eObjectWillChangeCalled = expectation(description: "object will change called 1")
        let c = preferences.objectWillChange.sink {
            eObjectWillChangeCalled.fulfill()
        }

        let valuesWithTrue = persistor1.values()
        let valuesWithFalse = persistor2.values()
        XCTAssertEqual(valuesWithTrue.difference(from: valuesWithFalse), ["\(\DownloadsPreferencesPersistorMock.shouldOpenPopupOnCompletion)".pathExtension])

        preferences.shouldOpenPopupOnCompletion = true
        waitForExpectations(timeout: 0)
        XCTAssertTrue(preferences.shouldOpenPopupOnCompletion)
        XCTAssertEqual(persistor2.values().difference(from: valuesWithTrue), [])

        eObjectWillChangeCalled = expectation(description: "object will change called 2")
        preferences.shouldOpenPopupOnCompletion = false
        waitForExpectations(timeout: 0)
        XCTAssertFalse(preferences.shouldOpenPopupOnCompletion)
        XCTAssertEqual(persistor2.values().difference(from: valuesWithFalse), [])
        withExtendedLifetime(c) {}
    }

    func testWhenLastUsedCustomDownloadLocationIsSet_lastDownloadLocationIsReturned() {
        let testDirectory = createTemporaryTestDirectory()
        let persistor = DownloadsPreferencesPersistorMock(selectedDownloadLocation: nil)
        let preferences = DownloadsPreferences(persistor: persistor)

        let valuesBeforeChange = persistor.values()
        preferences.lastUsedCustomDownloadLocation = testDirectory

        let valuesAfterChange = persistor.values()
        XCTAssertEqual(valuesBeforeChange.difference(from: valuesAfterChange), ["\(\DownloadsPreferencesPersistorMock.lastUsedCustomDownloadLocation)".pathExtension])
        XCTAssertEqual(preferences.lastUsedCustomDownloadLocation, testDirectory)
    }

    func testWhenLastUsedCustomDownloadLocationIsRemoved_nilIsReturned() {
        let testDirectory = createTemporaryTestDirectory()
        let persistor = DownloadsPreferencesPersistorMock(selectedDownloadLocation: nil)
        let preferences = DownloadsPreferences(persistor: persistor)

        let valuesBeforeChange = persistor.values()
        preferences.lastUsedCustomDownloadLocation = testDirectory
        deleteTemporaryTestDirectory()

        let valuesAfterChange = persistor.values()
        XCTAssertEqual(valuesBeforeChange.difference(from: valuesAfterChange), ["\(\DownloadsPreferencesPersistorMock.lastUsedCustomDownloadLocation)".pathExtension])
        XCTAssertNil(preferences.lastUsedCustomDownloadLocation)
    }

    func testWhenInvalidLastUsedCustomDownloadLocationIsSet_lastUsedCustomLocationIsNil() {
        let testDirectory = createTemporaryTestDirectory()
        let persistor = DownloadsPreferencesPersistorMock(selectedDownloadLocation: nil)
        let preferences = DownloadsPreferences(persistor: persistor)

        preferences.lastUsedCustomDownloadLocation = testDirectory
        preferences.lastUsedCustomDownloadLocation = testDirectory.appendingPathComponent("non-existent-dir")

        XCTAssertNil(preferences.lastUsedCustomDownloadLocation)
    }

    func testWhenLastUsedCustomDownloadLocationIsReset_nilIsReturned() {
        let testDirectory = createTemporaryTestDirectory()
        let persistor = DownloadsPreferencesPersistorMock(selectedDownloadLocation: nil)
        let preferences = DownloadsPreferences(persistor: persistor)

        let valuesBeforeChange = persistor.values()
        preferences.lastUsedCustomDownloadLocation = testDirectory
        preferences.lastUsedCustomDownloadLocation = testDirectory.appendingPathComponent("non-existent-dir")
        deleteTemporaryTestDirectory()

        let valuesAfterChange = persistor.values()
        XCTAssertEqual(valuesBeforeChange.difference(from: valuesAfterChange), ["\(\DownloadsPreferencesPersistorMock.lastUsedCustomDownloadLocation)".pathExtension])
        XCTAssertNil(preferences.lastUsedCustomDownloadLocation)
    }

}

private extension DownloadsPreferencesTests {

    func createTemporaryTestDirectory(named name: String = DownloadsPreferencesTests.defaultTestDirectoryName) -> URL {
        let baseTemporaryDirectoryURL = FileManager.default.temporaryDirectory
        let testTemporaryDirectoryURL = baseTemporaryDirectoryURL.appendingPathComponent(name)

        do {
            try FileManager.default.createDirectory(at: testTemporaryDirectoryURL, withIntermediateDirectories: false, attributes: nil)
        } catch {
            XCTFail("Failed to create temporary test directory: \(error)")
        }

        return testTemporaryDirectoryURL
    }

    func deleteTemporaryTestDirectory(named name: String = DownloadsPreferencesTests.defaultTestDirectoryName) {
        let baseTemporaryDirectoryURL = FileManager.default.temporaryDirectory

        try? FileManager.default.removeItem(at: baseTemporaryDirectoryURL.appendingPathComponent(name))
    }
}
