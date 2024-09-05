//
//  MockRemoteMessagingStore.swift
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

import RemoteMessaging

class MockRemoteMessagingStore: RemoteMessagingStoring {

    var saveProcessedResultCalls = 0
    var fetchRemoteMessagingConfigCalls = 0
    var fetchScheduledRemoteMessageCalls = 0
    var fetchRemoteMessageCalls = 0
    var hasShownRemoteMessageCalls = 0
    var fetchShownRemoteMessageIdsCalls = 0
    var hasDismissedRemoteMessageCalls = 0
    var dismissRemoteMessageCalls = 0
    var fetchDismissedRemoteMessageIdsCalls = 0
    var updateRemoteMessageCalls = 0

    var remoteMessagingConfig: RemoteMessagingConfig?
    var scheduledRemoteMessage: RemoteMessageModel?
    var remoteMessages: [String: RemoteMessageModel]
    var shownRemoteMessagesIDs: [String]
    var dismissedRemoteMessagesIDs: [String]

    init(
        remoteMessagingConfig: RemoteMessagingConfig? = nil,
        scheduledRemoteMessage: RemoteMessageModel? = nil,
        remoteMessages: [String: RemoteMessageModel] = [:],
        shownRemoteMessagesIDs: [String] = [],
        dismissedRemoteMessagesIDs: [String] = []
    ) {
        self.remoteMessagingConfig = remoteMessagingConfig
        self.scheduledRemoteMessage = scheduledRemoteMessage
        self.remoteMessages = remoteMessages
        self.shownRemoteMessagesIDs = shownRemoteMessagesIDs
        self.dismissedRemoteMessagesIDs = dismissedRemoteMessagesIDs
    }

    func saveProcessedResult(_ processorResult: RemoteMessagingConfigProcessor.ProcessorResult) {
        saveProcessedResultCalls += 1
    }

    func fetchRemoteMessagingConfig() -> RemoteMessagingConfig? {
        fetchRemoteMessagingConfigCalls += 1
        return remoteMessagingConfig
    }

    func fetchScheduledRemoteMessage() -> RemoteMessageModel? {
        fetchScheduledRemoteMessageCalls += 1
        return scheduledRemoteMessage
    }

    func fetchRemoteMessage(withID id: String) -> RemoteMessageModel? {
        fetchRemoteMessageCalls += 1
        return remoteMessages[id]
    }

    func hasShownRemoteMessage(withID id: String) -> Bool {
        hasShownRemoteMessageCalls += 1
        return shownRemoteMessagesIDs.contains(id)
    }

    func fetchShownRemoteMessageIDs() -> [String] {
        fetchShownRemoteMessageIdsCalls += 1
        return shownRemoteMessagesIDs
    }

    func hasDismissedRemoteMessage(withID id: String) -> Bool {
        hasDismissedRemoteMessageCalls += 1
        return dismissedRemoteMessagesIDs.contains(id)
    }

    func dismissRemoteMessage(withID id: String) {
        dismissRemoteMessageCalls += 1
    }

    func fetchDismissedRemoteMessageIDs() -> [String] {
        fetchDismissedRemoteMessageIdsCalls += 1
        return dismissedRemoteMessagesIDs
    }

    func updateRemoteMessage(withID id: String, asShown shown: Bool) {
        updateRemoteMessageCalls += 1
        if shown {
            shownRemoteMessagesIDs.append(id)
        } else {
            shownRemoteMessagesIDs.removeAll(where: { $0 == id })
        }
    }

    func resetRemoteMessages() {}
}
