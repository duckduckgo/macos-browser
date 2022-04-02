//
//  LoginsPreferencesModelTests.swift
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
    var shouldAutoLockLogins: Bool = true
    var autoLockThreshold: LoginsAutoLockThreshold = .fifteenMinutes
    var askToSaveUsernamesAndPasswords: Bool = true
    var askToSaveAddresses: Bool = true
    var askToSavePaymentMethods: Bool = true
}

final class LoginsPreferencesModelTests: XCTestCase {

    func testThatPreferencesArePersisted() throws {
        let persistor = LoginsPreferencesPersistorMock()
        let model = LoginsPreferencesModel(persistor: persistor)

        model.shouldAutoLockLogins.toggle()
        XCTAssertEqual(persistor.shouldAutoLockLogins, model.shouldAutoLockLogins)

        model.autoLockThreshold = .fiveMinutes
        XCTAssertEqual(persistor.autoLockThreshold, LoginsAutoLockThreshold.fiveMinutes)

        model.askToSaveUsernamesAndPasswords.toggle()
        XCTAssertEqual(persistor.askToSaveUsernamesAndPasswords, model.askToSaveUsernamesAndPasswords)

        model.askToSaveAddresses.toggle()
        XCTAssertEqual(persistor.askToSaveAddresses, model.askToSaveAddresses)

        model.askToSavePaymentMethods.toggle()
        XCTAssertEqual(persistor.askToSavePaymentMethods, model.askToSavePaymentMethods)
    }
}
