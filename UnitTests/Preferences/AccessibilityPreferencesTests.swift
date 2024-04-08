//
//  AccessibilityPreferencesTests.swift
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

class MockAccessibilityPreferencesPersistor: AccessibilityPreferencesPersistor {
    var defaultPageZoom: CGFloat = DefaultZoomValue.percent100.rawValue
}

class AccessibilityPreferencesTests: XCTestCase {

    func testWhenInitializedThenItLoadsPersistedDefaultPageZoom() {
        let mockPersistor = MockAccessibilityPreferencesPersistor()
        mockPersistor.defaultPageZoom = DefaultZoomValue.percent150.rawValue
        let accessibilityPreferences = AccessibilityPreferences(persistor: mockPersistor)

        XCTAssertEqual(accessibilityPreferences.defaultPageZoom, DefaultZoomValue.percent150)
    }

    func testWhenDefaultPageZoomUpdatedThenPersistorUpdates() {
        let mockPersistor = MockAccessibilityPreferencesPersistor()
        let accessibilityPreferences = AccessibilityPreferences(persistor: mockPersistor)
        accessibilityPreferences.defaultPageZoom = .percent75

        XCTAssertEqual(mockPersistor.defaultPageZoom, DefaultZoomValue.percent75.rawValue)
    }

}
