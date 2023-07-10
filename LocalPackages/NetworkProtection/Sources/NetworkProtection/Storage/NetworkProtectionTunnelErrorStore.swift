//
//  NetworkProtectionTunnelErrorStore.swift
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
import Common

/// This class provides a mechanism to store and announce errors with the tunnel.
/// The reason this class is necessary is because we need to store and share failures across different UI elements.  As an example
/// we may need to show these errors in the status menu (which will eventually be run in its own agent), and in the status view within
/// the app.
///
public final class NetworkProtectionTunnelErrorStore {
    private static let lastErrorMessageKey = "com.duckduckgo.NetworkProtectionTunnelErrorStore.lastErrorMessage"
    private let userDefaults: UserDefaults
    private let notificationCenter: NetworkProtectionNotificationCenter

    public init(userDefaults: UserDefaults = .standard,
                notificationCenter: NetworkProtectionNotificationCenter) {
        self.userDefaults = userDefaults
        self.notificationCenter = notificationCenter
    }

    public var lastErrorMessage: String? {
        get {
            userDefaults.string(forKey: Self.lastErrorMessageKey)
        }

        set {
            userDefaults.set(newValue, forKey: Self.lastErrorMessageKey)
            postLastErrorMessageChangedNotification(newValue)
        }
    }
    // MARK: - Posting Notifications
    private func postLastErrorMessageChangedNotification(_ errorMessage: String?) {
        notificationCenter.post(.tunnelErrorChanged, object: errorMessage)
    }
}
