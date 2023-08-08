//
//  DeviceAuthenticatorTests.swift
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

import Foundation
import XCTest
@testable import DuckDuckGo_Privacy_Browser

class DeviceAuthenticatorTests: XCTestCase {

    private func waitResult(for expectations: [XCTestExpectation], timeout: TimeInterval) -> XCTWaiter.Result {
        XCTWaiter.wait(for: expectations, timeout: 0.2)
    }

    // MARK: - Tests

    func testWhenAutoLockIsEnabled_AndDeviceIsLocked_ThenRequiresAuthenticationIsTrue() {
        let mockStatisticsStore = MockStatisticsStore()
        let authenticationService = MockDeviceAuthenticatorService.alwaysAuthenticate
        let preferences = AutofillPreferences(statisticsStore: mockStatisticsStore)
        preferences.isAutoLockEnabled = true

        let deviceAuthenticator = DeviceAuthenticator(authenticationService: authenticationService, autofillPreferences: preferences)

        XCTAssertTrue(deviceAuthenticator.requiresAuthentication)
    }

    func testWhenAutoLockIsEnabled_AndDeviceIsLocked_AndAuthenticationIsGranted_ThenRequiresAuthenticationIsFalse() async {
        let mockStatisticsStore = MockStatisticsStore()
        let authenticationService = MockDeviceAuthenticatorService.alwaysAuthenticate
        let preferences = AutofillPreferences(statisticsStore: mockStatisticsStore)
        preferences.isAutoLockEnabled = true

        let deviceAuthenticator = DeviceAuthenticator(authenticationService: authenticationService, autofillPreferences: preferences)
        let result = await deviceAuthenticator.authenticateUser(reason: .unlockLogins)

        XCTAssertTrue(result.authenticated)
        XCTAssertFalse(deviceAuthenticator.requiresAuthentication)
    }

    func testWhenAutoLockIsEnabled_AndDeviceIsLocked_AndAuthenticationIsDenied_ThenRequiresAuthenticationIsFalse() async {
        let mockStatisticsStore = MockStatisticsStore()
        let authenticationService = MockDeviceAuthenticatorService.neverAuthenticate
        let preferences = AutofillPreferences(statisticsStore: mockStatisticsStore)
        preferences.isAutoLockEnabled = true

        let deviceAuthenticator = DeviceAuthenticator(authenticationService: authenticationService, autofillPreferences: preferences)
        let result = await deviceAuthenticator.authenticateUser(reason: .unlockLogins)

        XCTAssertFalse(result.authenticated)
        XCTAssertTrue(deviceAuthenticator.requiresAuthentication)
    }

    func testWhenAutoLockIsEnabled_AndDeviceIsUnlocked_AndAuthenticationIsRequested_ThenAuthenticationSucceedsWithoutPrompting() async {
        let mockStatisticsStore = MockStatisticsStore()
        let authenticationService = MockDeviceAuthenticatorService.alwaysAuthenticate
        let preferences = AutofillPreferences(statisticsStore: mockStatisticsStore)
        preferences.isAutoLockEnabled = true

        let deviceAuthenticator = DeviceAuthenticator(authenticationService: authenticationService, autofillPreferences: preferences)
        let initialResult = await deviceAuthenticator.authenticateUser(reason: .unlockLogins)

        XCTAssertTrue(initialResult.authenticated)
        XCTAssertFalse(deviceAuthenticator.requiresAuthentication)
        XCTAssertEqual(authenticationService.authenticationAttempts, 1)

        let successfulResult = await deviceAuthenticator.authenticateUser(reason: .unlockLogins)

        XCTAssertTrue(successfulResult.authenticated)
        XCTAssertFalse(deviceAuthenticator.requiresAuthentication)
        XCTAssertEqual(authenticationService.authenticationAttempts, 1)
    }

