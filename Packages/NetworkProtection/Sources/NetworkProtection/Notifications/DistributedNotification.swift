//
//  DistributedNotification.swift
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

extension DistributedNotificationCenter.CenterType {
    public static let networkProtection = DistributedNotificationCenter.CenterType("com.duckduckgo.DistributedNotificationCenter.CenterType.networkProtection")
}

extension NotificationCenter {
    public func addObserver(for networkProtectionNotification: DistributedNotification, object: Any?, queue: OperationQueue?, using block: @escaping @Sendable (Notification) -> Void) -> NSObjectProtocol {

        addObserver(forName: networkProtectionNotification.name, object: object, queue: queue, using: block)
    }
}

extension DistributedNotificationCenter {
    public func post(_ networkProtectionNotification: DistributedNotification, object: String? = nil) {
        self.postNotificationName(networkProtectionNotification.name, object: object, options: [.deliverImmediately, .postToAllSessions])
    }
}

public enum DistributedNotification: String {
    // Tunnel Status
    case statusDidChange = "com.duckduckgo.network-protection.NetworkProtectionNotification.statusDidChange"

    // Connection issues
    case issuesStarted = "com.duckduckgo.network-protection.NetworkProtectionNotification.issuesStarted"
    case issuesResolved = "com.duckduckgo.network-protection.NetworkProtectionNotification.issuesResolved"

    // Server Selection
    case serverSelected = "com.duckduckgo.network-protection.NetworkProtectionNotification.serverSelected"

    // XPC Service
    case ipcListenerStarted = "com.duckduckgo.network-protection.NetworkProtectionNotification.ipcListenerStarted"

    // Error Events
    case tunnelErrorChanged = "com.duckduckgo.network-protection.NetworkProtectionNotification.tunnelErrorChanged"
    case controllerErrorChanged = "com.duckduckgo.network-protection.NetworkProtectionNotification.controllerErrorChanged"

    // New Status Observer
    case newStatusObserver = "com.duckduckgo.network-protection.NetworkProtectionNotification.newStatusObserver"

    static let preferredStringEncoding = String.Encoding.utf8

    public var name: Foundation.Notification.Name {
        NSNotification.Name(rawValue: rawValue)
    }
}
