//
//  HomePageRootViewModelTests.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

final class HomePageRootViewModelTests: XCTestCase {

    func testWhenInitializedThenItLoadsPersistedValues() throws {
        var persistor = HomePage.Models.HomePagePreferencesUserDefaultsPersistor()
        persistor.isFavouriteVisible = true
        persistor.isContinueSetUpVisible = true
        persistor.isRecentActivityVisible = true

        var model = HomePage.Models.HomePageRootViewModel(homePagePreferencesPersistor: persistor)

        XCTAssertTrue(model.isFavouriteVisible)
        XCTAssertTrue(model.isContinueSetUpVisible)
        XCTAssertTrue(model.isRecentActivityVisible)

        persistor.isFavouriteVisible = false
        persistor.isContinueSetUpVisible = false
        persistor.isRecentActivityVisible = false

        model = HomePage.Models.HomePageRootViewModel(homePagePreferencesPersistor: persistor)

        XCTAssertFalse(model.isFavouriteVisible)
        XCTAssertFalse(model.isContinueSetUpVisible)
        XCTAssertFalse(model.isRecentActivityVisible)
    }

    func testWhenPropertiesAreUpdatedThenPersistedValuesAreUpdated() throws {
        var persistor = HomePage.Models.HomePagePreferencesUserDefaultsPersistor()
        var model = HomePage.Models.HomePageRootViewModel(homePagePreferencesPersistor: persistor)

        model.isRecentActivityVisible = true
        XCTAssertEqual(persistor.isRecentActivityVisible, true)
        model.isFavouriteVisible = true
        XCTAssertEqual(persistor.isFavouriteVisible, true)
        model.isContinueSetUpVisible = true
        XCTAssertEqual(persistor.isContinueSetUpVisible, true)

        model.isRecentActivityVisible = false
        XCTAssertEqual(persistor.isRecentActivityVisible, false)
        model.isFavouriteVisible = false
        XCTAssertEqual(persistor.isFavouriteVisible, false)
        model.isContinueSetUpVisible = false
        XCTAssertEqual(persistor.isContinueSetUpVisible, false)

    }

    func testPersisterReturnsValuesFromDisk() {
        UserDefaultsWrapper<Any>.clearAll()
        var persister1 = HomePage.Models.HomePagePreferencesUserDefaultsPersistor()
        var persister2 = HomePage.Models.HomePagePreferencesUserDefaultsPersistor()

        persister2.isFavouriteVisible = false
        persister1.isFavouriteVisible = true
        persister2.isRecentActivityVisible = false
        persister1.isRecentActivityVisible = true
        persister2.isContinueSetUpVisible = false
        persister1.isContinueSetUpVisible = true

        XCTAssertTrue(persister2.isFavouriteVisible)
        XCTAssertTrue(persister2.isRecentActivityVisible)
        XCTAssertTrue(persister2.isContinueSetUpVisible)
    }
}
