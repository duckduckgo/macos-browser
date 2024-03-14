//
//  NetworkProtectionRemoteMessaging.swift
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

#if NETWORK_PROTECTION

protocol NetworkProtectionRemoteMessaging {

    func fetchRemoteMessages(completion: (() -> Void)?)
    func presentableRemoteMessages() -> [NetworkProtectionRemoteMessage]
    func dismiss(message: NetworkProtectionRemoteMessage)

}

final class DefaultNetworkProtectionRemoteMessaging: NetworkProtectionRemoteMessaging {

    enum Constants {
        static let lastRefreshDateKey = "network-protection.remote-messaging.last-refresh-date"
    }

    private let messageRequest: HomePageRemoteMessagingRequest
    private let messageStorage: HomePageRemoteMessagingStorage
    private let waitlistStorage: WaitlistStorage
    private let waitlistActivationDateStore: WaitlistActivationDateStore
    private let networkProtectionVisibility: NetworkProtectionFeatureVisibility
    private let minimumRefreshInterval: TimeInterval
    private let userDefaults: UserDefaults

    convenience init() {
        #if DEBUG || REVIEW
        self.init(minimumRefreshInterval: .seconds(30))
        #else
        self.init(minimumRefreshInterval: .hours(1))
        #endif
    }

    init(
        messageRequest: HomePageRemoteMessagingRequest = DefaultHomePageRemoteMessagingRequest.networkProtectionMessagesRequest(),
        messageStorage: HomePageRemoteMessagingStorage = DefaultHomePageRemoteMessagingStorage.networkProtection(),
        waitlistStorage: WaitlistStorage = WaitlistKeychainStore(waitlistIdentifier: "networkprotection", keychainAppGroup: Bundle.main.appGroup(bundle: .netP)),
        waitlistActivationDateStore: WaitlistActivationDateStore = DefaultWaitlistActivationDateStore(source: .netP),
        networkProtectionVisibility: NetworkProtectionFeatureVisibility = DefaultNetworkProtectionVisibility(),
        minimumRefreshInterval: TimeInterval,
        userDefaults: UserDefaults = .standard
    ) {
        self.messageRequest = messageRequest
        self.messageStorage = messageStorage
        self.waitlistStorage = waitlistStorage
        self.waitlistActivationDateStore = waitlistActivationDateStore
        self.networkProtectionVisibility = networkProtectionVisibility
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
            let result: Result<[NetworkProtectionRemoteMessage], Error> = result

            switch result {
            case .success(let messages):
                do {
                    try self.messageStorage.store(messages: messages)
                    self.updateLastRefreshDate() // Update last refresh date on success, otherwise let the app try again next time
                } catch {
                    Pixel.fire(.debug(event: .networkProtectionRemoteMessageStorageFailed, error: error))
                }
            case .failure(let error):
                // Ignore 403 errors, those happen when a file can't be found on S3
                if case APIRequest.Error.invalidStatusCode(403) = error {
                    self.updateLastRefreshDate() // Avoid refreshing constantly when the file isn't available
                    return
                }

                Pixel.fire(.debug(event: .networkProtectionRemoteMessageFetchingFailed, error: error))
            }
        }

    }

    /// Uses the "days since VPN activated" count combined with the set of dismissed messages to determine which messages should be displayed to the user.
    func presentableRemoteMessages() -> [NetworkProtectionRemoteMessage] {
        let dismissedMessageIDs = messageStorage.dismissedMessageIDs()
        let possibleMessages: [NetworkProtectionRemoteMessage] = messageStorage.storedMessages()

        // Only show messages that haven't been dismissed, and check whether they have a
        // requirement on how long the user has used the VPN for.
        let filteredMessages = possibleMessages.filter { message in

            // Don't show messages that have already been dismissed. If you need to show the same message to a user again,
            // it should get a new message ID.
            if dismissedMessageIDs.contains(message.id) {
                return false
            }

            // First, check messages that require a number of days of NetP usage
            if let requiredDaysSinceActivation = message.daysSinceNetworkProtectionEnabled,
               let daysSinceActivation = waitlistActivationDateStore.daysSinceActivation() {
                if requiredDaysSinceActivation <= daysSinceActivation {
                    return true
                } else {
                    return false
                }
            }

            // Next, check if the message requires access to NetP but it's not visible:
            if message.requiresNetworkProtectionAccess, !networkProtectionVisibility.isNetworkProtectionVisible() {
                return false
            }

            // Finally, check if the message requires NetP usage, and check if the user has used it at all:
            if message.requiresNetworkProtectionUsage, waitlistActivationDateStore.daysSinceActivation() == nil {
                return false
            }

            return true

        }

        return filteredMessages
    }

    func dismiss(message: NetworkProtectionRemoteMessage) {
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

#endif
