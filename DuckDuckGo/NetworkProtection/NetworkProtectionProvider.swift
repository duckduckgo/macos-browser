//
//  NSImage+NetworkProtection.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import SwiftUI
import OSLog
import BrowserServicesKit
import NetworkExtension
import NetworkProtection
import SystemExtensions
import Common

enum NetworkProtectionConnectionStatus {
    case notConfigured
    case disconnected
    case disconnecting
    case connected(connectedDate: Date)
    case connecting
    case reasserting
    case unknown
}

typealias NetworkProtectionStatusChangeHandler = (NetworkProtectionConnectionStatus) -> Void
typealias NetworkProtectionConfigChangeHandler = () -> Void

protocol NetworkProtectionProvider {

    // MARK: - Polling Connection State

    /// Queries Network Protection to know if its VPN is connected.
    ///
    /// - Returns: `true` if the VPN is connected, connecting or reasserting, and `false` otherwise.
    ///
    func isConnected() async -> Bool

    // MARK: - Starting & Stopping the VPN

    /// Starts the VPN connection used for Network Protection
    ///
    func start() async throws

    /// Stops the VPN connection used for Network Protection
    ///
    func stop() async throws

    // MARK: - Config & Status Change Publishers

    var configChangePublisher: CurrentValueSubject<Void, Never> { get }
}

final class DefaultNetworkProtectionProvider: NetworkProtectionProvider {

    // MARK: - Errors & Logging

    enum QuickConfigLoadingError: Error {
        case quickConfigFilePathEnvVarMissing
    }

    /// The logger that this object will use for errors that are handled by this class.
    ///
    private let logger: NetworkProtectionLogger

    /// Handles registration of the current device with the Network Protection backend.
    /// The manager is also responsible to maintaining the current known list of backend servers, and allowing the user to pick which one they connect to.
    /// 
    private let deviceManager: NetworkProtectionDeviceManagement

    // MARK: - Notifications & Observers

    /// The notification center to use to observe tunnel change notifications.
    ///
    private let notificationCenter: NotificationCenter

    /// The observer token for VPN configuration changes,
    ///
    private var configChangeObserverToken: NSObjectProtocol?

    let configChangePublisher = CurrentValueSubject<Void, Never>(())

    // MARK: - Bundle Identifiers
    
    var extensionBundleIdentifier: String {
        NetworkProtectionBundle.extensionBundle().bundleIdentifier!
    }
    
    // MARK: - VPN Tunnel & Configuration

    /// The environment variable that holds the path to the WG quick configuration file that will be used for the tunnel.
    ///
    static let quickConfigFilePathEnvironmentVariable = "NETP_QUICK_CONFIG_FILE_PATH"

    /// The path of the WG quick configuration file that is used when the environment variable is not present.
    static let defaultConfigFilePath = "~/NetworkProtection.conf"

    /// The actual storage for our tunnel manager.
    ///
    private var internalTunnelManager: NETunnelProviderManager?

    /// The tunnel manager: will try to load if it its not loaded yet, but if one can't be loaded from preferences,
    /// a new one will not be created.  This is useful for querying the connection state and information without triggering
    /// a VPN-access popup to the user.
    ///
    private var tunnelManager: NETunnelProviderManager? {
        get async {
            guard let tunnelManager = internalTunnelManager else {
                let tunnelManager = await loadTunnelManager()
                internalTunnelManager = tunnelManager
                return tunnelManager
            }

            return tunnelManager
        }
    }

    private func loadTunnelManager() async -> NETunnelProviderManager? {
        try? await NETunnelProviderManager.loadAllFromPreferences().first
    }

    private func loadOrMakeTunnelManager() async throws -> NETunnelProviderManager {
        guard let tunnelManager = await tunnelManager else {
            let tunnelManager = NETunnelProviderManager()
            try await setupAndSave(tunnelManager)
            internalTunnelManager = tunnelManager
            return tunnelManager
        }

        try await setupAndSave(tunnelManager)
        return tunnelManager
    }

    private func setupAndSave(_ tunnelManager: NETunnelProviderManager) async throws {
        try await setup(tunnelManager)
        try await tunnelManager.saveToPreferences()
        try await tunnelManager.loadFromPreferences()
    }
    
    enum ActiveSessionError: Error {
        case couldNotLoadPreferences(error: Error)
        case activeConnectionHasNoSession
    }
    
