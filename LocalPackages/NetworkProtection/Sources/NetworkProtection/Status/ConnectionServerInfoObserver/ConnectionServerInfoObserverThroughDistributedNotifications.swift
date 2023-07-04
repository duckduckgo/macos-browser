//
//  ConnectionServerInfoObserverThroughDistributedNotifications.swift
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

#if os(macOS)

import Combine
import Foundation
import Common
import NetworkExtension
import NotificationCenter

/// Observes the server info through Distributed Notifications and an IPC connection.
///
public class ConnectionServerInfoObserverThroughDistributedNotifications: ConnectionServerInfoObserver {
    public let publisher = CurrentValueSubject<NetworkProtectionStatusServerInfo, Never>(.unknown)

    // MARK: - Notifications

    private let distributedNotificationCenter: DistributedNotificationCenter
    private var serverSelectedCancellable: AnyCancellable!

    // MARK: - Logging

    private let log: OSLog

    // MARK: - Initialization

    public init(distributedNotificationCenter: DistributedNotificationCenter = .forType(.networkProtection),
                log: OSLog = .networkProtection) {

        self.distributedNotificationCenter = distributedNotificationCenter
        self.log = log

        start()
    }

    func start() {
        serverSelectedCancellable = distributedNotificationCenter.publisher(for: .serverSelected).sink { [weak self] notification in
            self?.handleServerSelected(notification)
        }
    }

    private func handleServerSelected(_ notification: Notification) {

        let serverInfo: NetworkProtectionStatusServerInfo

        do {
            serverInfo = try ServerSelectedNotificationObjectDecoder().decodeObject(from: notification)
        } catch {
            let error = StaticString(stringLiteral: "Could not decode .serverSelected distributed notification object")
            assertionFailure("\(error)")
            os_log(error, log: log, type: .error)
            return
        }

        publisher.send(serverInfo)
    }
}

#endif
