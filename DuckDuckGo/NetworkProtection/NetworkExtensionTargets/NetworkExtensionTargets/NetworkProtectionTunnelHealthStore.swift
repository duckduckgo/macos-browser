//
//  NetworkProtectionTunnelHealthStore.swift
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

/// Stores information about NetP's tunnel health
///
final class NetworkProtectionTunnelHealthStore {
    private static let isHavingConnectivityIssuesKey = "com.duckduckgo.isHavingConnectivityIssues"
    private let userDefaults: UserDefaults
    private let distributedNotificationCenter: DistributedNotificationCenter

    init(userDefaults: UserDefaults = .standard,
         distributedNotificationCenter: DistributedNotificationCenter = .forType(.networkProtection)) {
        self.userDefaults = userDefaults
        self.distributedNotificationCenter = distributedNotificationCenter
    }

    var isHavingConnectivityIssues: Bool {
        get {
            userDefaults.bool(forKey: Self.isHavingConnectivityIssuesKey)
        }
        set {
            guard newValue != userDefaults.bool(forKey: Self.isHavingConnectivityIssuesKey) else {
                return
            }

            userDefaults.set(newValue, forKey: Self.isHavingConnectivityIssuesKey)
            postIssueChangeNotification(newValue: newValue)
        }
    }

    // MARK: - Posting Issue Notifications

    private func postIssueChangeNotification(newValue: Bool) {
        if newValue {
            distributedNotificationCenter.post(.issuesStarted)
        } else {
            distributedNotificationCenter.post(.issuesResolved)
        }
    }
}
