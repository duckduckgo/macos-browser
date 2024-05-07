//
//  NetworkProtectionKnownFailureStore.swift
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

import Foundation
import NetworkProtection

final class NetworkProtectionKnownFailureStore {
    private static let lastKnownFailureKey = "com.duckduckgo.NetworkProtectionKnownFailureStore.knownFailure"
    private let userDefaults: UserDefaults
    private let distributedNotificationCenter: DistributedNotificationCenter

    init(userDefaults: UserDefaults = .standard,
         distributedNotificationCenter: DistributedNotificationCenter = .default()) {
        self.userDefaults = userDefaults
        self.distributedNotificationCenter = distributedNotificationCenter
    }

    var lastKnownFailure: KnownFailure? {
        get {
            guard let data = userDefaults.data(forKey: Self.lastKnownFailureKey) else { return nil }
            return try? JSONDecoder().decode(KnownFailure.self, from: data)
        }

        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            userDefaults.set(data, forKey: Self.lastKnownFailureKey)
            postKnownFailureUpdatedNotification(data: data)
        }
    }

    // MARK: - Posting Notifications

    private func postKnownFailureUpdatedNotification(data: Data?) {
        let object: String? = {
            guard let data else { return nil }
            return String(data: data, encoding: .utf8)
        }()
        distributedNotificationCenter.post(.knownFailureUpdated, object: object)
    }
}
