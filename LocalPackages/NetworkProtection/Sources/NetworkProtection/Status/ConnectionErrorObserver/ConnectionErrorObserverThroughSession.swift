//
//  ConnectionErrorObserver.swift
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

import AppKit
import Combine
import Foundation
import NetworkExtension
import Common

/// This status observer can only be used from the App that owns the tunnel, as other Apps won't have access to the
/// NEVPNStatusDidChange notifications or tunnel session.
///
public class ConnectionErrorObserverThroughSession: ConnectionErrorObserver {
    public let publisher = CurrentValueSubject<String?, Never>(nil)

    // MARK: - Notifications

    private let notificationCenter: NotificationCenter
    private let workspaceNotificationCenter: NotificationCenter
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Logging

    private let log: OSLog

    // MARK: - Initialization

    public init(notificationCenter: NotificationCenter = .default,
                workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
                log: OSLog = .networkProtection) {

        self.notificationCenter = notificationCenter
        self.workspaceNotificationCenter = workspaceNotificationCenter
        self.log = log

        start()
    }

    func start() {
        notificationCenter.publisher(for: .NEVPNStatusDidChange).sink { [weak self] notification in
            self?.handleStatusChangeNotification(notification)
        }.store(in: &cancellables)

        workspaceNotificationCenter.publisher(for: NSWorkspace.didWakeNotification).sink { [weak self] notification in
            self?.handleDidWake(notification)
        }.store(in: &cancellables)
    }

    // MARK: - Handling Notifications

    private func handleDidWake(_ notification: Notification) {
        Task {
            do {
                guard let session = try await ConnectionSessionUtilities.activeSession() else {
                    return
                }

                try updateTunnelErrorMessage(session: session)
            } catch {
                os_log("Failed to handle wake %{public}@", log: log, type: .error, error.localizedDescription)
            }
        }
    }

    private func handleStatusChangeNotification(_ notification: Notification) {
        do {
            guard let session = ConnectionSessionUtilities.session(from: notification) else {
                return
            }

            try updateTunnelErrorMessage(session: session)
        } catch {
            os_log("Failed to handle status change %{public}@", log: log, type: .error, error.localizedDescription)
        }
    }

    // MARK: - Obtaining the NetP VPN status

    private func updateTunnelErrorMessage(session: NETunnelProviderSession) throws {
        let request = Data([ExtensionMessage.getLastErrorMessage.rawValue])
        try session.sendProviderMessage(request) { [weak self] data in
            guard let self = self else {
                return
            }

            guard let data = data else {
                self.publisher.send(nil)
                return
            }

            let errorMessage = String(data: data, encoding: ExtensionMessage.preferredStringEncoding)

            if errorMessage != self.publisher.value {
                self.publisher.send(errorMessage)
            }
        }
    }
}
