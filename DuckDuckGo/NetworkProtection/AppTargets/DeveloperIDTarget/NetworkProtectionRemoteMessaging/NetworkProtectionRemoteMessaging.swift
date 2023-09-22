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

extension Notification.Name {
    static let NetworkProtectionRemoteMessagesChanged = NSNotification.Name("NetworkProtectionRemoteMessagesChanged")
}

protocol NetworkProtectionRemoteMessaging {

    func fetchRemoteMessages()
    func presentableRemoteMessages() -> [NetworkProtectionRemoteMessage]
    func dismissRemoteMessage(with id: String)

}

final class DefaultNetworkProtectionRemoteMessaging: NetworkProtectionRemoteMessaging {

    enum NetworkProtectionRemoteMessagingError {
        case test
    }

    private let messageRequest: NetworkProtectionRemoteMessagingRequest
    private let messageStorage: NetworkProtectionRemoteMessagingStorage
    private let waitlistActivationDateStore: WaitlistActivationDateStore
    private let userDefaults: UserDefaults

    init(
        messageRequest: NetworkProtectionRemoteMessagingRequest = DefaultNetworkProtectionRemoteMessagingRequest(),
        messageStorage: NetworkProtectionRemoteMessagingStorage = DefaultNetworkProtectionRemoteMessagingStorage(),
        waitlistActivationDateStore: WaitlistActivationDateStore = DefaultWaitlistActivationDateStore(),
        userDefaults: UserDefaults = .standard
    ) {
        self.messageRequest = messageRequest
        self.messageStorage = messageStorage
        self.waitlistActivationDateStore = waitlistActivationDateStore
        self.userDefaults = userDefaults
    }

    func fetchRemoteMessages() {
#if NETWORK_PROTECTION
        // Don't fetch messages if the user hasn't used NetP
        guard waitlistActivationDateStore.daysSinceActivation() != nil else {
            return
        }

        // TODO: Don't fetch messages if this has already been done recently

        messageRequest.fetchNetworkProtectionRemoteMessages { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let messages):
                do {
                    try self.messageStorage.store(messages: messages)

                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .NetworkProtectionRemoteMessagesChanged, object: nil)
                    }
                } catch {
                    Pixel.fire(.debug(event: .networkProtectionRemoteMessageStorageFailed, error: error))
                }
            case .failure(let error):
                // Ignore 403 errors, those happen when a file can't be found on S3
                if case APIRequest.Error.invalidStatusCode(403) = error {
                    return
                }

                Pixel.fire(.debug(event: .networkProtectionRemoteMessageFetchingFailed, error: error))
            }
        }
#endif
    }

    /// Uses the "days since Network Protection activated" count combined with the set of dismissed messages to determine which messages should be displayed to the user.
    func presentableRemoteMessages() -> [NetworkProtectionRemoteMessage] {
#if NETWORK_PROTECTION
        guard let daysSinceActivation = waitlistActivationDateStore.daysSinceActivation() else {
            return []
        }

        let dismissedMessageIDs = messageStorage.dismissedMessageIDs()
        let possibleMessages = messageStorage.storedMessages()

        // Only show messages that haven't been dismissed, and check whether they have a requirement on how long the user
        // has used Network Protection for.
        let filteredMessages = possibleMessages.filter { message in
            if dismissedMessageIDs.contains(message.id) {
                return false
            }

            if let requiredDaysSinceActivation = message.daysSinceNetworkProtectionEnabled {
                if requiredDaysSinceActivation <= daysSinceActivation {
                    return true
                } else {
                    return false
                }
            } else {
                return true
            }
        }

        return filteredMessages
#else
        return []
#endif
    }

    func dismissRemoteMessage(with id: String) {
#if NETWORK_PROTECTION
        messageStorage.dismissRemoteMessage(with: id)
#endif
    }

}
