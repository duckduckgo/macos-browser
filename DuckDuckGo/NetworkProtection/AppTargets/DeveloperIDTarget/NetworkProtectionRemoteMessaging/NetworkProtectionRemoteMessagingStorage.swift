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

    func store(messages: [NetworkProtectionRemoteMessage])
    func storedMessages() -> [NetworkProtectionRemoteMessage]

    func dismissRemoteMessage(with id: String)
    func dismissedMessageIDs() -> [String]

}

final class DefaultNetworkProtectionRemoteMessagingStorage: NetworkProtectionRemoteMessagingStorage {

    func store(messages: [NetworkProtectionRemoteMessage]) {
        // TODO
    }

    func storedMessages() -> [NetworkProtectionRemoteMessage] {
        return []
    }

    func dismissRemoteMessage(with id: String) {
        // TODO
    }

    func dismissedMessageIDs() -> [String] {
        return []
    }

}
