//
//  ConnectionServerInfoObserverThroughSession.swift
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
public class ConnectionServerInfoObserverThroughSession: ConnectionServerInfoObserver {
    public let publisher = CurrentValueSubject<NetworkProtectionStatusServerInfo, Never>(.unknown)

    // MARK: - Notifications

    private let notificationCenter: NotificationCenter
    private let platformNotificationCenter: NotificationCenter
    private let platformDidWakeNotification: Notification.Name
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Logging

    private let log: OSLog

    // MARK: - Initialization

    public init(notificationCenter: NotificationCenter = .default,
                platformNotificationCenter: NotificationCenter,
                platformDidWakeNotification: Notification.Name,
                log: OSLog = .networkProtection) {

        self.notificationCenter = notificationCenter
        self.platformNotificationCenter = platformNotificationCenter
        self.platformDidWakeNotification = platformDidWakeNotification
        self.log = log

        start()
    }

    func start() {
        notificationCenter.publisher(for: .NEVPNStatusDidChange).sink { [weak self] notification in
            self?.handleStatusChangeNotification(notification)
        }.store(in: &cancellables)

        platformNotificationCenter.publisher(for: platformDidWakeNotification).sink { [weak self] notification in
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

                await updateServerInfo(session: session)
            } catch {
                os_log("Failed to handle wake %{public}@", log: log, type: .error, error.localizedDescription)
            }
        }
    }

    private func handleStatusChangeNotification(_ notification: Notification) {
        guard let session = ConnectionSessionUtilities.session(from: notification) else {
            return
        }

        Task {
            await updateServerInfo(session: session)
        }
    }

    // MARK: - Obtaining the NetP VPN status

    private func updateServerInfo(session: NETunnelProviderSession) async {
        let serverAddress = await self.serverAddress(from: session)
        let serverLocation = await self.serverLocation(from: session)

        let newServerInfo = NetworkProtectionStatusServerInfo(serverLocation: serverLocation, serverAddress: serverAddress)

        publisher.send(newServerInfo)
    }

    private func serverAddress(from session: NETunnelProviderSession) async -> String? {
        await withCheckedContinuation { continuation in
            do {
                let request = Data([ExtensionMessage.getServerAddress.rawValue])
                try session.sendProviderMessage(request) { data in
                    guard let data = data else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let serverAddress = String(data: data, encoding: ExtensionMessage.preferredStringEncoding)
                    continuation.resume(returning: serverAddress)
                }
            } catch {
                // Cannot communicate with session, this is acceptable in case the session is down
                continuation.resume(returning: nil)
            }
        }
    }

    private func serverLocation(from session: NETunnelProviderSession) async -> String? {
        await withCheckedContinuation { continuation in
            let request = Data([ExtensionMessage.getServerLocation.rawValue])

            do {
                try session.sendProviderMessage(request) { data in
                    guard let data = data else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let serverLocation = String(data: data, encoding: ExtensionMessage.preferredStringEncoding)
                    continuation.resume(returning: serverLocation)
                }
            } catch {
                // Cannot communicate with session, this is acceptable in case the session is down
                continuation.resume(returning: nil)
            }
        }
    }
}
