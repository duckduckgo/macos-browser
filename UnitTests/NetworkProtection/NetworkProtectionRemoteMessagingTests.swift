//
//  NetworkProtectionRemoteMessagingTests.swift
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

#if NETWORK_PROTECTION

import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class NetworkProtectionRemoteMessagingTests: XCTestCase {

    private var defaults: UserDefaults!
    private let testGroupName = "remote-messaging"

    override func setUp() {
        defaults = UserDefaults(suiteName: testGroupName)!
        defaults.removePersistentDomain(forName: testGroupName)
    }

    func testWhenFetchingRemoteMessages_AndTheUserDidNotSignUpViaWaitlist_ThenMessagesAreNotFetched() {
        let request = MockNetworkProtectionRemoteMessagingRequest()
        let storage = MockNetworkProtectionRemoteMessagingStorage()
        let waitlistStorage = MockWaitlistStorage()
        let activationDateStorage = MockWaitlistActivationDateStore()

        let messaging = DefaultNetworkProtectionRemoteMessaging(
            messageRequest: request,
            messageStorage: storage,
            waitlistStorage: waitlistStorage,
            waitlistActivationDateStore: activationDateStorage,
            minimumRefreshInterval: 0,
            userDefaults: defaults
        )

        XCTAssertTrue(!waitlistStorage.isWaitlistUser)

        let expectation = expectation(description: "Remote Message Fetch")

        messaging.fetchRemoteMessages {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        XCTAssertFalse(request.didFetchMessages)
    }

    func testWhenFetchingRemoteMessages_AndTheUserDidSignUpViaWaitlist_ButUserHasNotActivatedNetP_ThenMessagesAreNotFetched() {
        let request = MockNetworkProtectionRemoteMessagingRequest()
        let storage = MockNetworkProtectionRemoteMessagingStorage()
        let waitlistStorage = MockWaitlistStorage()
        let activationDateStorage = MockWaitlistActivationDateStore()

        waitlistStorage.store(waitlistToken: "token")
        waitlistStorage.store(waitlistTimestamp: 123)
        waitlistStorage.store(inviteCode: "ABCD1234")

        let messaging = DefaultNetworkProtectionRemoteMessaging(
            messageRequest: request,
            messageStorage: storage,
            waitlistStorage: waitlistStorage,
            waitlistActivationDateStore: activationDateStorage,
            minimumRefreshInterval: 0,
            userDefaults: defaults
        )

        XCTAssertTrue(waitlistStorage.isWaitlistUser)
        XCTAssertNil(activationDateStorage.daysSinceActivation())

        let expectation = expectation(description: "Remote Message Fetch")

        messaging.fetchRemoteMessages {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        XCTAssertFalse(request.didFetchMessages)
    }

    func testWhenFetchingRemoteMessages_AndWaitlistUserHasActivatedNetP_ThenMessagesAreFetched_AndMessagesAreStored() {
        let request = MockNetworkProtectionRemoteMessagingRequest()
        let storage = MockNetworkProtectionRemoteMessagingStorage()
        let waitlistStorage = MockWaitlistStorage()
        let activationDateStorage = MockWaitlistActivationDateStore()

        let messages = [mockMessage(id: "123")]

        request.result = .success(messages)
        waitlistStorage.store(waitlistToken: "token")
        waitlistStorage.store(waitlistTimestamp: 123)
        waitlistStorage.store(inviteCode: "ABCD1234")
        activationDateStorage._daysSinceActivation = 10

        let messaging = DefaultNetworkProtectionRemoteMessaging(
            messageRequest: request,
            messageStorage: storage,
            waitlistStorage: waitlistStorage,
            waitlistActivationDateStore: activationDateStorage,
            minimumRefreshInterval: 0,
            userDefaults: defaults
        )

        XCTAssertTrue(waitlistStorage.isWaitlistUser)
        XCTAssertEqual(storage.storedMessages(), [])
        XCTAssertNotNil(activationDateStorage.daysSinceActivation())

        let expectation = expectation(description: "Remote Message Fetch")

        messaging.fetchRemoteMessages {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(request.didFetchMessages)
        XCTAssertEqual(storage.storedMessages(), messages)
    }

    func testWhenFetchingRemoteMessages_AndWaitlistUserHasActivatedNetP_ButRateLimitedOperationCannotRunAgain_ThenMessagesAreNotFetched() {
        let request = MockNetworkProtectionRemoteMessagingRequest()
        let storage = MockNetworkProtectionRemoteMessagingStorage()
        let waitlistStorage = MockWaitlistStorage()
        let activationDateStorage = MockWaitlistActivationDateStore()

        waitlistStorage.store(waitlistToken: "token")
        waitlistStorage.store(waitlistTimestamp: 123)
        waitlistStorage.store(inviteCode: "ABCD1234")
        activationDateStorage._daysSinceActivation = 10

        defaults.setValue(Date(), forKey: DefaultNetworkProtectionRemoteMessaging.Constants.lastRefreshDateKey)

        let messaging = DefaultNetworkProtectionRemoteMessaging(
            messageRequest: request,
            messageStorage: storage,
            waitlistStorage: waitlistStorage,
            waitlistActivationDateStore: activationDateStorage,
            minimumRefreshInterval: .days(7), // Use a large number to hit the refresh check
            userDefaults: defaults
        )

        XCTAssertTrue(waitlistStorage.isWaitlistUser)
        XCTAssertNotNil(activationDateStorage.daysSinceActivation())

        let expectation = expectation(description: "Remote Message Fetch")

        messaging.fetchRemoteMessages {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        XCTAssertFalse(request.didFetchMessages)
        XCTAssertEqual(storage.storedMessages(), [])
    }

    func testWhenStoredMessagesExist_AndSomeMessagesHaveBeenDismissed_ThenPresentableMessagesDoNotIncludeDismissedMessages() {
        let request = MockNetworkProtectionRemoteMessagingRequest()
        let storage = MockNetworkProtectionRemoteMessagingStorage()
        let waitlistStorage = MockWaitlistStorage()
        let activationDateStorage = MockWaitlistActivationDateStore()

        let dismissedMessage = mockMessage(id: "123")
        let activeMessage = mockMessage(id: "456")
        try? storage.store(messages: [dismissedMessage, activeMessage])
        activationDateStorage._daysSinceActivation = 10

        let messaging = DefaultNetworkProtectionRemoteMessaging(
            messageRequest: request,
            messageStorage: storage,
            waitlistStorage: waitlistStorage,
            waitlistActivationDateStore: activationDateStorage,
            minimumRefreshInterval: 0,
            userDefaults: defaults
        )

        let presentableMessagesBefore = messaging.presentableRemoteMessages()
        XCTAssertEqual(presentableMessagesBefore, [dismissedMessage, activeMessage])
        messaging.dismiss(message: dismissedMessage)
        let presentableMessagesAfter = messaging.presentableRemoteMessages()
        XCTAssertEqual(presentableMessagesAfter, [activeMessage])
    }

    func testWhenStoredMessagesExist_AndSomeMessagesRequireDaysActive_ThenPresentableMessagesDoNotIncludeInvalidMessages() {
        let request = MockNetworkProtectionRemoteMessagingRequest()
        let storage = MockNetworkProtectionRemoteMessagingStorage()
        let waitlistStorage = MockWaitlistStorage()
        let activationDateStorage = MockWaitlistActivationDateStore()

        let hiddenMessage = mockMessage(id: "123", daysSinceNetworkProtectionEnabled: 10)
        let activeMessage = mockMessage(id: "456")
        try? storage.store(messages: [hiddenMessage, activeMessage])
        activationDateStorage._daysSinceActivation = 5

        let messaging = DefaultNetworkProtectionRemoteMessaging(
            messageRequest: request,
            messageStorage: storage,
            waitlistStorage: waitlistStorage,
            waitlistActivationDateStore: activationDateStorage,
            minimumRefreshInterval: 0,
            userDefaults: defaults
        )

        let presentableMessagesAfter = messaging.presentableRemoteMessages()
        XCTAssertEqual(presentableMessagesAfter, [activeMessage])
    }

    private func mockMessage(id: String, daysSinceNetworkProtectionEnabled: Int = 0) -> NetworkProtectionRemoteMessage {
        let remoteMessageJSON = """
        {
            "id": "\(id)",
            "daysSinceNetworkProtectionEnabled": \(daysSinceNetworkProtectionEnabled),
            "cardTitle": "Title",
            "cardDescription": "Description",
            "cardAction": "Action",
            "surveyURL": "https://duckduckgo.com/"
        }
        """

        let decoder = JSONDecoder()
        return try! decoder.decode(NetworkProtectionRemoteMessage.self, from: remoteMessageJSON.data(using: .utf8)!)
    }

}

// MARK: - Mocks

private final class MockNetworkProtectionRemoteMessagingRequest: NetworkProtectionRemoteMessagingRequest {

    var result: Result<[NetworkProtectionRemoteMessage], Error>!
    var didFetchMessages: Bool = false

    func fetchNetworkProtectionRemoteMessages(completion: @escaping (Result<[NetworkProtectionRemoteMessage], Error>) -> Void) {
        didFetchMessages = true
        completion(result)
    }

}

private final class MockNetworkProtectionRemoteMessagingStorage: NetworkProtectionRemoteMessagingStorage {

    var _storedMessages: [NetworkProtectionRemoteMessage] = []
    var _storedDismissedMessageIDs: [String] = []

    func store(messages: [NetworkProtectionRemoteMessage]) throws {
        self._storedMessages = messages
    }

    func storedMessages() -> [NetworkProtectionRemoteMessage] {
        _storedMessages
    }

    func dismissRemoteMessage(with id: String) {
        if !_storedDismissedMessageIDs.contains(id) {
            _storedDismissedMessageIDs.append(id)
        }
    }

    func dismissedMessageIDs() -> [String] {
        _storedDismissedMessageIDs
    }

}

final class MockWaitlistActivationDateStore: WaitlistActivationDateStore {

    var _daysSinceActivation: Int?
    var _daysSinceLastActive: Int?

    func daysSinceActivation() -> Int? {
        _daysSinceActivation
    }

    func daysSinceLastActive() -> Int? {
        _daysSinceLastActive
    }

}

#endif
