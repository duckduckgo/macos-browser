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

    func fetchRemoteMessages(completion: (() -> Void)?)
    func presentableRemoteMessages() -> [SurveyRemoteMessage]
    func dismiss(message: SurveyRemoteMessage)

}

final class DefaultSurveyRemoteMessaging: SurveyRemoteMessaging {

    enum Constants {
        static let lastRefreshDateKey = "surveys.remote-messaging.last-refresh-date"
    }

    private let messageRequest: HomePageRemoteMessagingRequest
    private let messageStorage: HomePageRemoteMessagingStorage
    private let subscriptionManager: SubscriptionManaging
    private let waitlistActivationDateStore: WaitlistActivationDateStore
    private let minimumRefreshInterval: TimeInterval
    private let userDefaults: UserDefaults

    convenience init(subscriptionManager: SubscriptionManaging) {
        #if DEBUG || REVIEW
        self.init(subscriptionManager: subscriptionManager, minimumRefreshInterval: .seconds(30))
        #else
        self.init(subscriptionManager: subscriptionManager, minimumRefreshInterval: .hours(1))
        #endif
    }

    init(
        messageRequest: HomePageRemoteMessagingRequest = DefaultHomePageRemoteMessagingRequest.surveysRequest(),
        messageStorage: HomePageRemoteMessagingStorage = DefaultHomePageRemoteMessagingStorage.surveys(),
        subscriptionManager: SubscriptionManaging,
        waitlistActivationDateStore: WaitlistActivationDateStore = DefaultWaitlistActivationDateStore(source: .netP),
        networkProtectionVisibility: NetworkProtectionFeatureVisibility = DefaultNetworkProtectionVisibility(subscriptionManager: Application.appDelegate.subscriptionManager),
        minimumRefreshInterval: TimeInterval,
        userDefaults: UserDefaults = .standard
    ) {
        self.messageRequest = messageRequest
        self.messageStorage = messageStorage
        self.subscriptionManager = subscriptionManager
        self.waitlistActivationDateStore = waitlistActivationDateStore
        self.minimumRefreshInterval = minimumRefreshInterval
        self.userDefaults = userDefaults
    }

    func fetchRemoteMessages(completion fetchCompletion: (() -> Void)? = nil) {
        if let lastRefreshDate = lastRefreshDate(), lastRefreshDate.addingTimeInterval(minimumRefreshInterval) > Date() {
            fetchCompletion?()
            return
        }

        self.messageRequest.fetchHomePageRemoteMessages { [weak self] result in
            defer {
                fetchCompletion?()
            }

            guard let self else { return }

            // Cast the generic parameter to a concrete type:
            let result: Result<[SurveyRemoteMessage], Error> = result

            switch result {
            case .success(let messages):
                do {
                    try self.messageStorage.store(messages: messages)
                    self.updateLastRefreshDate() // Update last refresh date on success, otherwise let the app try again next time
                } catch {
                    PixelKit.fire(DebugEvent(GeneralPixel.networkProtectionRemoteMessageStorageFailed, error: error))
                }
            case .failure(let error):
                // Ignore 403 errors, those happen when a file can't be found on S3
                if case APIRequest.Error.invalidStatusCode(403) = error {
                    self.updateLastRefreshDate() // Avoid refreshing constantly when the file isn't available
                    return
                }

                PixelKit.fire(DebugEvent(GeneralPixel.networkProtectionRemoteMessageFetchingFailed, error: error))
            }
        }

    }

    /// Uses the "days since VPN activated" count combined with the set of dismissed messages to determine which messages should be displayed to the user.
    func presentableRemoteMessages() -> [SurveyRemoteMessage] {
        let dismissedMessageIDs = messageStorage.dismissedMessageIDs()
        let possibleMessages: [SurveyRemoteMessage] = messageStorage.storedMessages()

        // TODO: Check all attributes

        let filteredMessages = possibleMessages.filter { message in
            if dismissedMessageIDs.contains(message.id) {
                return false
            }

            // Check subscription status:

            if let subscriptionStatus = message.attributes.subscriptionStatus {

            }

            // Check VPN usage:
            
            if let requiredDaysSinceActivation = message.attributes.daysSinceVPNEnabled,
               let daysSinceActivation = waitlistActivationDateStore.daysSinceActivation() {
                if requiredDaysSinceActivation <= daysSinceActivation {
                    return true
                } else {
                    return false
                }
            }

            // Don't show messages unless at least one attribute matches:
            return false

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
