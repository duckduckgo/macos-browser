//
//  SurveyRemoteMessagingTests.swift
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

import XCTest
import SubscriptionTestingUtilities
@testable import Subscription
@testable import DuckDuckGo_Privacy_Browser

@available(macOS 12.0, *)
final class SurveyRemoteMessagingTests: XCTestCase {

    private var defaults: UserDefaults!
    private let testGroupName = "remote-messaging"

    private var accountManager: AccountManaging!
    private var subscriptionFetcher: SurveyRemoteMessageSubscriptionFetching!

    override func setUp() {
        defaults = UserDefaults(suiteName: testGroupName)!
        defaults.removePersistentDomain(forName: testGroupName)

        accountManager = AccountManagerMock(isUserAuthenticated: true, accessToken: "mock-token")
        subscriptionFetcher = MockSubscriptionFetcher()
    }

    func testWhenFetchingRemoteMessages_AndTheUserDidNotSignUpViaWaitlist_ThenMessagesAreFetched() async {
        let request = MockNetworkProtectionRemoteMessagingRequest()
        request.result = .success([])
        let storage = MockSurveyRemoteMessagingStorage()
        let activationDateStorage = MockWaitlistActivationDateStore()

        let messaging = DefaultSurveyRemoteMessaging(
            messageRequest: request,
            messageStorage: storage,
            accountManager: accountManager,
            subscriptionFetcher: subscriptionFetcher,
            vpnActivationDateStore: activationDateStorage,
            pirActivationDateStore: activationDateStorage,
            minimumRefreshInterval: 0,
            userDefaults: defaults
        )

        await messaging.fetchRemoteMessages()

        XCTAssertTrue(request.didFetchMessages)
    }

    func testWhenFetchingRemoteMessages_AndTheUserDidSignUpViaWaitlist_ButUserHasNotActivatedNetP_ThenMessagesAreFetched() async {
        let request = MockNetworkProtectionRemoteMessagingRequest()
        let storage = MockSurveyRemoteMessagingStorage()
        let activationDateStorage = MockWaitlistActivationDateStore()

        request.result = .success([])

        let messaging = DefaultSurveyRemoteMessaging(
            messageRequest: request,
            messageStorage: storage,
            accountManager: accountManager,
            subscriptionFetcher: subscriptionFetcher,
            vpnActivationDateStore: activationDateStorage,
            pirActivationDateStore: activationDateStorage,
            minimumRefreshInterval: 0,
            userDefaults: defaults
        )

        XCTAssertNil(activationDateStorage.daysSinceActivation())

        await messaging.fetchRemoteMessages()

        XCTAssertTrue(request.didFetchMessages)
    }

    func testWhenFetchingRemoteMessages_AndWaitlistUserHasActivatedNetP_ThenMessagesAreFetched_AndMessagesAreStored() async {
        let request = MockNetworkProtectionRemoteMessagingRequest()
        let storage = MockSurveyRemoteMessagingStorage()
        let activationDateStorage = MockWaitlistActivationDateStore()

        let messages = [mockMessage(id: "123")]

        request.result = .success(messages)
        activationDateStorage._daysSinceActivation = 10

        let messaging = DefaultSurveyRemoteMessaging(
            messageRequest: request,
            messageStorage: storage,
            accountManager: accountManager,
            subscriptionFetcher: subscriptionFetcher,
            vpnActivationDateStore: activationDateStorage,
            pirActivationDateStore: activationDateStorage,
            minimumRefreshInterval: 0,
            userDefaults: defaults
        )

        XCTAssertEqual(storage.storedMessages(), [])
        XCTAssertNotNil(activationDateStorage.daysSinceActivation())

        await messaging.fetchRemoteMessages()

        XCTAssertTrue(request.didFetchMessages)
        XCTAssertEqual(storage.storedMessages(), messages)
    }

    func testWhenFetchingRemoteMessages_AndWaitlistUserHasActivatedNetP_ButRateLimitedOperationCannotRunAgain_ThenMessagesAreNotFetched() async {
        let request = MockNetworkProtectionRemoteMessagingRequest()
        let storage = MockSurveyRemoteMessagingStorage()
        let activationDateStorage = MockWaitlistActivationDateStore()

        activationDateStorage._daysSinceActivation = 10

        defaults.setValue(Date(), forKey: DefaultSurveyRemoteMessaging.Constants.lastRefreshDateKey)

        let messaging = DefaultSurveyRemoteMessaging(
            messageRequest: request,
            messageStorage: storage,
            accountManager: accountManager,
            subscriptionFetcher: subscriptionFetcher,
            vpnActivationDateStore: activationDateStorage,
            pirActivationDateStore: activationDateStorage,
            minimumRefreshInterval: .days(7), // Use a large number to hit the refresh check
            userDefaults: defaults
        )

        XCTAssertNotNil(activationDateStorage.daysSinceActivation())

        await messaging.fetchRemoteMessages()

        XCTAssertFalse(request.didFetchMessages)
        XCTAssertEqual(storage.storedMessages(), [])
    }

