//
//  NetworkProtectionControllerErrorStore.swift
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
import NetworkProtection

/// This class provides a mechanism to store and announce issues when interacting with the tunnel.
/// The reason this lass is necessry is because we need to store and share failures across different UI elements.  As an example
/// we may need to show these errors in the status menu (which will eventually be run in its own agent), and in the status view within
/// the app.
///
final class NetworkProtectionControllerErrorStore {
    private static let lastErrorMessageKey = "com.duckduckgo.NetworkProtectionControllerErrorStore.lastErrorMessage"
    private let userDefaults: UserDefaults
    private let distributedNotificationCenter: DistributedNotificationCenter

    init(userDefaults: UserDefaults = .standard,
         distributedNotificationCenter: DistributedNotificationCenter = .default()) {
        self.userDefaults = userDefaults
        self.distributedNotificationCenter = distributedNotificationCenter
    }

    var lastErrorMessage: String? {
        get {
            userDefaults.string(forKey: Self.lastErrorMessageKey)
        }

        set {
            userDefaults.set(newValue, forKey: Self.lastErrorMessageKey)
            postErrorChangedNotification(errorMessage: newValue)
        }
    }

    // MARK: - Posting Notifications

    private func postErrorChangedNotification(errorMessage: String?) {
        distributedNotificationCenter.post(.controllerErrorChanged, object: errorMessage)
    }
}
