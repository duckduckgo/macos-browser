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
import os

/// Classes that implement this protocol are in charge of relaying status changes.
///
public protocol NetworkProtectionStatusReporter {
    var statusPublisher: CurrentValueSubject<ConnectionStatus, Never> { get }
    var connectivityIssuesPublisher: CurrentValueSubject<Bool, Never> { get }
    var serverInfoPublisher: CurrentValueSubject<NetworkProtectionStatusServerInfo, Never> { get }
    var connectionErrorPublisher: CurrentValueSubject<String?, Never> { get }
    var controllerErrorMessagePublisher: CurrentValueSubject<String?, Never> { get }
}

/// Convenience struct used to relay server info updates through a reporter.
///
public struct NetworkProtectionStatusServerInfo: Codable, Equatable {
    public static let unknown = NetworkProtectionStatusServerInfo(serverLocation: nil, serverAddress: nil)

    /// The server location.  A `nil` location means unknown
    ///
    public let serverLocation: String?

    /// The server address.  A `nil` address means unknown.
    ///
    public let serverAddress: String?

    public init(serverLocation: String?, serverAddress: String?) {
        self.serverLocation = serverLocation
        self.serverAddress = serverAddress
    }
}

/// This is the default status reporter.
///
public final class DefaultNetworkProtectionStatusReporter: NetworkProtectionStatusReporter {

    // MARK: - Logging

    /// The logger that this object will use for errors that are handled by this class.
    ///
    private let logger: NetworkProtectionLogger

    // MARK: - Notifications

    private let distributedNotificationCenter: DistributedNotificationCenter

    // MARK: - Notifications: Observation Tokens

    private var observationTokens = [NotificationToken]()

    // MARK: - Publishers

    private let statusObserver: ConnectionStatusObserver
    public var statusPublisher: CurrentValueSubject<ConnectionStatus, Never> {
        statusObserver.publisher
    }
    public let connectivityIssuesPublisher = CurrentValueSubject<Bool, Never>(false)
    private let serverInfoObserver: ConnectionServerInfoObserver
    public var serverInfoPublisher: CurrentValueSubject<NetworkProtectionStatusServerInfo, Never> {
        serverInfoObserver.publisher
    }
    private let connectionErrorObserver: ConnectionErrorObserver
    public var connectionErrorPublisher: CurrentValueSubject<String?, Never> {
        connectionErrorObserver.publisher
    }
    public let controllerErrorMessagePublisher = CurrentValueSubject<String?, Never>(nil)

    // MARK: - Init & deinit

    public init(statusObserver: ConnectionStatusObserver,
                serverInfoObserver: ConnectionServerInfoObserver,
                connectionErrorObserver: ConnectionErrorObserver,
                distributedNotificationCenter: DistributedNotificationCenter = .forType(.networkProtection),
                logger: NetworkProtectionLogger = DefaultNetworkProtectionLogger()) {

        self.statusObserver = statusObserver
        self.serverInfoObserver = serverInfoObserver
        self.connectionErrorObserver = connectionErrorObserver
        self.distributedNotificationCenter = distributedNotificationCenter
        self.logger = logger

        start()
    }

    // MARK: - Starting & Stopping

    private func start() {
        observationTokens.append(distributedNotificationCenter.addObserver(for: .controllerErrorChanged, object: nil, queue: nil) { [weak self] notification in

            self?.handleControllerErrorStatusChanged(notification)
        })

        observationTokens.append(distributedNotificationCenter.addObserver(for: .issuesStarted, object: nil, queue: nil) { [weak self] _ in

            self?.connectivityIssuesPublisher.send(true)
        })

        observationTokens.append(distributedNotificationCenter.addObserver(for: .issuesResolved, object: nil, queue: nil) { [weak self] _ in

            self?.connectivityIssuesPublisher.send(false)
        })

        distributedNotificationCenter.post(.newStatusObserver)
    }

    // MARK: - Updating controller errors

    private func handleControllerErrorStatusChanged(_ notification: Notification) {
        let errorMessage = notification.object as? String
        controllerErrorMessagePublisher.send(errorMessage)
    }

    /// Queries the extension for connectivity issues and updates the state locally.
    ///
    private func updateConnectivityIssues(session: NETunnelProviderSession) throws {
        let request = Data([ExtensionMessage.isHavingConnectivityIssues.rawValue])
        try session.sendProviderMessage(request) { [weak self] data in
            guard let self = self,
                  let data = data else {
                return
            }

            // This is a quick solution for now to decode a bool from the data, which
            // indicates whether there are connection issues or not.
            // A more appropriate solution when we have time would be to use proper encoding
            // maybe using a JSON encoder.
            let value = data[0] == 1

            if value != self.connectivityIssuesPublisher.value {
                self.connectivityIssuesPublisher.send(value)
            }
        }
    }
}
