//
//  ConnectionStatusObserverThroughSession.swift
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

/// This status observer can only be used from the App that owns the tunnel, as other Apps won't have access to the
/// NEVPNStatusDidChange notifications or tunnel session.
///
public class ConnectionStatusObserverThroughSession: ConnectionStatusObserver {
    public let publisher = CurrentValueSubject<ConnectionStatus, Never>(.unknown)

    // MARK: - Notifications

    private let notificationCenter: NotificationCenter
    private let workspaceNotificationCenter: NotificationCenter
    private var observationTokens = [NotificationToken]()

    // MARK: - Logging

    private let log: OSLog

    // MARK: - Initialization

    public init(notificationCenter: NotificationCenter = .default,
                workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
                log: OSLog = .networkProtectionStatusReporterLog) {

        self.notificationCenter = notificationCenter
        self.workspaceNotificationCenter = workspaceNotificationCenter
        self.log = log

        start()
    }

    private func start() {
        Task {
            await loadInitialStatus()
            startObservers()
        }
    }

    private func startObservers() {
        observationTokens.append(notificationCenter.addObserver(for: .NEVPNStatusDidChange, object: nil, queue: nil) { [weak self] notification in
            self?.handleStatusChangeNotification(notification)
        })

        observationTokens.append(workspaceNotificationCenter.addObserver(for: NSWorkspace.didWakeNotification, object: nil, queue: nil) { [weak self] notification in
            self?.handleDidWake(notification)
        })
    }

    private func loadInitialStatus() async {
        guard let session = try? await ConnectionSessionUtilities.activeSession() else {
            return
        }

        handleStatusChange(in: session)
    }

    // MARK: - Handling Notifications

    private func handleDidWake(_ notification: Notification) {
        Task {
            do {
                guard let session = try await ConnectionSessionUtilities.activeSession() else {
                    return
                }

                handleStatusChange(in: session)
            } catch {
                os_log("%{public}@: failed to handle wake %{public}@", log: log, type: .error, String(describing: self), error.localizedDescription)
            }
        }
    }

    private func handleStatusChangeNotification(_ notification: Notification) {
        guard let session = ConnectionSessionUtilities.session(from: notification) else {
            return
        }

        handleStatusChange(in: session)
    }

    private func handleStatusChange(in session: NETunnelProviderSession) {
        let status = self.connectionStatus(from: session)
        publisher.send(status)
    }

    // MARK: - Obtaining the NetP VPN status

    private func connectedDate(from session: NETunnelProviderSession) -> Date {
        // In theory when the connection has been established, the date should be set.  But in a worst-case
        // scenario where for some reason the date is missing, we're going to just use Date() as the connection
        // has just started and it's a decent aproximation.
        session.connectedDate ?? Date()
    }

    private func connectionStatus(from session: NETunnelProviderSession) -> ConnectionStatus {
        let internalStatus = session.status
        let status: ConnectionStatus

        switch internalStatus {
        case .connected:
            let connectedDate = connectedDate(from: session)
            status = .connected(connectedDate: connectedDate)
        case .connecting:
            status = .connecting
        case .reasserting:
            status = .reasserting
        case .disconnected, .invalid:
            status = .disconnected
        case .disconnecting:
            status = .disconnecting
        @unknown default:
            status = .unknown
        }

        return status
    }

    // MARK: - Logging

    private func logStatusChanged(status: ConnectionStatus) {
        os_log("%{public}@: connection status is now %{public}@", log: log, type: .debug, String(describing: self), String(describing: status))
    }
}
