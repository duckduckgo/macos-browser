//
//  SearchPreferencesTests.swift
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

import PixelKit
import XCTest
@testable import DuckDuckGo_Privacy_Browser

class MockSearchPreferencesPersistor: SearchPreferencesPersistor {
    var showAutocompleteSuggestions: Bool = false
}

class SearchPreferencesTests: XCTestCase {

    override func setUpWithError() throws {
        PixelKit.setUp(appVersion: "",
                       defaultHeaders: [:],
                       defaults: UserDefaults()) { _, _, _, _, _, _ in }
    }

    override func tearDownWithError() throws {
        PixelKit.tearDown()
    }

    func testWhenInitializedThenItLoadsPersistedValues() {
        let mockPersistor = MockSearchPreferencesPersistor()
        mockPersistor.showAutocompleteSuggestions = true
        let searchPreferences = SearchPreferences(persistor: mockPersistor)

        XCTAssertTrue(searchPreferences.showAutocompleteSuggestions)
    }

    func testWhenShowAutocompleteSuggestionsUpdatedThenPersistorUpdates() {
        let mockPersistor = MockSearchPreferencesPersistor()
        let searchPreferences = SearchPreferences(persistor: mockPersistor)
        searchPreferences.showAutocompleteSuggestions = true

        XCTAssertTrue(mockPersistor.showAutocompleteSuggestions)
    }

}