    static func activeSession() async throws -> NETunnelProviderSession? {
        try await withCheckedThrowingContinuation { continuation in
            NETunnelProviderManager.loadAllFromPreferences { managers, error in
                if let error = error {
                    continuation.resume(throwing: ActiveSessionError.couldNotLoadPreferences(error: error))
                    return
                }
                
                Task {
                    guard let manager = managers?.first(where: { manager in
                        switch manager.connection.status {
                        case .connected, .connecting, .reasserting:
                            return true
                        default:
                            return false
                        }
                    }) else {
                        // No active connection, this is acceptable
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    guard let session = manager.connection as? NETunnelProviderSession else {
                        continuation.resume(returning: nil)
                        return
                    }

                    continuation.resume(returning: session)
                }
            }
        }
    }

    // MARK: - Initialization & Deinitialization

    convenience init() {
        let keychainStore = NetworkProtectionKeychainStore(useSystemKeychain: NetworkProtectionBundle.usesSystemKeychain())
        let deviceManager = NetworkProtectionDeviceManager(keyStore: keychainStore,
                                                           errorEvents: Self.networkProtectionDebugEvents)
        
        self.init(notificationCenter: .default,
                  deviceManager: deviceManager,
                  logger: DefaultNetworkProtectionLogger())
    }

    /// Default initializer
    ///
    /// - Parameters:
    ///         - notificationCenter: (meant for testing) the notification center that this object will use.
    ///         - logger: (meant for testing) the logger that this object will use.
    ///
    init(notificationCenter: NotificationCenter,
         deviceManager: NetworkProtectionDeviceManagement,
         logger: NetworkProtectionLogger) {

        self.logger = logger
        self.deviceManager = deviceManager
        self.notificationCenter = notificationCenter

        startObservingNotifications()

        Task {
            // Make sure the tunnel is loaded
            _ = await tunnelManager
        }
    }

    deinit {
        stopObservingNotifications()
    }

    // MARK: - Observing VPN Notifications

    private func startObservingNotifications() {
        startObservingVPNConfigChanges()
    }

    private func startObservingVPNConfigChanges() {
        guard configChangeObserverToken == nil else {
            return
        }

        configChangeObserverToken = notificationCenter.addObserver(forName: .NEVPNConfigurationChange, object: nil, queue: nil) { [weak self] notification in
            guard let self = self,
                let manager = notification.object as? NETunnelProviderManager else {
                return
            }

            self.internalTunnelManager = manager
            self.configChangePublisher.send(())
        }
    }

    private func stopObservingNotifications() {
        stopObservingVPNConfigChanges()
    }

    private func stopObservingVPNConfigChanges() {
        guard let token = configChangeObserverToken else {
            return
        }

        notificationCenter.removeObserver(token)
        configChangeObserverToken = nil
    }

    // MARK: - Error Reporting

    static let networkProtectionDebugEvents: EventMapping<NetworkProtectionError>? = .init { event, _, _, _ in
        let domainEvent: Pixel.Event

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

        case .failedToFetchServerList:
            return
        case .failedToParseServerListResponse:
            domainEvent = .networkProtectionClientFailedToParseServerListResponse
        case .failedToEncodeRegisterKeyRequest:
            domainEvent = .networkProtectionClientFailedToEncodeRegisterKeyRequest
        case .failedToFetchRegisteredServers:
            return
        case .failedToParseRegisteredServersResponse:
            domainEvent = .networkProtectionClientFailedToParseRegisteredServersResponse
        case .serverListInconsistency:
            // - TODO: not sure what to do here
            return

        case .failedToEncodeServerList:
            domainEvent = .networkProtectionServerListStoreFailedToEncodeServerList
        case .failedToWriteServerList(let eventError):
            domainEvent = .networkProtectionServerListStoreFailedToWriteServerList(error: eventError)
        case .noServerListFound:
            return
        case .couldNotCreateServerListDirectory(let _):
            return
            
        case .failedToReadServerList(let eventError):
            domainEvent = .networkProtectionServerListStoreFailedToReadServerList(error: eventError)

        case .failedToCastKeychainValueToData(let field):
            domainEvent = .networkProtectionKeychainErrorFailedToCastKeychainValueToData(field: field)
        case .keychainReadError(let field, let status):
            domainEvent = .networkProtectionKeychainReadError(field: field, status: status)
        case .keychainWriteError(let field, let status):
            domainEvent = .networkProtectionKeychainWriteError(field: field, status: status)
        case .keychainDeleteError(let field, let status):
            domainEvent = .networkProtectionKeychainDeleteError(field: field, status: status)

        case .unhandledError(function: let function, line: let line, error: let error):
            domainEvent = .networkProtectionUnhandledError(function: function, line: line, error: error)
        }

        Pixel.fire(domainEvent, includeAppVersionParameter: true)
    }

    // MARK: - Notifications: Handling
    
    static let statusChangeQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
        
