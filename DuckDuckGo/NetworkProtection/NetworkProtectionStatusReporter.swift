//
//  NetworkProtectionStatusReporter.swift
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
import NetworkExtension
import NetworkProtection
import NotificationCenter
import os

/// Classes that implement this protocol are in charge of relaying status changes.
///
protocol NetworkProtectionStatusReporter {
    var statusChangePublisher: CurrentValueSubject<NetworkProtectionConnectionStatus, Never> { get }
    var connectivityIssuesPublisher: CurrentValueSubject<Bool, Never> { get }
    var serverInfoPublisher: CurrentValueSubject<NetworkProtectionStatusServerInfo, Never> { get }
    var tunnelErrorMessagePublisher: CurrentValueSubject<String?, Never> { get }
    var controllerErrorMessagePublisher: CurrentValueSubject<String?, Never> { get }
}

/// Convenience struct used to relay server info updates through a reporter.
///
struct NetworkProtectionStatusServerInfo: Equatable {
    static let unknown = NetworkProtectionStatusServerInfo(serverLocation: nil, serverAddress: nil)

    /// The server location.  A `nil` location means unknown
    ///
    let serverLocation: String?

    /// The server address.  A `nil` address means unknown.
    ///
    let serverAddress: String?
}

/// This is the default status reporter.
///
final class DefaultNetworkProtectionStatusReporter: NetworkProtectionStatusReporter {

    // MARK: - Logging

    /// The logger that this object will use for errors that are handled by this class.
    ///
    private let logger: NetworkProtectionLogger

    // MARK: - Notifications

    private let notificationCenter: NotificationCenter
    private let workspaceNotificationCenter: NotificationCenter
    private let distributedNotificationCenter: DistributedNotificationCenter

    // MARK: - Publishers

    let statusChangePublisher = CurrentValueSubject<NetworkProtectionConnectionStatus, Never>(.unknown)
    let connectivityIssuesPublisher = CurrentValueSubject<Bool, Never>(false)
    let serverInfoPublisher = CurrentValueSubject<NetworkProtectionStatusServerInfo, Never>(.unknown)
    let tunnelErrorMessagePublisher = CurrentValueSubject<String?, Never>(nil)
    let controllerErrorMessagePublisher = CurrentValueSubject<String?, Never>(nil)

    // MARK: - Stores

    private let controllerErrorStore = NetworkProtectionControllerErrorStore()

    // MARK: - Init & deinit

    init(notificationCenter: NotificationCenter = .default,
         workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
         distributedNotificationCenter: DistributedNotificationCenter = .forType(.networkProtection),
         logger: NetworkProtectionLogger = DefaultNetworkProtectionLogger()) {

        self.notificationCenter = notificationCenter
        self.workspaceNotificationCenter = workspaceNotificationCenter
        self.distributedNotificationCenter = distributedNotificationCenter
        self.logger = logger

        start()
    }

    // MARK: - Starting & Stopping

    private func start() {
        Task {
            await updateServerInfo()
        }

        notificationCenter.addObserver(forName: .NEVPNStatusDidChange, object: nil, queue: nil) { [weak self] notification in
            self?.handleStatusChangeNotification(notification)
        }

        workspaceNotificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil) { [weak self] notification in
            self?.handleDidWake(notification)
        }

        distributedNotificationCenter.addObserver(forName: .NetPTunnelErrorStatusChanged, object: nil, queue: nil) { [weak self] _ in
            guard let self = self else {
                return
            }

            Task {
                do {
                    try await self.updateTunnelErrorMessage()
                } catch {
                    os_log("🔵 Error when attempting to update the tunnel error message: %{public}@", type: .error, error.localizedDescription)
                }
            }
        }

        distributedNotificationCenter.addObserver(forName: .NetPControllerErrorStatusChanged, object: nil, queue: nil) { [weak self] _ in
            guard let self = self else {
                return
            }

            Task {
                do {
                    try await self.updateControllerErrorMessage()
                } catch {
                    os_log("🔵 Error when attempting to update the tunnel error message: %{public}@", type: .error, error.localizedDescription)
                }
            }
        }

        distributedNotificationCenter.addObserver(forName: .NetPConnectivityIssuesStarted, object: nil, queue: nil, using: { [weak self] _ in

            self?.connectivityIssuesPublisher.send(true)
        })

        distributedNotificationCenter.addObserver(forName: .NetPConnectivityIssuesResolved, object: nil, queue: nil, using: { [weak self] _ in

            self?.connectivityIssuesPublisher.send(false)
        })

