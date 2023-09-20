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

protocol NetworkProtectionRemoteMessaging {

    func fetchRemoteMessages()
    func presentableRemoteMessages() -> [NetworkProtectionRemoteMessage]
    func dismissRemoteMessage(with id: String)

}

final class DefaultNetworkProtectionRemoteMessaging: NetworkProtectionRemoteMessaging {

    private let messageRequest: NetworkProtectionRemoteMessagingRequest
    private let messageStorage: NetworkProtectionRemoteMessagingStorage

    init(
        messageRequest: NetworkProtectionRemoteMessagingRequest = DefaultNetworkProtectionRemoteMessagingRequest(),
        messageStorage: NetworkProtectionRemoteMessagingStorage = DefaultNetworkProtectionRemoteMessagingStorage()
    ) {
        self.messageRequest = messageRequest
        self.messageStorage = messageStorage
    }

    func fetchRemoteMessages() {
        // 1. Fetch remote messages
        // 2. Store them
    }

    func presentableRemoteMessages() -> [NetworkProtectionRemoteMessage] {
        return []
    }

    func dismissRemoteMessage(with id: String) {

    }

}