        return queue
    }()

    @objc private func resetExtensionNotification(_ notification: Notification) {
        os_log("Received reset extension notification", log: .networkProtection)
        
        Task { @MainActor in
            try? await stop()
            try? await internalTunnelManager?.removeFromPreferences()
        }
    }

    // MARK: - Tunnel Configuration

    /// Loads the tunnel configuration from the filesystem.
    ///
    private func loadTunnelConfiguration() throws -> TunnelConfiguration? {
        let resolvedDefaultPath = NSString(string: Self.defaultConfigFilePath).expandingTildeInPath

        if let quickConfigFile = ProcessInfo.processInfo.environment[Self.quickConfigFilePathEnvironmentVariable] {
            let quickConfig = try String(contentsOfFile: quickConfigFile)
            let configuration = try TunnelConfiguration(fromWgQuickConfig: quickConfig)
            configuration.name = "DuckDuckGo Network Protection Configuration"

            return configuration
        } else if let defaultQuickConfig = try? String(contentsOfFile: resolvedDefaultPath) {
            let configuration = try TunnelConfiguration(fromWgQuickConfig: defaultQuickConfig)
            configuration.name = "DuckDuckGo Network Protection Configuration"

            return configuration
        }

        return nil
    }

    /// Reloads the tunnel manager from preferences.
    ///
    private func reloadTunnelManager() {
        internalTunnelManager = nil
    }

    /// Setups the tunnel manager if it's not set up already.
    ///
    private func setup(_ tunnelManager: NETunnelProviderManager) async throws {
        // 1 - If configuration exists... let it through (but what if it's broken?  the service will take care of it)
        // 2 - If a configuration doesn't exist, fill in a dummy one (can this cause issues?)
        
        if tunnelManager.localizedDescription == nil {
            tunnelManager.localizedDescription = UserText.networkProtectionTunnelName
        }
        
        if !tunnelManager.isEnabled {
            tunnelManager.isEnabled = true
        }
        
        guard tunnelManager.protocolConfiguration == nil else {
            return
        }

        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.serverAddress = "127.0.0.1" // Dummy address... the NetP service will take care of grabbing a real server
        tunnelManager.protocolConfiguration = protocolConfiguration
    }

    // MARK: - Connection Status Querying

    /// Queries Network Protection to know if its VPN is connected.
    ///
    /// - Returns: `true` if the VPN is connected, connecting or reasserting, and `false` otherwise.
    ///
    func isConnected() async -> Bool {
        guard let tunnelManager = await tunnelManager else {
            return false
        }

        switch tunnelManager.connection.status {
        case .connected, .connecting, .reasserting:
            return true
        default:
            return false
        }
    }

    // MARK: - Starting & Stopping the VPN

    /// Starts the VPN connection used for Network Protection
    ///
    func start() async throws {
        NetworkProtectionAgentManager.current.enable()
        let tunnelManager = try await loadOrMakeTunnelManager()

        switch tunnelManager.connection.status {
        case .invalid:
            reloadTunnelManager()
            try await start()
        case .disconnected, .disconnecting:
            var options = [String: NSObject]()
            
            if let selectedServerName = NetworkProtectionSelectedServerUserDefaultsStore().selectedServer.stringValue {
                options["selectedServer"] = selectedServerName as NSString
            }
            
            try tunnelManager.connection.startVPNTunnel(options: options)
        default:
            // Intentional no-op
            break
        }
    }

    /// Stops the VPN connection used for Network Protection
    ///
    func stop() async throws {
        guard let tunnelManager = await tunnelManager else {
            return
        }

        switch tunnelManager.connection.status {
        case .connected, .connecting, .reasserting:
            tunnelManager.connection.stopVPNTunnel()
        default:
            break
        }
    }

    // MARK: - Debug commands for the extension
    
    private let selectedServerStore = NetworkProtectionSelectedServerUserDefaultsStore()

    static func resetAllState() {
        Task {
            if let activeSession = try? await activeSession() {
                try? activeSession.sendProviderMessage(Data([NetworkProtectionAppRequest.resetAllState.rawValue])) { _ in
                    os_log("🔵 Status was reset")
                }
            }
            
            // ☝️ Take care of resetting all state within the extension first, and wait half a second
            try? await Task.sleep(nanoseconds: 500 * NSEC_PER_MSEC)
            // 👇 And only afterwards turn off the tunnel and removing it from prefernces
            
            let tunnels = try? await NETunnelProviderManager.loadAllFromPreferences()
            
            if let tunnels = tunnels {
                for tunnel in tunnels {
                    tunnel.connection.stopVPNTunnel()
                    try? await tunnel.removeFromPreferences()
                }
            }
            
            try? await NetworkProtectionAgentManager.current.reset()
            NetworkProtectionKeychain.deleteReferences()
            NetworkProtectionSelectedServerUserDefaultsStore().reset()
        }
    }

    static func setSelectedServer(selectedServer: SelectedNetworkProtectionServer) {
        NetworkProtectionSelectedServerUserDefaultsStore().selectedServer = selectedServer
        
        let selectedServerName: String?
        
        if case .endpoint(let serverName) = selectedServer {
            selectedServerName = serverName
        } else {
            selectedServerName = nil
        }
        
        Task {
            guard let activeSession = try? await activeSession() else {
                return
            }
            
            var request = Data([NetworkProtectionAppRequest.setSelectedServer.rawValue])
             
            if let selectedServerName = selectedServerName {
                let serverNameData = selectedServerName.data(using: NetworkProtectionAppRequest.preferredStringEncoding)!
                request.append(serverNameData)
            }
            
            try? activeSession.sendProviderMessage(request)
        }
    }
    
    static func selectedServerName() -> String? {
        NetworkProtectionSelectedServerUserDefaultsStore().selectedServer.stringValue
    }
}
