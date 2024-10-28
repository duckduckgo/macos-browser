//
//  DataBrokerProtectionUserNotificationServiceTests.swift
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
import DataBrokerProtection
import UserNotifications

final class DataBrokerProtectionUserNotificationServiceTests: XCTestCase {

    private var mockAuthenticationManager: MockAuthenticationManager!
    private var mockDBPUserNotificationCenter: MockDBPUserNotificationCenter!
    private var sut: DataBrokerProtectionUserNotificationService!

    override func setUpWithError() throws {
        mockAuthenticationManager = MockAuthenticationManager()
        mockDBPUserNotificationCenter = MockDBPUserNotificationCenter()
        sut = DefaultDataBrokerProtectionUserNotificationService(pixelHandler: MockPixelHandler(),
                                                                 userNotificationCenter: mockDBPUserNotificationCenter,
                                                                 authenticationManager: mockAuthenticationManager)
    }

    func test_sendFirstScanCompletedNotification_WhenUserNotAuthenticated_ShouldSendFirstFreemiumScanNotification() {
        // Given
        mockAuthenticationManager.isUserAuthenticatedValue = false

        // When
        sut.sendFirstScanCompletedNotification()

        // Then
        XCTAssertEqual(mockDBPUserNotificationCenter.addedRequest?.identifier, "dbp.freemium.scan.complete")
    }

    func test_sendFirstScanCompletedNotification_WhenUserAuthenticated_ShouldSendFirstScanCompleteNotification() {
        // Given
        mockAuthenticationManager.isUserAuthenticatedValue = true

        // When
        sut.sendFirstScanCompletedNotification()

        // Then
        XCTAssertEqual(mockDBPUserNotificationCenter.addedRequest?.identifier, "dbp.scan.complete")
    }
}

final private class MockDBPUserNotificationCenter: DBPUserNotificationCenter {

    var addedRequest: UNNotificationRequest?

    var delegate: (any UNUserNotificationCenterDelegate)?

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: (((any Error)?) -> Void)? = nil) {
        addedRequest = request
    }

    func getNotificationSettings(completionHandler: @escaping (UNNotificationSettings) -> Void) {}

    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, (any Error)?) -> Void) {}
}
