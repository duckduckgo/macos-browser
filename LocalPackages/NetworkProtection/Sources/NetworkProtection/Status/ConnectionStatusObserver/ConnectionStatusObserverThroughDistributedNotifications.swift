//
//  ConnectionStatusObserverThroughDistributedNotifications.swift
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

/// Observes the tunnel status through Distributed Notifications.
///
public class ConnectionStatusObserverThroughDistributedNotifications: ConnectionStatusObserver {
    public let publisher = CurrentValueSubject<ConnectionStatus, Never>(.unknown)

    // MARK: - Network Path Monitoring

    private static let monitorDispatchQueue = DispatchQueue(label: "com.duckduckgo.NetworkProtection.ConnectionStatusObserverThroughDistributedNotifications.monitorDispatchQueue", qos: .background)
    private let monitor = NWPathMonitor()
    private static let timeoutOnNetworkChanges: TimeInterval = .seconds(3)
    private var lastStatusChangeTimestamp: Date?

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
        distributedNotificationCenter.publisher(for: .statusDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
            self?.handleDistributedStatusChangeNotification(notification)
        }.store(in: &cancellables)

        workspaceNotificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
            self?.handleDidWake(notification)
        }.store(in: &cancellables)

        monitor.pathUpdateHandler = { [weak self] _ in
            self?.requestStatusUpdate()
        }
        monitor.start(queue: Self.monitorDispatchQueue)
    }

    private func handleDistributedStatusChangeNotification(_ notification: Notification) {
        let statusChange: ConnectionStatusChange

        do {
            statusChange = try ConnectionStatusChangeDecoder().decodeObject(from: notification)
        } catch {
            os_log("Could not decode .statusDidChange distributed notification object: %{public}@", log: log, type: .error, String(describing: notification.object))
            assertionFailure("Could not decode .statusDidChange distributed notification object: \(String(describing: notification.object))")
            return
        }

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

    /// This method checks if we should process a status change notification, or if it has already been processed and there's
    /// no need to do it again.
    ///
    /// We should process the received status change if any of the following conditions is true:
    ///     - We have never processed a status change before; or
    ///     - The last status change we recorded was prior to the newly received change.
    ///
    /// - Parameters:
    ///     - change: a change that we want to know if we need to process or not.
    ///
    private func shouldProcessStatusChange(_ change: ConnectionStatusChange) -> Bool {
        guard let lastStatusChangeTimestamp else {
            return true
        }

        return lastStatusChangeTimestamp < change.timestamp
    }

    /// Requests a status update and updates the status to disconnected if we don't hear back within a certain time.
    /// The timeout is currently set to 3 seconds.
    ///
    private func requestStatusUpdate() {
        distributedNotificationCenter.post(.requestStatusUpdate)

        var cancellable: AnyCancellable!

        cancellable = publisher
            .dropFirst()
            .timeout(.seconds(Self.timeoutOnNetworkChanges), scheduler: DispatchQueue.main)
            .sink(receiveCompletion: { [weak publisher] completion in
                if case .failure = completion {
                    publisher?.send(.disconnected)
                }

                cancellable.cancel()
            }, receiveValue: { _ in
                cancellable.cancel()
            })
    }

    // MARK: - Logging

    private func logStatusChanged(status: ConnectionStatus) {
        os_log("%{public}@: connection status is now %{public}@", log: log, type: .debug, String(describing: self), String(describing: status))
    }
}
