//
//  AutofillPreferencesModelTests.swift
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

final class AutofillPreferencesPersistorMock: AutofillPreferencesPersistor {
    var isAutoLockEnabled: Bool = true
    var autoLockThreshold: AutofillAutoLockThreshold = .fifteenMinutes
    var askToSaveUsernamesAndPasswords: Bool = true
    var askToSaveAddresses: Bool = true
    var askToSavePaymentMethods: Bool = true
    var passwordManager: PasswordManager = .duckduckgo
}

final class UserAuthenticatorMock: UserAuthenticating {
    // swiftlint:disable:next identifier_name
    var _authenticateUser: (DeviceAuthenticator.AuthenticationReason) -> DeviceAuthenticationResult = { _ in return .success }

    func authenticateUser(reason: DeviceAuthenticator.AuthenticationReason, result: @escaping (DeviceAuthenticationResult) -> Void) {
        let authenticationResult = _authenticateUser(reason)
        result(authenticationResult)
    }
}

final class AutofillPreferencesModelTests: XCTestCase {

    func testThatPreferencesArePersisted() throws {
        let persistor = AutofillPreferencesPersistorMock()
        let userAuthenticator = UserAuthenticatorMock()
        let model = AutofillPreferencesModel(persistor: persistor, userAuthenticator: userAuthenticator)

        model.askToSaveUsernamesAndPasswords.toggle()
        XCTAssertEqual(persistor.askToSaveUsernamesAndPasswords, model.askToSaveUsernamesAndPasswords)

        model.askToSaveAddresses.toggle()
        XCTAssertEqual(persistor.askToSaveAddresses, model.askToSaveAddresses)

        model.askToSavePaymentMethods.toggle()
        XCTAssertEqual(persistor.askToSavePaymentMethods, model.askToSavePaymentMethods)
    }

    func testWhenUserIsAuthenticatedThenAutoLockCanBeDisabled() throws {
        let persistor = AutofillPreferencesPersistorMock()
        let userAuthenticator = UserAuthenticatorMock()
        let model = AutofillPreferencesModel(persistor: persistor, userAuthenticator: userAuthenticator)

        userAuthenticator._authenticateUser = { _ in return .success}

        model.authorizeAutoLockSettingsChange(isEnabled: false)
        XCTAssertEqual(model.isAutoLockEnabled, false)
        XCTAssertEqual(persistor.isAutoLockEnabled, model.isAutoLockEnabled)
    }

    func testWhenUserIsNotAuthenticatedThenAutoLockCannotBeDisabled() throws {
        let persistor = AutofillPreferencesPersistorMock()
        let userAuthenticator = UserAuthenticatorMock()
        let model = AutofillPreferencesModel(persistor: persistor, userAuthenticator: userAuthenticator)

        userAuthenticator._authenticateUser = { _ in return .failure}

        model.authorizeAutoLockSettingsChange(isEnabled: false)
        XCTAssertEqual(model.isAutoLockEnabled, true)
        XCTAssertEqual(persistor.isAutoLockEnabled, model.isAutoLockEnabled)
    }

    func testWhenUserIsAuthenticatedThenAutoLockThresholdCanBeChanged() throws {
        let persistor = AutofillPreferencesPersistorMock()
        let userAuthenticator = UserAuthenticatorMock()
        let model = AutofillPreferencesModel(persistor: persistor, userAuthenticator: userAuthenticator)

        userAuthenticator._authenticateUser = { _ in return .success}

        model.authorizeAutoLockSettingsChange(threshold: .oneHour)
        XCTAssertEqual(model.isAutoLockEnabled, true)
        XCTAssertEqual(model.autoLockThreshold, .oneHour)
        XCTAssertEqual(persistor.autoLockThreshold, model.autoLockThreshold)
    }

    func testWhenUserIsNotAuthenticatedThenAutoLockThresholdCannotBeChanged() throws {
        let persistor = AutofillPreferencesPersistorMock()
        let userAuthenticator = UserAuthenticatorMock()
        let model = AutofillPreferencesModel(persistor: persistor, userAuthenticator: userAuthenticator)

        userAuthenticator._authenticateUser = { _ in return .failure}

        model.authorizeAutoLockSettingsChange(threshold: .oneHour)
        XCTAssertNotEqual(model.autoLockThreshold, .oneHour)
        XCTAssertEqual(persistor.autoLockThreshold, model.autoLockThreshold)
    }
}
