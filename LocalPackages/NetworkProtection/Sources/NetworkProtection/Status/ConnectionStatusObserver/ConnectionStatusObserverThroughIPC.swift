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
    private static let timeoutOnNetworkChanges: TimeInterval = .seconds(3)
    private var lastStatusResponse = Date()
    private var lastStatusChangeTimestamp: Date?

    // MARK: - Notifications: Decoding

    private let connectionStatusDecoder = ConnectionStatusChangeDecoder()

    // MARK: - Notifications

    private let distributedNotificationCenter: DistributedNotificationCenter
    private let workspaceNotificationCenter: NotificationCenter
    private var cancellables = Set<AnyCancellable>()

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
        distributedNotificationCenter.publisher(for: .statusDidChange).sink { [weak self] notification in
            self?.handleDistributedStatusChangeNotification(notification)
        }.store(in: &cancellables)

        workspaceNotificationCenter.publisher(for: NSWorkspace.didWakeNotification).sink { [weak self] notification in
            self?.handleDidWake(notification)
        }.store(in: &cancellables)

        monitor.pathUpdateHandler = { [weak self] _ in
            self?.requestStatusUpdate()
        }
        monitor.start(queue: Self.monitorDispatchQueue)
    }

    private func handleDistributedStatusChangeNotification(_ notification: Notification) {
        let statusChange = connectionStatusDecoder.decode(notification.object)
        lastStatusResponse = Date()

        guard shouldProcessStatusChange(statusChange) else {
            return
        }

        lastStatusChangeTimestamp = statusChange.timestamp
        logStatusChanged(status: statusChange.status)

        publisher.send(statusChange.status)
    }

    private func handleDidWake(_ notification: Notification) {
        requestStatusUpdate()
    }

    // MARK: - Requesting Status Updates

    private func shouldProcessStatusChange(_ change: ConnectionStatusChange) -> Bool {
        guard let lastStatusChangeTimestamp else {
            return true
        }

        return publisher.value != change.status || lastStatusChangeTimestamp < change.timestamp
    }

    /// Requests a status update and updates the status to disconnected if we don't hear back within a certain time.
    /// The timeout is currently set to 3 seconds.
    ///
    private func requestStatusUpdate() {
        let requestDate = Date()
        distributedNotificationCenter.post(.requestStatusUpdate)

        Task {
            try? await Task.sleep(interval: Self.timeoutOnNetworkChanges)

            if lastStatusResponse < requestDate {
                publisher.send(.disconnected)
            }
        }
    }

    // MARK: - Logging

    private func logStatusChanged(status: ConnectionStatus) {
        os_log("%{public}@: connection status is now %{public}@", log: log, type: .debug, String(describing: self), String(describing: status))
    }
}
