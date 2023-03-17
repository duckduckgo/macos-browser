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
}

final class DefaultNetworkProtectionProvider: NetworkProtectionProvider {

    // MARK: - Errors & Logging

    enum QuickConfigLoadingError: Error {
        case quickConfigFilePathEnvVarMissing
    }

    /// The logger that this object will use for errors that are handled by this class.
    ///
    private let logger: NetworkProtectionLogger

    /// Stores the last controller error for the purpose of updating the UI as needed..
    ///
    private let controllerErrorStore = NetworkProtectionControllerErrorStore()

    // MARK: - Notifications & Observers

    /// The notification center to use to observe tunnel change notifications.
    ///
    private let notificationCenter: NotificationCenter

    /// The observer token for VPN configuration changes,
    ///
    private var configChangeObserverToken: NSObjectProtocol?

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

    static func activeSession() async throws -> NETunnelProviderSession? {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()

        guard let manager = managers.first else {
            // No active connection, this is acceptable
            return nil
        }

        guard let session = manager.connection as? NETunnelProviderSession else {
            // The active connection is not running, so there's no session, this is acceptable
            return nil
        }

        return session
    }

    // MARK: - Initialization & Deinitialization

    convenience init() {
        self.init(notificationCenter: .default,
                  logger: DefaultNetworkProtectionLogger())
    }

    /// Default initializer
    ///
    /// - Parameters:
    ///         - notificationCenter: (meant for testing) the notification center that this object will use.
    ///         - logger: (meant for testing) the logger that this object will use.
    ///
    init(notificationCenter: NotificationCenter,
         logger: NetworkProtectionLogger) {

        self.logger = logger
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
        if tunnelManager.localizedDescription == nil {
            tunnelManager.localizedDescription = UserText.networkProtectionTunnelName
        }

        if !tunnelManager.isEnabled {
            tunnelManager.isEnabled = true
        }

        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.serverAddress = "127.0.0.1" // Dummy address... the NetP service will take care of grabbing a real server
        protocolConfiguration.providerBundleIdentifier = NetworkProtectionBundle.extensionBundle().bundleIdentifier
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

    // MARK: - Ensure things are working

#if NETP_SYSTEM_EXTENSION
    /// - Returns: `true` if the system extension and the background agent were activated successfully
    ///
    private func ensureSystemExtensionAndAgentAreActivated() async throws -> Bool {
        #if DEBUG
        try? await NetworkProtectionAgentManager.current.reset()
        #else

        NetworkProtectionAgentManager.current.enable()
        #endif

        if case .willActivateAfterReboot = try await SystemExtensionManager.shared.activate(waitingForUserApprovalHandler: { [weak self] in
            self?.controllerErrorStore.lastErrorMessage = "Go to Security & Privacy in System Settings to allow Network Protection to activate"
        }) {
            controllerErrorStore.lastErrorMessage = "Please reboot to activate Network Protection"
            return false
        }

        return true
    }
#endif

    // MARK: - Starting & Stopping the VPN

    /// Starts the VPN connection used for Network Protection
    ///
    func start() async throws {
#if NETP_SYSTEM_EXTENSION
        guard try await ensureSystemExtensionAndAgentAreActivated() else {
            return
        }
#endif

        controllerErrorStore.lastErrorMessage = nil
        let tunnelManager: NETunnelProviderManager

        do {
            tunnelManager = try await loadOrMakeTunnelManager()
        } catch {
            controllerErrorStore.lastErrorMessage = error.localizedDescription
            throw error
        }

        switch tunnelManager.connection.status {
        case .invalid:
            reloadTunnelManager()
            try await start()
        case .connected:
            // Intentional no-op
            break
        default:
            var options = [String: NSObject]()

            if let selectedServerName = NetworkProtectionSelectedServerUserDefaultsStore().selectedServer.stringValue {
                options["selectedServer"] = selectedServerName as NSString
            }

            do {
                try tunnelManager.connection.startVPNTunnel(options: options)
            } catch {
                controllerErrorStore.lastErrorMessage = error.localizedDescription
                throw error
            }
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
                    os_log("Status was reset in the extension", log: .networkProtection)
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

#if NETP_SYSTEM_EXTENSION
            try? await NetworkProtectionAgentManager.current.reset()
#endif
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
