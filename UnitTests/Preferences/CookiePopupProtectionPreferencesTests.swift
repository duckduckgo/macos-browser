//
//  CookiePopupProtectionPreferencesTests.swift
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

class MockCookiePopupProtectionPreferencesPersistor: CookiePopupProtectionPreferencesPersistor {
    var autoconsentEnabled: Bool = false
}

class CookiePopupProtectionPreferencesTests: XCTestCase {

    func testWhenInitializedThenItLoadsPersistedAutoconsentSetting() {
        let mockPersistor = MockCookiePopupProtectionPreferencesPersistor()
        mockPersistor.autoconsentEnabled = true
        let cookiePopupPreferences = CookiePopupProtectionPreferences(persistor: mockPersistor)

        XCTAssertTrue(cookiePopupPreferences.isAutoconsentEnabled)
    }

    func testWhenIsAutoconsentEnabledUpdatedThenPersistorUpdates() {
        let mockPersistor = MockCookiePopupProtectionPreferencesPersistor()
        let cookiePopupPreferences = CookiePopupProtectionPreferences(persistor: mockPersistor)
        cookiePopupPreferences.isAutoconsentEnabled = false

        XCTAssertFalse(mockPersistor.autoconsentEnabled)
    }

}