    func testWhenStoredMessagesExist_AndSomeMessagesHaveBeenDismissed_ThenPresentableMessagesDoNotIncludeDismissedMessages() {
        let request = MockNetworkProtectionRemoteMessagingRequest()
        let storage = MockSurveyRemoteMessagingStorage()
        let activationDateStorage = MockWaitlistActivationDateStore()

        let dismissedMessage = mockMessage(id: "123")
        let activeMessage = mockMessage(id: "456")
        try? storage.store(messages: [dismissedMessage, activeMessage])
        activationDateStorage._daysSinceActivation = 10

        let messaging = DefaultSurveyRemoteMessaging(
            messageRequest: request,
            messageStorage: storage,
            accountManager: accountManager,
            subscriptionFetcher: subscriptionFetcher,
            vpnActivationDateStore: activationDateStorage,
            pirActivationDateStore: activationDateStorage,
            minimumRefreshInterval: 0,
            userDefaults: defaults
        )

        let presentableMessagesBefore = messaging.presentableRemoteMessages()
        XCTAssertEqual(presentableMessagesBefore, [dismissedMessage, activeMessage])
        messaging.dismiss(message: dismissedMessage)
        let presentableMessagesAfter = messaging.presentableRemoteMessages()
        XCTAssertEqual(presentableMessagesAfter, [activeMessage])
    }

    func testWhenStoredMessagesExist_AndSomeMessagesRequireNetPUsage_ThenPresentableMessagesDoNotIncludeInvalidMessages() {
        let request = MockNetworkProtectionRemoteMessagingRequest()
        let storage = MockSurveyRemoteMessagingStorage()
        let activationDateStorage = MockWaitlistActivationDateStore()

        let message = mockMessage(id: "123")
        try? storage.store(messages: [message])

        let messaging = DefaultSurveyRemoteMessaging(
            messageRequest: request,
            messageStorage: storage,
            accountManager: accountManager,
            subscriptionFetcher: subscriptionFetcher,
            vpnActivationDateStore: activationDateStorage,
            pirActivationDateStore: activationDateStorage,
            minimumRefreshInterval: 0,
            userDefaults: defaults
        )

        let presentableMessages = messaging.presentableRemoteMessages()
        XCTAssertEqual(presentableMessages, [message])
    }

    private func mockMessage(id: String,
                             subscriptionStatus: String = Subscription.Status.autoRenewable.rawValue,
                             minimumDaysSinceSubscriptionStarted: Int = 0,
                             maximumDaysUntilSubscriptionExpirationOrRenewal: Int = 0,
                             daysSinceVPNEnabled: Int = 0,
                             daysSincePIREnabled: Int = 0) -> SurveyRemoteMessage {
        let remoteMessageJSON = """
        {
            "id": "\(id)",
            "cardTitle": "Title",
            "cardDescription": "Description 1",
            "attributes": {
                    "subscriptionStatus": "\(subscriptionStatus)",
                    "minimumDaysSinceSubscriptionStarted": \(minimumDaysSinceSubscriptionStarted),
                    "maximumDaysUntilSubscriptionExpirationOrRenewal": \(maximumDaysUntilSubscriptionExpirationOrRenewal),
                    "daysSinceVPNEnabled": \(daysSinceVPNEnabled),
                    "daysSincePIREnabled": \(daysSincePIREnabled)
            },
            "action": {
                "actionTitle": "Action 1"
            }
        }
        """

        let decoder = JSONDecoder()
        return try! decoder.decode(SurveyRemoteMessage.self, from: remoteMessageJSON.data(using: .utf8)!)
    }

}

// MARK: - Mocks

private final class MockNetworkProtectionRemoteMessagingRequest: HomePageRemoteMessagingRequest {

    var result: Result<[SurveyRemoteMessage], Error>!
    var didFetchMessages: Bool = false

    func fetchHomePageRemoteMessages() async -> Result<[SurveyRemoteMessage], any Error> {
        didFetchMessages = true
        return result
    }

}

private final class MockSurveyRemoteMessagingStorage: SurveyRemoteMessagingStorage {

    var _storedMessages: [SurveyRemoteMessage] = []
    var _storedDismissedMessageIDs: [String] = []

    func store(messages: [SurveyRemoteMessage]) throws {
        self._storedMessages = messages
    }

    func storedMessages() -> [SurveyRemoteMessage] {
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

final class MockSubscriptionFetcher: SurveyRemoteMessageSubscriptionFetching {

    var subscription: Subscription = Subscription(
        productId: "product",
        name: "name",
        billingPeriod: .monthly,
        startedAt: Date(),
        expiresOrRenewsAt: Date(),
        platform: .apple,
        status: .autoRenewable)

    func getSubscription(accessToken: String) async -> Result<Subscription, SubscriptionServiceError> {
        return .success(subscription)
    }

}
