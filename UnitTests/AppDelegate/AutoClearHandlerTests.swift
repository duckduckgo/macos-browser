//
//  AutoClearHandlerTests.swift
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
class AutoClearHandlerTests: XCTestCase {

    var handler: AutoClearHandler!
    var preferences: DataClearingPreferences!
    var fireViewModel: FireViewModel!

    override func setUp() {
        super.setUp()
        let persistor = MockFireButtonPreferencesPersistor()
        preferences = DataClearingPreferences(persistor: persistor)
        fireViewModel = FireViewModel(fire: Fire(tld: ContentBlocking.shared.tld))
        let fileName = "AutoClearHandlerTests"
        let fileStore = FileStoreMock()
        let service = StatePersistenceService(fileStore: fileStore, fileName: fileName)
        let appStateRestorationManager = AppStateRestorationManager(fileStore: fileStore,
                                                                    service: service,
                                                                    shouldRestorePreviousSession: false)
        handler = AutoClearHandler(preferences: preferences, fireViewModel: fireViewModel, stateRestorationManager: appStateRestorationManager)
    }

    override func tearDown() {
        handler = nil
        preferences = nil
        fireViewModel = nil
        super.tearDown()
    }

    func testWhenBurningEnabledAndNoWarningRequiredThenTerminateLaterIsReturned() {
            preferences.isAutoClearEnabled = true
            preferences.isWarnBeforeClearingEnabled = false

            let response = handler.handleAppTermination()

            XCTAssertEqual(response, .terminateLater)
        }

        func testWhenBurningDisabledThenNoTerminationResponse() {
            preferences.isAutoClearEnabled = false

            let response = handler.handleAppTermination()

            XCTAssertNil(response)
        }

        func testWhenBurningEnabledAndFlagFalseThenBurnOnStartTriggered() {
            preferences.isAutoClearEnabled = true
            handler.resetTheCorrectTerminationFlag()

            XCTAssertTrue(handler.burnOnStartIfNeeded())
        }

        func testWhenBurningDisabledThenBurnOnStartNotTriggered() {
            preferences.isAutoClearEnabled = false
            handler.resetTheCorrectTerminationFlag()

            XCTAssertFalse(handler.burnOnStartIfNeeded())
        }

}
