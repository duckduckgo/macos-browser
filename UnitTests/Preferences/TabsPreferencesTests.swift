//
//  TabsPreferencesTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

class MockTabsPreferencesPersistor: TabsPreferencesPersistor {
    var preferNewTabsToWindows: Bool = false
    var switchToNewTabWhenOpened: Bool = false
    var newTabPosition: NewTabPosition = .atEnd
}

final class TabsPreferencesTests: XCTestCase {

    func testWhenInitializedThenItLoadsPersistedValues() {
        let mockPersistor = MockTabsPreferencesPersistor()
        mockPersistor.preferNewTabsToWindows = true
        mockPersistor.switchToNewTabWhenOpened = true
        mockPersistor.newTabPosition = .nextToCurrent
        let tabsPreferences = TabsPreferences(persistor: mockPersistor)

        XCTAssertTrue(tabsPreferences.preferNewTabsToWindows)
        XCTAssertTrue(tabsPreferences.switchToNewTabWhenOpened)
        XCTAssertEqual(tabsPreferences.newTabPosition, .nextToCurrent)
    }

    func testWhenPreferencesUpdatedThenPersistorUpdates() {
        let mockPersistor = MockTabsPreferencesPersistor()
        let tabsPreferences = TabsPreferences(persistor: mockPersistor)
        tabsPreferences.preferNewTabsToWindows = true
        tabsPreferences.switchToNewTabWhenOpened = true
        tabsPreferences.newTabPosition = .nextToCurrent

        XCTAssertTrue(mockPersistor.preferNewTabsToWindows)
        XCTAssertTrue(mockPersistor.switchToNewTabWhenOpened)
        XCTAssertEqual(mockPersistor.newTabPosition, .nextToCurrent)
    }
}