    func testWhenAutoLockIsDisabled_ThenRequiresAuthenticationIsFalse() {
        let mockStatisticsStore = MockStatisticsStore()
        let authenticationService = MockDeviceAuthenticatorService.alwaysAuthenticate
        let preferences = AutofillPreferences(statisticsStore: mockStatisticsStore)
        preferences.isAutoLockEnabled = false

        let deviceAuthenticator = DeviceAuthenticator(authenticationService: authenticationService, autofillPreferences: preferences)

        XCTAssertFalse(deviceAuthenticator.requiresAuthentication)
    }

    func testWhenAutoLockIsEnabled_AndDeviceIsUnlocked_AndDeviceIsIdleForLongerThanTheThreshold_ThenDeviceBecomesLocked() async {
        let mockStatisticsStore = MockStatisticsStore()
        let idleStateProvider = MockIdleStateProvider(idleDuration: 60 * 20) // 20 minute idle duration, to be safe
        let authenticationService = MockDeviceAuthenticatorService.alwaysAuthenticate
        let preferences = AutofillPreferences(statisticsStore: mockStatisticsStore)

        preferences.isAutoLockEnabled = true
        preferences.autoLockThreshold = .fifteenMinutes

        DeviceAuthenticator.Constants.intervalBetweenIdleChecks = 0.1
        let deviceAuthenticator = DeviceAuthenticator(idleStateProvider: idleStateProvider,
                                                      authenticationService: authenticationService,
                                                      autofillPreferences: preferences)

        _ = await deviceAuthenticator.authenticateUser(reason: .unlockLogins)

        XCTAssertFalse(deviceAuthenticator.requiresAuthentication)

        let expectation = expectation(description: "Wait for the authenticator to become locked")
        let result = waitResult(for: [expectation], timeout: 0.2)

        if result == .timedOut {
            XCTAssertTrue(deviceAuthenticator.requiresAuthentication)
        } else {
            XCTFail("Didn't wait for the expectation to time out")
        }
    }

    func testWhenAutoLockIsEnabled_AndDeviceIsUnlocked_AndDeviceIsIdleForLessThanTheThreshold_ThenDeviceDoesNotLock() async {
        let mockStatisticsStore = MockStatisticsStore()
        let idleStateProvider = MockIdleStateProvider(idleDuration: 60)
        let authenticationService = MockDeviceAuthenticatorService.alwaysAuthenticate
        let preferences = AutofillPreferences(statisticsStore: mockStatisticsStore)

        preferences.isAutoLockEnabled = true
        preferences.autoLockThreshold = .fifteenMinutes

        let deviceAuthenticator = DeviceAuthenticator(idleStateProvider: idleStateProvider,
                                                      authenticationService: authenticationService,
                                                      autofillPreferences: preferences)

        _ = await deviceAuthenticator.authenticateUser(reason: .unlockLogins)

        XCTAssertFalse(deviceAuthenticator.requiresAuthentication)

        let expectation = expectation(description: "Wait for the authenticator to become locked")
        let result = await XCTWaiter.fulfillment(of: [expectation], timeout: 0.2)

        if result == .timedOut {
            XCTAssertFalse(deviceAuthenticator.requiresAuthentication)
        } else {
            XCTFail("Didn't wait for the expectation to time out")
        }
    }

}

// MARK: - Dependencies

private final class MockDeviceAuthenticatorService: DeviceAuthenticationService {

    static var alwaysAuthenticate: MockDeviceAuthenticatorService {
        MockDeviceAuthenticatorService(shouldBeAuthenticated: true)
    }

    static var neverAuthenticate: MockDeviceAuthenticatorService {
        MockDeviceAuthenticatorService(shouldBeAuthenticated: false)
    }

    var authenticationAttempts = 0

    private let shouldBeAuthenticated: Bool

    init(shouldBeAuthenticated: Bool) {
        self.shouldBeAuthenticated = shouldBeAuthenticated
    }

    func authenticateDevice(reason: String, result: @escaping DeviceAuthenticationResultHandler) {
        authenticationAttempts += 1
        result(shouldBeAuthenticated ? .success : .failure)
    }

}

private struct MockIdleStateProvider: DeviceIdleStateProvider {

    let idleDuration: TimeInterval

    func secondsSinceLastEvent() -> TimeInterval {
        return idleDuration
    }

}
