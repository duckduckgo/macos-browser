//
//  ConnectionStatusObserverThroughIPC.swift
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

import Combine
import Foundation
import NetworkExtension
import NotificationCenter
import Common

/// Observes the tunnel status through Distributed Notifications and an IPC connection.
///
public class ConnectionStatusObserverThroughIPC: ConnectionStatusObserver {
    public let publisher = CurrentValueSubject<ConnectionStatus, Never>(.unknown)

    // MARK: - Network Path Monitoring

    private static let monitorDispatchQueue = DispatchQueue(label: "com.duckduckgo.NetworkProtection.ConnectionStatusObserverThroughIPC.monitorDispatchQueue", qos: .background)
    private let monitor = NWPathMonitor()
    private static let timeoutOnNetworkChanges = TimeInterval(3)
    private var lastUpdate: Date = Date()

    // MARK: - Notifications: Decoding

    private let connectionStatusDecoder = ConnectionStatusDecoder()

    // MARK: - Notifications

    private let distributedNotificationCenter: DistributedNotificationCenter
    private let workspaceNotificationCenter: NotificationCenter
    private var observationTokens = [NotificationToken]()

    // MARK: - Logging

    private let log: OSLog

    // MARK: - Initialization

    public init(distributedNotificationCenter: DistributedNotificationCenter = .forType(.networkProtection),
                workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
                log: OSLog = .networkProtectionStatusReporterLog) {

        self.distributedNotificationCenter = distributedNotificationCenter
        self.workspaceNotificationCenter = workspaceNotificationCenter
        self.log = log

        start()
    }

    func start() {
        observationTokens.append(distributedNotificationCenter.addObserver(for: .statusDidChange, object: nil, queue: nil) { [weak self] notification in
            self?.handleDistributedStatusChangeNotification(notification)
        })

        observationTokens.append(workspaceNotificationCenter.addObserver(for: NSWorkspace.didWakeNotification, object: nil, queue: nil) { [weak self] notification in
            self?.handleDidWake(notification)
        })

        // swiftlint:disable:next unused_capture_list
        monitor.pathUpdateHandler = { [weak self] _ in
            guard let self else {
                return
            }

            requestStatusUpdate()
        }
        monitor.start(queue: Self.monitorDispatchQueue)
    }

    private func handleDistributedStatusChangeNotification(_ notification: Notification) {
        let connectionStatus = connectionStatusDecoder.decode(notification.object)
        logStatusChanged(status: connectionStatus)
        lastUpdate = Date()

        publisher.send(connectionStatus)
    }

    private func handleDidWake(_ notification: Notification) {
        requestStatusUpdate()
    }

    // MARK: - Requesting Status Updates

    /// Requests a status update and updates the status to disconnected if we don't hear back within a certain time.
    /// The timeout is currently set to 3 seconds.
    ///
    private func requestStatusUpdate() {
        let requestDate = Date()
        distributedNotificationCenter.post(.requestStatusUpdate)

        Task {
            try? await Task.sleep(nanoseconds: UInt64(Self.timeoutOnNetworkChanges * Double(NSEC_PER_SEC)))

            if lastUpdate < requestDate {
                publisher.send(.disconnected)
            }
        }
    }

    // MARK: - Logging

    private func logStatusChanged(status: ConnectionStatus) {
        os_log("%{public}@: connection status is now %{public}@", log: log, type: .debug, String(describing: self), String(describing: status))
    }
}
