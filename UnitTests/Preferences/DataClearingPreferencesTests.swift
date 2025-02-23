//
//  DataClearingPreferencesTests.swift
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

class MockFireButtonPreferencesPersistor: FireButtonPreferencesPersistor {

    var autoClearEnabled: Bool = false
    var warnBeforeClearingEnabled: Bool = false
    var loginDetectionEnabled: Bool = false
    var oneClickFireButton: Bool = false

}

class DataClearingPreferencesTests: XCTestCase {

    func testWhenInitializedThenItLoadsPersistedLoginDetectionSetting() {
        let mockPersistor = MockFireButtonPreferencesPersistor()
        mockPersistor.loginDetectionEnabled = true
        let dataClearingPreferences = DataClearingPreferences(persistor: mockPersistor)

        XCTAssertTrue(dataClearingPreferences.isLoginDetectionEnabled)
    }

    func testWhenIsLoginDetectionEnabledUpdatedThenPersistorUpdates() {
        let mockPersistor = MockFireButtonPreferencesPersistor()
        let dataClearingPreferences = DataClearingPreferences(persistor: mockPersistor)
        dataClearingPreferences.isLoginDetectionEnabled = true

        XCTAssertTrue(mockPersistor.loginDetectionEnabled)
    }
}
