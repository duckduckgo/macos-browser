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
import NetworkProtection
import NetworkExtension
import Common
import Networking
import PixelKit

final class MacPacketTunnelProvider: PacketTunnelProvider {

    private static func makeNotificationsPresenter() -> NetworkProtectionNotificationsPresenter {
#if NETP_SYSTEM_EXTENSION
        let ipcConnection = IPCConnection(log: .networkProtectionIPCLog, memoryManagementLog: .networkProtectionMemoryLog)
        ipcConnection.startListener()
        return NetworkProtectionIPCNotificationsPresenter(ipcConnection: ipcConnection)
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

    private let controllerErrorStore: NetworkProtectionTunnelErrorStore

    // MARK: - Error Reporting

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private static func networkProtectionDebugEvents(controllerErrorStore: NetworkProtectionTunnelErrorStore) -> EventMapping<NetworkProtectionError>? {
        return EventMapping { event, _, _, _ in
            let domainEvent: NetworkProtectionPixelEvent
#if DEBUG
            // Makes sure we see the assertion failure in the yellow NetP alert.
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
            case .noAuthTokenFound:
                domainEvent = .networkProtectionNoAuthTokenFoundError
            case .unhandledError(function: let function, line: let line, error: let error):
                domainEvent = .networkProtectionUnhandledError(function: function, line: line, error: error)
            }
            Pixel.fire(domainEvent, frequency: .dailyAndContinuous, includeAppVersionParameter: true)
        }
    }

    // MARK: - PacketTunnelProvider.Event reporting

    private static var packetTunnelProviderEvents: EventMapping<PacketTunnelProvider.Event> = .init { event, _, _, _ in
        switch event {
        case .userBecameActive:
            Pixel.fire(.networkProtectionActiveUser, frequency: .dailyOnly, includeAppVersionParameter: true)
        case .reportLatency(ms: let ms, server: let server, networkType: let networkType):
            Pixel.fire(.networkProtectionLatency(ms: ms, server: server, networkType: networkType), frequency: .standard)
        case .rekeyCompleted:
            Pixel.fire(.networkProtectionRekeyCompleted, frequency: .dailyAndContinuous, includeAppVersionParameter: true)
        }
    }

    // MARK: - Initialization

    init() {
        let distributedNotificationCenter = DistributedNotificationCenter.forType(.networkProtection)
        controllerErrorStore = NetworkProtectionTunnelErrorStore(notificationCenter: distributedNotificationCenter)
        super.init(notificationCenter: distributedNotificationCenter,
                   notificationsPresenter: Self.makeNotificationsPresenter(),
                   useSystemKeychain: NetworkProtectionBundle.usesSystemKeychain(),
                   debugEvents: Self.networkProtectionDebugEvents(controllerErrorStore: controllerErrorStore),
                   providerEvents: Self.packetTunnelProviderEvents,
                   appLauncher: AppLauncher(appBundleURL: .mainAppBundleURL))
    }

    // MARK: - NEPacketTunnelProvider

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        loadVendorOptions(from: tunnelProviderProtocol)
        super.startTunnel(options: options, completionHandler: completionHandler)
    }

    private var tunnelProviderProtocol: NETunnelProviderProtocol? {
        protocolConfiguration as? NETunnelProviderProtocol
    }

    private func loadVendorOptions(from provider: NETunnelProviderProtocol?) {
        guard let vendorOptions = provider?.providerConfiguration else {
            os_log("🔵 Provider is nil, or providerConfiguration is not set", log: .networkProtection)
            assertionFailure("Provider is nil, or providerConfiguration is not set")
            return
        }

        loadDefaultPixelHeaders(from: vendorOptions)
    }

    private func loadDefaultPixelHeaders(from options: [String: Any]) {
        guard let defaultPixelHeaders = options[NetworkProtectionOptionKey.defaultPixelHeaders.rawValue] as? [String: String] else {

            os_log("🔵 Pixel options are not set", log: .networkProtection)
            assertionFailure("Default pixel headers are not set")
            return
        }

        setupPixels(defaultHeaders: defaultPixelHeaders)
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
            let configuration = APIRequest.Configuration(url: url, method: .get, queryParameters: parameters, headers: headers)
            let request = APIRequest(configuration: configuration)

            request.fetch { _, error in
                onComplete(error)
            }
        }
    }
}