        distributedNotificationCenter.addObserver(forName: .NetPServerSelected, object: nil, queue: nil) { [weak self] _ in
            guard let self = self else {
                return
            }

            Task {
                await self.updateServerInfo()
            }
        }
    }

    // MARK: - Handling Status Changes

    private func handleStatusChangeNotification(_ notification: Notification) {
        guard let session = managedSession(from: notification) else {
            return
        }

        do {
            try handleStatusChange(in: session)
        } catch {
            logger.log(error)
        }
    }

    private func handleStatusChange(in session: NETunnelProviderSession) throws {
        /// Some situations can cause the connection status in the session's manager to be invalid.
        /// This just means we need to reload the manager from preferences.  That will trigger another status change
        /// notification that will provide a valid connection status.
        guard session.manager.connection.status != .invalid else {
            Task {
                try await session.manager.loadFromPreferences()
            }
            return
        }

        let status = self.connectionStatus(from: session)
        statusChangePublisher.send(status)

        try updateTunnelErrorMessage(session: session)
        try updateConnectivityIssues(session: session)
    }

    // MARK: - Waking from Sleep

    private func handleDidWake(_ notification: Notification) {
        Task {
            do {
                guard let session = try await DefaultNetworkProtectionProvider.activeSession() else {
                    return
                }

                try handleStatusChange(in: session)
            } catch {
                logger.log(error)
            }
        }
    }

    // MARK: - Updating controller errors

    private func updateControllerErrorMessage() async throws {
        let controllerErrorStore = NetworkProtectionControllerErrorStore()
        controllerErrorMessagePublisher.send(controllerErrorStore.lastErrorMessage)
    }

    // MARK: - Updating tunnel errors

    private func updateTunnelErrorMessage() async throws {
        guard let activeSession = try await DefaultNetworkProtectionProvider.activeSession() else {
            return
        }

        try updateTunnelErrorMessage(session: activeSession)
    }

    private func updateTunnelErrorMessage(session: NETunnelProviderSession) throws {
        let request = Data([NetworkProtectionAppRequest.getLastErrorMessage.rawValue])
        try session.sendProviderMessage(request) { [weak self] data in
            guard let self = self else {
                return
            }

            guard let data = data else {
                self.tunnelErrorMessagePublisher.send(nil)
                return
            }

            let errorMessage = String(data: data, encoding: NetworkProtectionAppRequest.preferredStringEncoding)

            if errorMessage != self.tunnelErrorMessagePublisher.value {
                self.tunnelErrorMessagePublisher.send(errorMessage)
            }
        }
    }

    /// Queries the extension for connectivity issues and updates the state locally.
    ///
    private func updateConnectivityIssues(session: NETunnelProviderSession) throws {
        let request = Data([NetworkProtectionAppRequest.isHavingConnectivityIssues.rawValue])
        try session.sendProviderMessage(request) { [weak self] data in
            guard let self = self,
                  let data = data else {
                return
            }

            let value = data[0] == 1

            if value != self.connectivityIssuesPublisher.value {
                self.connectivityIssuesPublisher.send(value)
            }
        }
    }

    // MARK: - Handling Server Changes

    private func updateServerInfo() async {
        let session: NETunnelProviderSession

        do {
            guard let activeSession = try await DefaultNetworkProtectionProvider.activeSession() else {
                return
            }

            session = activeSession
        } catch {
            os_log("🔵 Error when attempting to retrieve the active session: %{public}@", type: .error, error.localizedDescription)
            return
        }

        let serverAddress = await self.serverAddress(from: session)
        let serverLocation = await self.serverLocation(from: session)

        let newServerInfo = NetworkProtectionStatusServerInfo(serverLocation: serverLocation, serverAddress: serverAddress)

        serverInfoPublisher.send(newServerInfo)
    }

    private func serverAddress(from session: NETunnelProviderSession) async -> String? {
        await withCheckedContinuation { continuation in
            do {
                let request = Data([NetworkProtectionAppRequest.getServerAddress.rawValue])
                try session.sendProviderMessage(request) { data in
                    guard let data = data else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let serverAddress = String(data: data, encoding: NetworkProtectionAppRequest.preferredStringEncoding)
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
            let request = Data([NetworkProtectionAppRequest.getServerLocation.rawValue])

            do {
                try session.sendProviderMessage(request) { data in
                    guard let data = data else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let serverLocation = String(data: data, encoding: NetworkProtectionAppRequest.preferredStringEncoding)
                    continuation.resume(returning: serverLocation)
                }
            } catch {
                // Cannot communicate with session, this is acceptable in case the session is down
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Obtaining the NetP VPN status

    /// Retrieves a session that we are managing.  When we're running as a system extension we'll get notifications
    /// for all VPN connections in the system, so we just want to follow the notifications for the connections we own.
    ///
    private func managedSession(from notification: Notification) -> NETunnelProviderSession? {
        guard let session = (notification.object as? NETunnelProviderSession),
              session.manager.protocolConfiguration is NETunnelProviderProtocol else {
            return nil
        }

        return session
    }

    private func connectedDate(from session: NETunnelProviderSession) -> Date {
        // In theory when the connection has been established, the date should be set.  But in a worst-case
        // scenario where for some reason the date is missing, we're going to just use Date() as the connection
        // has just started and it's a decent aproximation.
        session.connectedDate ?? Date()
    }

    private func connectionStatus(from session: NETunnelProviderSession) -> NetworkProtectionConnectionStatus {
        let internalStatus = session.status
        let status: NetworkProtectionConnectionStatus

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
}
