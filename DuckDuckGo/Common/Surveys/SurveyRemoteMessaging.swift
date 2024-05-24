//
//  SurveyRemoteMessaging.swift
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

import Foundation
import Networking
import PixelKit
import Subscription

protocol SurveyRemoteMessaging {

    func fetchRemoteMessages() async
    func presentableRemoteMessages() -> [SurveyRemoteMessage]
    func dismiss(message: SurveyRemoteMessage)

}

protocol SurveyRemoteMessageSubscriptionFetching {

    func getSubscription(accessToken: String) async -> Result<Subscription, SubscriptionService.SubscriptionServiceError>

}

final class DefaultSurveyRemoteMessaging: SurveyRemoteMessaging {

    enum Constants {
        static let lastRefreshDateKey = "surveys.remote-messaging.last-refresh-date"
    }

    private let messageRequest: HomePageRemoteMessagingRequest
    private let messageStorage: SurveyRemoteMessagingStorage
    private let accountManager: AccountManaging
    private let subscriptionFetcher: SurveyRemoteMessageSubscriptionFetching
    private let waitlistActivationDateStore: WaitlistActivationDateStore
    private let minimumRefreshInterval: TimeInterval
    private let userDefaults: UserDefaults

    convenience init(subscriptionManager: SubscriptionManaging) {
        #if DEBUG || REVIEW
        self.init(
            accountManager: subscriptionManager.accountManager,
            subscriptionFetcher: subscriptionManager.subscriptionService,
            minimumRefreshInterval: .seconds(30)
        )
        #else
        self.init(
            accountManager: subscriptionManager.accountManager,
            subscriptionFetcher: subscriptionManager.subscriptionService,
            minimumRefreshInterval: .hours(1)
        )
        #endif
    }

    init(
        messageRequest: HomePageRemoteMessagingRequest = DefaultHomePageRemoteMessagingRequest.surveysRequest(),
        messageStorage: SurveyRemoteMessagingStorage = DefaultSurveyRemoteMessagingStorage.surveys(),
        accountManager: AccountManaging,
        subscriptionFetcher: SurveyRemoteMessageSubscriptionFetching,
        waitlistActivationDateStore: WaitlistActivationDateStore = DefaultWaitlistActivationDateStore(source: .netP),
        networkProtectionVisibility: NetworkProtectionFeatureVisibility = DefaultNetworkProtectionVisibility(subscriptionManager: Application.appDelegate.subscriptionManager),
        minimumRefreshInterval: TimeInterval,
        userDefaults: UserDefaults = .standard
    ) {
        self.messageRequest = messageRequest
        self.messageStorage = messageStorage
        self.accountManager = accountManager
        self.subscriptionFetcher = subscriptionFetcher
        self.waitlistActivationDateStore = waitlistActivationDateStore
        self.minimumRefreshInterval = minimumRefreshInterval
        self.userDefaults = userDefaults
    }

    func fetchRemoteMessages() async {
        if let lastRefreshDate = lastRefreshDate(), lastRefreshDate.addingTimeInterval(minimumRefreshInterval) > Date() {
            return
        }

        let messageFetchResult = await self.messageRequest.fetchHomePageRemoteMessages()

        switch messageFetchResult {
        case .success(let messages):
            do {
                let processedMessages = await self.process(messages: messages)
                try self.messageStorage.store(messages: processedMessages)
                self.updateLastRefreshDate()
            } catch {
                PixelKit.fire(DebugEvent(GeneralPixel.networkProtectionRemoteMessageStorageFailed, error: error))
            }
        case .failure(let error):
            // Ignore 403 errors, those happen when a file can't be found on S3
            if case APIRequest.Error.invalidStatusCode(403) = error {
                self.updateLastRefreshDate()
                return
            }

            PixelKit.fire(DebugEvent(GeneralPixel.networkProtectionRemoteMessageFetchingFailed, error: error))
        }
    }

    /// Processes the messages received from S3 and returns those which the user is eligible for. This is done by checking each of the attributes against the user's local state.
    /// Because the result of the message fetch is cached, it means that they won't be immediately updated if the user suddenly qualifies, but the refresh interval for remote messages is only 1 hour so it
    /// won't take long for the message to appear to the user.
    private func process(messages: [SurveyRemoteMessage]) async -> [SurveyRemoteMessage] {
        guard let token = accountManager.accessToken else {
            return []
        }

        guard case let .success(subscription) = await subscriptionFetcher.getSubscription(accessToken: token) else {
            return []
        }

        return messages.filter { message in

            // Check subscription status:
            if let messageSubscriptionStatus = message.attributes.subscriptionStatus {
                if let subscriptionStatus = Subscription.Status(rawValue: messageSubscriptionStatus) {
                    return subscription.status == subscriptionStatus
                } else {
                    // If we received a subscription status but can't map it to a valid type, don't show the message.
                    return false
                }
            }

            // Check subscription start date:
            if let messageDaysSinceSubscriptionStarted = message.attributes.minimumDaysSinceSubscriptionStarted {
                guard let daysSinceSubscriptionStartDate = Calendar.current.dateComponents(
                    [.day], from: subscription.startedAt, to: Date()
                ).day else {
                    return false
                }

                return daysSinceSubscriptionStartDate >= messageDaysSinceSubscriptionStarted
            }

            // Check subscription end/expiration date:
            if let messageDaysUntilSubscriptionExpiration = message.attributes.maximumDaysUntilSubscriptionExpirationOrRenewal {
                guard let daysUntilSubscriptionExpiration = Calendar.current.dateComponents(
                    [.day], from: subscription.expiresOrRenewsAt, to: Date()
                ).day else {
                    return false
                }

                return daysUntilSubscriptionExpiration <= messageDaysUntilSubscriptionExpiration
            }

            // Check VPN usage:
            if let requiredDaysSinceActivation = message.attributes.daysSinceVPNEnabled {
                if let daysSinceActivation = waitlistActivationDateStore.daysSinceActivation(), requiredDaysSinceActivation <= daysSinceActivation {
                    return true
                } else {
                    return false
                }
            }

            // Don't show messages unless at least one attribute matches:
            return false

        }
    }

    func presentableRemoteMessages() -> [SurveyRemoteMessage] {
        let dismissedMessageIDs = messageStorage.dismissedMessageIDs()
        let possibleMessages: [SurveyRemoteMessage] = messageStorage.storedMessages()

        let filteredMessages = possibleMessages.filter { message in
            if dismissedMessageIDs.contains(message.id) {
                return false
            }

            return true

        }

        return filteredMessages
    }

    func dismiss(message: SurveyRemoteMessage) {
        messageStorage.dismissRemoteMessage(with: message.id)
    }

    func resetLastRefreshTimestamp() {
        userDefaults.removeObject(forKey: Constants.lastRefreshDateKey)
    }

    // MARK: - Private

    private func lastRefreshDate() -> Date? {
        guard let object = userDefaults.object(forKey: Constants.lastRefreshDateKey) else {
            return nil
        }

        guard let date = object as? Date else {
            assertionFailure("Got rate limited date, but couldn't convert it to Date")
            userDefaults.removeObject(forKey: Constants.lastRefreshDateKey)
            return nil
        }

        return date
    }

    private func updateLastRefreshDate() {
        userDefaults.setValue(Date(), forKey: Constants.lastRefreshDateKey)
    }

}

extension SubscriptionService: SurveyRemoteMessageSubscriptionFetching {

    func getSubscription(accessToken: String) async -> Result<Subscription, SubscriptionServiceError> {
        return await self.getSubscription(accessToken: accessToken, cachePolicy: .returnCacheDataElseLoad)
    }

}
