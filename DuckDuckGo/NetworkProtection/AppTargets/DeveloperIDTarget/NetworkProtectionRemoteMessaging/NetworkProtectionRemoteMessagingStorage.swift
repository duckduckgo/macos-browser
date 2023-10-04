//
//  NetworkProtectionRemoteMessagingStorage.swift
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

protocol NetworkProtectionRemoteMessagingStorage {

    func store(messages: [NetworkProtectionRemoteMessage]) throws
    func storedMessages() -> [NetworkProtectionRemoteMessage]

    func dismissRemoteMessage(with id: String)
    func dismissedMessageIDs() -> [String]

}

final class DefaultNetworkProtectionRemoteMessagingStorage: NetworkProtectionRemoteMessagingStorage {

    private enum Constants {
        static let dismissedMessageIdentifiersKey = "home.page.network-protection.dismissed-message-identifiers"
        static let networkProtectionMessagesFileName = "network-protection-messages.json"
    }

    private let userDefaults: UserDefaults
    private let messagesURL: URL
    private static var applicationSupportURL: URL {
        URL.sandboxApplicationSupportURL.appendingPathComponent(Constants.networkProtectionMessagesFileName)
    }

    init(
        userDefaults: UserDefaults = .standard,
        messagesURL: URL = DefaultNetworkProtectionRemoteMessagingStorage.applicationSupportURL
    ) {
        self.userDefaults = userDefaults
        self.messagesURL = messagesURL
    }

    func store(messages: [NetworkProtectionRemoteMessage]) throws {
        let encoded = try JSONEncoder().encode(messages)
        try encoded.write(to: messagesURL)
    }

    func storedMessages() -> [NetworkProtectionRemoteMessage] {
        do {
            let messagesData = try Data(contentsOf: messagesURL)
            let messages = try JSONDecoder().decode([NetworkProtectionRemoteMessage].self, from: messagesData)

            return messages
        } catch {
            // Errors can occur if the file doesn't exist, or it got stored in a bad state, in which case the app will fetch the file again later and
            // overwrite it.
            return []
        }
    }

    func dismissRemoteMessage(with id: String) {
        var dismissedMessages = dismissedMessageIDs()

        guard !dismissedMessages.contains(id) else {
            return
        }

        dismissedMessages.append(id)
        userDefaults.set(dismissedMessages, forKey: Constants.dismissedMessageIdentifiersKey)
    }

    func dismissedMessageIDs() -> [String] {
        let messages = userDefaults.array(forKey: Constants.dismissedMessageIdentifiersKey) as? [String]
        return messages ?? []
    }

    func removeStoredAndDismissedMessages() {
        userDefaults.removeObject(forKey: Constants.dismissedMessageIdentifiersKey)
        try? FileManager.default.removeItem(at: messagesURL)
    }

}
