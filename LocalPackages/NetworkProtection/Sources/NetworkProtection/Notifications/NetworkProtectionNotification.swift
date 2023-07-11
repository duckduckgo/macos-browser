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
import Common

#if os(macOS)

fileprivate extension Bundle {
    private static let networkProtectionDistributedNotificationPrefixKey = "DISTRIBUTED_NOTIFICATIONS_PREFIX"

    var networkProtectionDistributedNotificationPrefix: String {
        guard let bundleID = object(forInfoDictionaryKey: Self.networkProtectionDistributedNotificationPrefixKey) as? String else {
            fatalError("Info.plist is missing \(Self.networkProtectionDistributedNotificationPrefixKey)")
        }

        return bundleID
    }
}

extension DistributedNotificationCenter {
    // MARK: - Logging

    private func logPost(_ notification: NetworkProtectionNotification, object: String? = nil, log: OSLog = .networkProtectionDistributedNotificationsLog) {

        if let string = object {
            os_log("%{public}@: Distributed notification posted: %{public}@ (%{public}@)", log: log, type: .debug, String(describing: Thread.current), notification.name.rawValue, string)
        } else {
            os_log("Distributed notification posted: %{public}@", log: log, type: .debug, notification.name.rawValue)
        }
    }
}

extension DistributedNotificationCenter: NetworkProtectionNotificationPosting {
    public func post(_ networkProtectionNotification: NetworkProtectionNotification, object: String? = nil, log: OSLog = .networkProtectionDistributedNotificationsLog) {
        logPost(networkProtectionNotification, object: object, log: log)

        postNotificationName(networkProtectionNotification.name, object: object, options: [.deliverImmediately, .postToAllSessions])
    }
}

#endif

public protocol NetworkProtectionNotificationPosting: AnyObject {
    func post(_ networkProtectionNotification: NetworkProtectionNotification, object: String?, log: OSLog)
}

public extension NetworkProtectionNotificationPosting {
    func post(_ networkProtectionNotification: NetworkProtectionNotification, object: String? = nil) {
        post(networkProtectionNotification, object: object, log: .networkProtectionDistributedNotificationsLog)
    }
}

public typealias NetworkProtectionNotificationCenter = NotificationCenter & NetworkProtectionNotificationPosting

extension NotificationCenter {
    static let preferredStringEncoding = String.Encoding.utf8

    public func addObserver(for networkProtectionNotification: NetworkProtectionNotification, object: Any?, queue: OperationQueue?, using block: @escaping @Sendable (Notification) -> Void) -> NSObjectProtocol {

        addObserver(forName: networkProtectionNotification.name, object: object, queue: queue, using: block)
    }

    public func publisher(for networkProtectionNotification: NetworkProtectionNotification, object: AnyObject? = nil) -> NotificationCenter.Publisher {
        self.publisher(for: networkProtectionNotification.name)
    }
}

public enum NetworkProtectionNotification: String {
    // Tunnel Status
    case statusDidChange

    // Connection issues
    case issuesStarted
    case issuesResolved

    // User Notification Events
    case showIssuesStartedNotification
    case showIssuesResolvedNotification
    case showIssuesNotResolvedNotification
    case showVPNSupersededNotification

    // Server Selection
    case serverSelected

    // Error Events
    case tunnelErrorChanged
    case controllerErrorChanged

    // New Status Observer
    case requestStatusUpdate

    fileprivate var name: Foundation.Notification.Name {
        NSNotification.Name(rawValue: fullNotificationName(for: rawValue))
    }

    private func fullNotificationName(for notificationName: String) -> String {
        "\(Bundle.main.networkProtectionDistributedNotificationPrefix).\(notificationName)"
    }
}
