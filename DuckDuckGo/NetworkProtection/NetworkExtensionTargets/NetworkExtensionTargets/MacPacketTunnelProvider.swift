//
//  MacPacketTunnelProvider.swift
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
import Combine
import Common
import NetworkProtection
import NetworkExtension
import Networking
import PixelKit

final class MacPacketTunnelProvider: PacketTunnelProvider {

    // MARK: - Additional Status Info

    /// Holds the date when the status was last changed so we can send it out as additional information
    /// in our status-change notifications.
    ///
    private var lastStatusChangeDate = Date()

    // MARK: - Notifications: Observation Tokens

    private var cancellables = Set<AnyCancellable>()

    // MARK: - User Notifications

    private static func makeNotificationsPresenter() -> NetworkProtectionNotificationsPresenter {
#if NETP_SYSTEM_EXTENSION
        return NetworkProtectionAgentNotificationsPresenter(notificationCenter: DistributedNotificationCenter.default())
#else
        let parentBundlePath = "../../../"
        let mainAppURL: URL
        if #available(macOS 13, *) {
            mainAppURL = URL(filePath: parentBundlePath, relativeTo: Bundle.main.bundleURL)
        } else {
            mainAppURL = URL(fileURLWithPath: parentBundlePath, relativeTo: Bundle.main.bundleURL)
        }
        return NetworkProtectionUNNotificationsPresenter(appLauncher: AppLauncher(appBundleURL: mainAppURL))
#endif
    }

    private let appLauncher: AppLaunching?

    // MARK: - Error Reporting

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private static func networkProtectionDebugEvents(controllerErrorStore: NetworkProtectionTunnelErrorStore) -> EventMapping<NetworkProtectionError>? {
        return EventMapping { event, _, _, _ in
            let domainEvent: NetworkProtectionPixelEvent
#if DEBUG
            // Makes sure we see the error in the yellow NetP alert.
            controllerErrorStore.lastErrorMessage = "[Debug] Error event: \(event.localizedDescription)"
#endif
            switch event {
            case .noServerRegistrationInfo:
                domainEvent = .networkProtectionTunnelConfigurationNoServerRegistrationInfo
            case .couldNotSelectClosestServer:
                domainEvent = .networkProtectionTunnelConfigurationCouldNotSelectClosestServer
            case .couldNotGetPeerPublicKey:
                domainEvent = .networkProtectionTunnelConfigurationCouldNotGetPeerPublicKey
            case .couldNotGetPeerHostName:
                domainEvent = .networkProtectionTunnelConfigurationCouldNotGetPeerHostName
            case .couldNotGetInterfaceAddressRange:
                domainEvent = .networkProtectionTunnelConfigurationCouldNotGetInterfaceAddressRange
            case .failedToFetchServerList(let eventError):
                domainEvent = .networkProtectionClientFailedToFetchServerList(error: eventError)
            case .failedToParseServerListResponse:
                domainEvent = .networkProtectionClientFailedToParseServerListResponse
            case .failedToEncodeRegisterKeyRequest:
                domainEvent = .networkProtectionClientFailedToEncodeRegisterKeyRequest
            case .failedToFetchRegisteredServers(let eventError):
                domainEvent = .networkProtectionClientFailedToFetchRegisteredServers(error: eventError)
            case .failedToParseRegisteredServersResponse:
                domainEvent = .networkProtectionClientFailedToParseRegisteredServersResponse
            case .failedToEncodeRedeemRequest:
                domainEvent = .networkProtectionClientFailedToEncodeRedeemRequest
            case .invalidInviteCode:
                domainEvent = .networkProtectionClientInvalidInviteCode
            case .failedToRedeemInviteCode(let error):
                domainEvent = .networkProtectionClientFailedToRedeemInviteCode(error: error)
            case .failedToParseRedeemResponse(let error):
                domainEvent = .networkProtectionClientFailedToParseRedeemResponse(error: error)
            case .invalidAuthToken:
                domainEvent = .networkProtectionClientInvalidAuthToken
            case .serverListInconsistency:
                return
            case .failedToEncodeServerList:
                domainEvent = .networkProtectionServerListStoreFailedToEncodeServerList
            case .failedToDecodeServerList:
                domainEvent = .networkProtectionServerListStoreFailedToDecodeServerList
            case .failedToWriteServerList(let eventError):
                domainEvent = .networkProtectionServerListStoreFailedToWriteServerList(error: eventError)
            case .noServerListFound:
                return
            case .couldNotCreateServerListDirectory:
                return
            case .failedToReadServerList(let eventError):
                domainEvent = .networkProtectionServerListStoreFailedToReadServerList(error: eventError)
            case .failedToCastKeychainValueToData(let field):
                domainEvent = .networkProtectionKeychainErrorFailedToCastKeychainValueToData(field: field)
            case .keychainReadError(let field, let status):
                domainEvent = .networkProtectionKeychainReadError(field: field, status: status)
            case .keychainWriteError(let field, let status):
                domainEvent = .networkProtectionKeychainWriteError(field: field, status: status)
            case .keychainDeleteError(let status):
                domainEvent = .networkProtectionKeychainDeleteError(status: status)
            case .wireGuardCannotLocateTunnelFileDescriptor:
                domainEvent = .networkProtectionWireguardErrorCannotLocateTunnelFileDescriptor
            case .wireGuardInvalidState:
                domainEvent = .networkProtectionWireguardErrorInvalidState
            case .wireGuardDnsResolution:
                domainEvent = .networkProtectionWireguardErrorFailedDNSResolution
            case .wireGuardSetNetworkSettings(let error):
                domainEvent = .networkProtectionWireguardErrorCannotSetNetworkSettings(error: error)
            case .startWireGuardBackend(let code):
                domainEvent = .networkProtectionWireguardErrorCannotStartWireguardBackend(code: code)
            case .noAuthTokenFound:
                domainEvent = .networkProtectionNoAuthTokenFoundError
            case .unhandledError(function: let function, line: let line, error: let error):
                domainEvent = .networkProtectionUnhandledError(function: function, line: line, error: error)
            }

            PixelKit.Pixel.fire(domainEvent, frequency: .dailyAndContinuous, withHeaders: [:])
        }
    }

    private let notificationCenter: NetworkProtectionNotificationCenter = DistributedNotificationCenter.default()

    // MARK: - PacketTunnelProvider.Event reporting

    private static var packetTunnelProviderEvents: EventMapping<PacketTunnelProvider.Event> = .init { event, _, _, _ in
        switch event {
        case .userBecameActive:
            Pixel.fire(
                NetworkProtectionPixelEvent.networkProtectionActiveUser,
                frequency: .dailyOnly,
                withHeaders: [:],
                includeAppVersionParameter: true
            )
        case .reportLatency(ms: let ms, server: let server, networkType: let networkType):
            Pixel.fire(
                NetworkProtectionPixelEvent.networkProtectionLatency(
                    ms: ms,
                    server: server,
                    networkType: networkType
                ), frequency: .standard, withHeaders: [:]
            )
        case .rekeyCompleted:
            Pixel.fire(
                NetworkProtectionPixelEvent.networkProtectionRekeyCompleted,
                frequency: .dailyAndContinuous,
                withHeaders: [:],
                includeAppVersionParameter: true
            )
        }
    }

    static var tokenServiceName: String {
#if NETP_SYSTEM_EXTENSION
        "\(Bundle.main.bundleIdentifier!).authToken"
#else
        NetworkProtectionKeychainTokenStore.Defaults.tokenStoreService
#endif
    }

    // MARK: - Initialization

    @objc public init() {
        self.appLauncher = AppLauncher(appBundleURL: .mainAppBundleURL)

        let tunnelHealthStore = NetworkProtectionTunnelHealthStore(notificationCenter: notificationCenter)
        let controllerErrorStore = NetworkProtectionTunnelErrorStore(notificationCenter: notificationCenter)
        let debugEvents = Self.networkProtectionDebugEvents(controllerErrorStore: controllerErrorStore)
        let tokenStore = NetworkProtectionKeychainTokenStore(keychainType: NetworkProtectionBundle.keychainType,
                                                             serviceName: Self.tokenServiceName,
                                                             errorEvents: debugEvents)

        super.init(notificationsPresenter: Self.makeNotificationsPresenter(),
                   tunnelHealthStore: tunnelHealthStore,
                   controllerErrorStore: controllerErrorStore,
                   keychainType: NetworkProtectionBundle.keychainType,
                   tokenStore: tokenStore,
                   debugEvents: debugEvents,
                   providerEvents: Self.packetTunnelProviderEvents)

        observeConnectionStatusChanges()
        observeServerChanges()
        observeStatusUpdateRequests()
    }

    // MARK: - Observing Changes & Requests

    /// Observe connection status changes to broadcast those changes through distributed notifications.
    ///
    private func observeConnectionStatusChanges() {
        connectionStatusPublisher.sink { [weak self] status in
            self?.lastStatusChangeDate = Date()
            self?.broadcast(status)
        }
        .store(in: &cancellables)
    }

    /// Observe server changes to broadcast those changes through distributed notifications.
    ///
    private func observeServerChanges() {
        lastSelectedServerInfoPublisher.sink { [weak self] server in
            self?.lastStatusChangeDate = Date()
            self?.broadcast(server)
        }
        .store(in: &cancellables)

        broadcastLastSelectedServerInfo()
    }

    /// Observe status update requests to broadcast connection status
    ///
    private func observeStatusUpdateRequests() {
        notificationCenter.publisher(for: .requestStatusUpdate).sink { [weak self] _ in
            self?.broadcastConnectionStatus()
            self?.broadcastLastSelectedServerInfo()
        }
        .store(in: &cancellables)
    }

    // MARK: - Broadcasting Status and Information

    /// Broadcasts the current connection status.
    ///
    private func broadcastConnectionStatus() {
        broadcast(connectionStatus)
    }

    /// Broadcasts the specified connection status.
    ///
    private func broadcast(_ connectionStatus: ConnectionStatus) {
        let lastStatusChange = ConnectionStatusChange(status: connectionStatus, on: lastStatusChangeDate)
        let payload = ConnectionStatusChangeEncoder().encode(lastStatusChange)

        notificationCenter.post(.statusDidChange, object: payload)
    }

    /// Broadcasts the current server information.
    ///
    private func broadcastLastSelectedServerInfo() {
        broadcast(lastSelectedServerInfo)
    }

    /// Broadcasts the specified server information.
    ///
    private func broadcast(_ serverInfo: NetworkProtectionServerInfo?) {
        guard let serverInfo else {
            return
        }

        let serverStatusInfo = NetworkProtectionStatusServerInfo(serverLocation: serverInfo.serverLocation, serverAddress: serverInfo.endpoint?.description)
        let payload = ServerSelectedNotificationObjectEncoder().encode(serverStatusInfo)

        notificationCenter.post(.serverSelected, object: payload)
    }

    // MARK: - NEPacketTunnelProvider

    enum ConfigurationError: Error {
        case missingProviderConfiguration
        case missingPixelHeaders
    }

    public override func loadVendorOptions(from provider: NETunnelProviderProtocol?) throws {
        try super.loadVendorOptions(from: provider)

        guard let vendorOptions = provider?.providerConfiguration else {
            os_log("🔵 Provider is nil, or providerConfiguration is not set", log: .networkProtection)
            throw ConfigurationError.missingProviderConfiguration
        }

        try loadDefaultPixelHeaders(from: vendorOptions)
    }

    private func loadDefaultPixelHeaders(from options: [String: Any]) throws {
        guard let defaultPixelHeaders = options[NetworkProtectionOptionKey.defaultPixelHeaders] as? [String: String] else {
            os_log("🔵 Pixel options are not set", log: .networkProtection)
            throw ConfigurationError.missingPixelHeaders
        }

        setupPixels(defaultHeaders: defaultPixelHeaders)
    }

    // MARK: - Start/Stop Tunnel

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        super.stopTunnel(with: reason) {
            Task {
                completionHandler()

                // From what I'm seeing in my tests the next call to start the tunnel is MUCH
                // less likely to fail if we force this extension to exit when the tunnel is killed.
                //
                // Ref: https://app.asana.com/0/72649045549333/1204668639086684/f
                //
                exit(EXIT_SUCCESS)
            }
        }
    }

    override func cancelTunnelWithError(_ error: Error?) {
        Task {
            super.cancelTunnelWithError(error)
            exit(EXIT_SUCCESS)
        }
    }

    // MARK: - Pixels

    private func setupPixels(defaultHeaders: [String: String]) {
        let dryRun: Bool
#if DEBUG
        dryRun = true
#else
        dryRun = false
#endif

        Pixel.setUp(dryRun: dryRun,
                    appVersion: AppVersion.shared.versionNumber,
                    defaultHeaders: defaultHeaders,
                    log: .networkProtectionPixel) { (pixelName: String, headers: [String: String], parameters: [String: String], _, _, onComplete: @escaping (Error?) -> Void) in

            let url = URL.pixelUrl(forPixelNamed: pixelName)
            let apiHeaders = APIRequest.Headers(additionalHeaders: headers) // workaround - Pixel class should really handle APIRequest.Headers by itself
            let configuration = APIRequest.Configuration(url: url, method: .get, queryParameters: parameters, headers: apiHeaders)
            let request = APIRequest(configuration: configuration)

            request.fetch { _, error in
                onComplete(error)
            }
        }
    }

}
