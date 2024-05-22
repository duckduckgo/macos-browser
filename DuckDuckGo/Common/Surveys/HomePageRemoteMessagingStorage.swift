//
//  HomePageRemoteMessagingStorage.swift
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

protocol HomePageRemoteMessagingStorage {

    func store<Message: Codable>(messages: [Message]) throws
    func storedMessages<Message: Codable>() -> [Message]

    func dismissRemoteMessage(with id: String)
    func dismissedMessageIDs() -> [String]

}

final class DefaultHomePageRemoteMessagingStorage: HomePageRemoteMessagingStorage {

    enum SurveyConstants {
        static let dismissedMessageIdentifiersKey = "home.page.survey.dismissed-message-identifiers"
        static let networkProtectionMessagesFileName = "survey-messages.json"
    }

    private let userDefaults: UserDefaults
    private let messagesURL: URL
    private let dismissedMessageIdentifiersKey: String

    private static var applicationSupportURL: URL {
        URL.sandboxApplicationSupportURL
    }

    static func surveys() -> DefaultHomePageRemoteMessagingStorage {
        return DefaultHomePageRemoteMessagingStorage(
            messagesFileName: SurveyConstants.networkProtectionMessagesFileName,
            dismissedMessageIdentifiersKey: SurveyConstants.dismissedMessageIdentifiersKey
        )
    }

    init(
        userDefaults: UserDefaults = .standard,
        messagesDirectoryURL: URL = DefaultHomePageRemoteMessagingStorage.applicationSupportURL,
        messagesFileName: String,
        dismissedMessageIdentifiersKey: String
    ) {
        self.userDefaults = userDefaults
        self.messagesURL = messagesDirectoryURL.appendingPathComponent(messagesFileName)
        self.dismissedMessageIdentifiersKey = dismissedMessageIdentifiersKey
    }

    func store<Message: Codable>(messages: [Message]) throws {
        let encoded = try JSONEncoder().encode(messages)
        try encoded.write(to: messagesURL)
    }

    func storedMessages<Message: Codable>() -> [Message] {
        do {
            let messagesData = try Data(contentsOf: messagesURL)
            let messages = try JSONDecoder().decode([Message].self, from: messagesData)

            return messages
        } catch {
            // Errors can occur if the file doesn't exist or the schema changed, in which case the app will fetch the file again later and
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
        userDefaults.set(dismissedMessages, forKey: dismissedMessageIdentifiersKey)
    }

    func dismissedMessageIDs() -> [String] {
        let messages = userDefaults.array(forKey: dismissedMessageIdentifiersKey) as? [String]
        return messages ?? []
    }

    func removeStoredAndDismissedMessages() {
        userDefaults.removeObject(forKey: dismissedMessageIdentifiersKey)
        try? FileManager.default.removeItem(at: messagesURL)
    }

}
