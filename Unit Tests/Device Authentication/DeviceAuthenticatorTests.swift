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
    
    private let groupName = "device-authenticator"
    var defaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        
        defaults = UserDefaults(suiteName: groupName)!
        defaults.removePersistentDomain(forName: groupName)
    }

    func testWhenAutoLockIsEnabled_AndDeviceIsLocked_ThenRequiresAuthenticationIsTrue() {
        let authenticationService = MockDeviceAuthenticatorService.alwaysAuthenticate
        var preferences = LoginsPreferences(userDefaults: defaults)
        preferences.shouldAutoLockLogins = true
        
        let deviceAuthenticator = DeviceAuthenticator(authenticationService: authenticationService, loginsPreferences: preferences)
        
        XCTAssertTrue(deviceAuthenticator.requiresAuthentication)
    }
    
    func testWhenAutoLockIsEnabled_AndDeviceIsLocked_AndAuthenticationIsGranted_ThenRequiresAuthenticationIsFalse() async {
        let authenticationService = MockDeviceAuthenticatorService.alwaysAuthenticate
        var preferences = LoginsPreferences(userDefaults: defaults)
        preferences.shouldAutoLockLogins = true
        
        let deviceAuthenticator = DeviceAuthenticator(authenticationService: authenticationService, loginsPreferences: preferences)
        let authenticated = await deviceAuthenticator.authenticateUser()
        
        XCTAssertTrue(authenticated)
        XCTAssertFalse(deviceAuthenticator.requiresAuthentication)
    }
    
    func testWhenAutoLockIsEnabled_AndDeviceIsLocked_AndAuthenticationIsDenied_ThenRequiresAuthenticationIsFalse() async {
        let authenticationService = MockDeviceAuthenticatorService.neverAuthenticate
        var preferences = LoginsPreferences(userDefaults: defaults)
        preferences.shouldAutoLockLogins = true
        
        let deviceAuthenticator = DeviceAuthenticator(authenticationService: authenticationService, loginsPreferences: preferences)
        let authenticated = await deviceAuthenticator.authenticateUser()
        
        XCTAssertFalse(authenticated)
        XCTAssertTrue(deviceAuthenticator.requiresAuthentication)
    }
    
    func testWhenAutoLockIsEnabled_AndDeviceIsUnlocked_AndAuthenticationIsRequested_ThenAuthenticationSucceedsWithoutPrompting() async {
        let authenticationService = MockDeviceAuthenticatorService.alwaysAuthenticate
        var preferences = LoginsPreferences(userDefaults: defaults)
        preferences.shouldAutoLockLogins = true
        
        let deviceAuthenticator = DeviceAuthenticator(authenticationService: authenticationService, loginsPreferences: preferences)
        let authenticated = await deviceAuthenticator.authenticateUser()
        
        XCTAssertTrue(authenticated)
        XCTAssertFalse(deviceAuthenticator.requiresAuthentication)
        XCTAssertEqual(authenticationService.authenticationAttempts, 1)
        
        let authenticatedAgain = await deviceAuthenticator.authenticateUser()
        
        XCTAssertTrue(authenticatedAgain)
        XCTAssertFalse(deviceAuthenticator.requiresAuthentication)
        XCTAssertEqual(authenticationService.authenticationAttempts, 1)
    }
    
    func testWhenAutoLockIsDisabled_ThenRequiresAuthenticationIsFalse() {
        let authenticationService = MockDeviceAuthenticatorService.alwaysAuthenticate
        var preferences = LoginsPreferences(userDefaults: defaults)
        preferences.shouldAutoLockLogins = false
        
        let deviceAuthenticator = DeviceAuthenticator(authenticationService: authenticationService, loginsPreferences: preferences)
        
        XCTAssertFalse(deviceAuthenticator.requiresAuthentication)
    }
    
    func testWhenAutoLockIsEnabled_AndDeviceIsUnlocked_AndDeviceIsIdleForLongerThanTheThreshold_ThenDeviceBecomesLocked() async {
        let idleStateProvider = MockIdleStateProvider(idleDuration: 60 * 20) // 20 minute idle duration, to be safe
        let authenticationService = MockDeviceAuthenticatorService.alwaysAuthenticate
        var preferences = LoginsPreferences(userDefaults: defaults)
        
        preferences.shouldAutoLockLogins = true
        preferences.autoLockThreshold = .fifteenMinutes
        
        let deviceAuthenticator = DeviceAuthenticator(idleStateProvider: idleStateProvider,
                                                      authenticationService: authenticationService,
                                                      loginsPreferences: preferences)

        _ = await deviceAuthenticator.authenticateUser()
        
        XCTAssertFalse(deviceAuthenticator.requiresAuthentication)
        
        let expectation = expectation(description: "Wait for the authenticator to become locked")
        let result = XCTWaiter.wait(for: [expectation], timeout: 1.5)

        if result == .timedOut {
            XCTAssertTrue(deviceAuthenticator.requiresAuthentication)
        } else {
            XCTFail("Didn't wait for the expectation to time out")
        }
    }
    
    func testWhenAutoLockIsEnabled_AndDeviceIsUnlocked_AndDeviceIsIdleForLessThanTheThreshold_ThenDeviceDoesNotLock() async {
        let idleStateProvider = MockIdleStateProvider(idleDuration: 60)
        let authenticationService = MockDeviceAuthenticatorService.alwaysAuthenticate
        var preferences = LoginsPreferences(userDefaults: defaults)
        
        preferences.shouldAutoLockLogins = true
        preferences.autoLockThreshold = .fifteenMinutes
        
        let deviceAuthenticator = DeviceAuthenticator(idleStateProvider: idleStateProvider,
                                                      authenticationService: authenticationService,
                                                      loginsPreferences: preferences)

        _ = await deviceAuthenticator.authenticateUser()
        
        XCTAssertFalse(deviceAuthenticator.requiresAuthentication)
        
        let expectation = expectation(description: "Wait for the authenticator to become locked")
        let result = XCTWaiter.wait(for: [expectation], timeout: 1.5)

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

    func authenticateDevice(reason: String, result: @escaping DeviceAuthenticationResult) {
        authenticationAttempts += 1
        result(shouldBeAuthenticated)
    }
    
}

private struct MockIdleStateProvider: DeviceIdleStateProvider {
    
    let idleDuration: TimeInterval
    
    func secondsSinceLastEvent() -> TimeInterval {
        return idleDuration
    }
    
}
