//
//  LoginsPreferencesTests.swift
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
import Combine
@testable import DuckDuckGo_Privacy_Browser

final class LoginsPreferencesPersistorMock: LoginsPreferencesPersistor {
    var askToSaveUsernamesAndPasswords: Bool = true
    var askToSaveAddresses: Bool = true
    var askToSavePaymentMethods: Bool = true
}

final class LoginsPreferencesTests: XCTestCase {

    func testWhenShouldAutoLockLoginsIsChangedThenNotificationIsSent() throws {
        let model = LoginsPreferences(statisticsStore: MockStatisticsStore(), persistor: LoginsPreferencesPersistorMock())

        _ = expectation(forNotification: .loginsAutoLockSettingsDidChange, object: nil)
        model.shouldAutoLockLogins.toggle()

        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func testThatAutoLockThresholdDefaultsTo15Minutes() throws {
        let statisticsStore = MockStatisticsStore()
        statisticsStore.autoLockThreshold = nil

        let model = LoginsPreferences(statisticsStore: statisticsStore, persistor: LoginsPreferencesPersistorMock())

        XCTAssertEqual(model.autoLockThreshold, .fifteenMinutes)
    }

    func testThatPreferencesArePersisted() throws {
        let statisticsStore = MockStatisticsStore()
        let persistor = LoginsPreferencesPersistorMock()
        let model = LoginsPreferences(statisticsStore: statisticsStore, persistor: persistor)

        model.autoLockThreshold = .fiveMinutes
        XCTAssertEqual(statisticsStore.autoLockThreshold, LoginsPreferences.AutoLockThreshold.fiveMinutes.rawValue)

        model.shouldAutoLockLogins.toggle()
        XCTAssertEqual(statisticsStore.autoLockEnabled, model.shouldAutoLockLogins)

        model.askToSaveUsernamesAndPasswords.toggle()
        XCTAssertEqual(persistor.askToSaveUsernamesAndPasswords, model.askToSaveUsernamesAndPasswords)

        model.askToSaveAddresses.toggle()
        XCTAssertEqual(persistor.askToSaveAddresses, model.askToSaveAddresses)

        model.askToSavePaymentMethods.toggle()
        XCTAssertEqual(persistor.askToSavePaymentMethods, model.askToSavePaymentMethods)
    }
}
