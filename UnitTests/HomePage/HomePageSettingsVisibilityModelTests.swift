//
//  HomePageSettingsVisibilityModelTests.swift
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

final class MockSettingsVisibilityModelPersistor: SettingsVisibilityModelPersistor {
    var didShowSettingsOnboarding: Bool = false
}

final class HomePageSettingsVisibilityModelTests: XCTestCase {
    var persistor: MockSettingsVisibilityModelPersistor!
    var model: HomePage.Models.SettingsVisibilityModel!

    override func setUp() {
        super.setUp()
        persistor = MockSettingsVisibilityModelPersistor()
        model = .init(persistor: persistor)
    }

    func testThatDidShowSettingsOnboardingIsPersisted() {
        model.didShowSettingsOnboarding = true
        XCTAssertTrue(persistor.didShowSettingsOnboarding)
        model.didShowSettingsOnboarding = false
        XCTAssertFalse(persistor.didShowSettingsOnboarding)
    }
}
