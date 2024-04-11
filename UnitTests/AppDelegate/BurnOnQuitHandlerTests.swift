//
//  BurnOnQuitHandlerTests.swift
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

import Foundation
import XCTest

@testable import DuckDuckGo_Privacy_Browser

@MainActor
class BurnOnQuitHandlerTests: XCTestCase {

    var handler: BurnOnQuitHandler!
    var preferences: DataClearingPreferences!
    var fireViewModel: FireViewModel!

    override func setUp() {
        super.setUp()
        let persistor = MockFireButtonPreferencesPersistor()
        preferences = DataClearingPreferences(persistor: persistor)
        fireViewModel = FireViewModel(fire: Fire(tld: ContentBlocking.shared.tld))
        handler = BurnOnQuitHandler(preferences: preferences, fireViewModel: fireViewModel)
    }

    override func tearDown() {
        handler = nil
        preferences = nil
        fireViewModel = nil
        super.tearDown()
    }

    func testWhenBurningEnabledAndNoWarningRequiredThenTerminateLaterIsReturned() {
            preferences.isBurnDataOnQuitEnabled = true
            preferences.isWarnBeforeClearingEnabled = false

            let response = handler.handleAppTermination()

            XCTAssertEqual(response, .terminateLater)
        }

        func testWhenBurningDisabledThenNoTerminationResponse() {
            preferences.isBurnDataOnQuitEnabled = false

            let response = handler.handleAppTermination()

            XCTAssertNil(response)
        }

        func testWhenBurningEnabledAndFlagFalseThenBurnOnStartTriggered() {
            preferences.isBurnDataOnQuitEnabled = true
            handler.resetTheFlag()

            XCTAssertTrue(handler.burnOnStartIfNeeded())
        }

        func testWhenBurningDisabledThenBurnOnStartNotTriggered() {
            preferences.isBurnDataOnQuitEnabled = false
            handler.resetTheFlag()

            XCTAssertFalse(handler.burnOnStartIfNeeded())
        }

}
