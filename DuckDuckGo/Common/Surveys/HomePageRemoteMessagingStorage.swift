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

protocol SurveyRemoteMessagingStorage {

    func dismissRemoteMessage(with id: String)
    func dismissedMessageIDs() -> [String]

}

final class DefaultSurveyRemoteMessagingStorage: SurveyRemoteMessagingStorage {

    enum SurveyConstants {
        static let dismissedMessageIdentifiersKey = "home.page.survey.dismissed-message-identifiers"
        static let surveyMessagesFileName = "survey-messages.json"
    }

    private let userDefaults: UserDefaults
    private let messagesURL: URL
    private let dismissedMessageIdentifiersKey: String

    private static var applicationSupportURL: URL {
        URL.sandboxApplicationSupportURL
    }

    static func surveys() -> DefaultSurveyRemoteMessagingStorage {
        return DefaultSurveyRemoteMessagingStorage(
            messagesFileName: SurveyConstants.surveyMessagesFileName,
            dismissedMessageIdentifiersKey: SurveyConstants.dismissedMessageIdentifiersKey
        )
    }

    init(
        userDefaults: UserDefaults = .standard,
        messagesDirectoryURL: URL = DefaultSurveyRemoteMessagingStorage.applicationSupportURL,
        messagesFileName: String,
        dismissedMessageIdentifiersKey: String
    ) {
        self.userDefaults = userDefaults
        self.messagesURL = messagesDirectoryURL.appendingPathComponent(messagesFileName)
        self.dismissedMessageIdentifiersKey = dismissedMessageIdentifiersKey
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

    func removeStoredMessagesIfNecessary() {
        try? FileManager.default.removeItem(at: messagesURL)
    }

    func removeStoredAndDismissedMessages() {
        userDefaults.removeObject(forKey: dismissedMessageIdentifiersKey)
        try? FileManager.default.removeItem(at: messagesURL)
    }

}
