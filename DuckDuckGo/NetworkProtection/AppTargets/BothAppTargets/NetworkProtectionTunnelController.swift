//
//  NetworkProtectionTunnelController.swift
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

#if NETWORK_PROTECTION

import Foundation
import Combine
import SwiftUI
import Common
import NetworkExtension
import NetworkProtection
import SystemExtensions
import Networking

typealias NetworkProtectionStatusChangeHandler = (NetworkProtection.ConnectionStatus) -> Void
typealias NetworkProtectionConfigChangeHandler = () -> Void

final class NetworkProtectionTunnelController: NetworkProtection.TunnelController {

    // MARK: - Debug Helpers

    /// Debug simulation options to aid with testing NetP.
    ///
    /// This is static because we want these options to be shared across all instances of `NetworkProtectionProvider`.
    ///
    static var simulationOptions = NetworkProtectionSimulationOptions()

    /// The logger that this object will use for errors that are handled by this class.
    ///
    private let logger: NetworkProtectionLogger

    /// Stores the last controller error for the purpose of updating the UI as needed..
    ///
    private let controllerErrorStore = NetworkProtectionControllerErrorStore()

    // MARK: - VPN Tunnel & Configuration

    /// Auth token store
    private let tokenStore: NetworkProtectionTokenStore

    // MARK: - Login Items

    private let loginItemsManager = NetworkProtectionLoginItemsManager()

    // MARK: - Debug Options Support

    private let debugUtilities = NetworkProtectionDebugUtilities()

    // MARK: - Connection Status

    private let statusTransitionAwaiter = ConnectionStatusTransitionAwaiter(statusObserver: ConnectionStatusObserverThroughSession(platformNotificationCenter: NSWorkspace.shared.notificationCenter, platformDidWakeNotification: NSWorkspace.didWakeNotification), transitionTimeout: .seconds(4))

    // MARK: - Tunnel Manager

    /// The tunnel manager: will try to load if it its not loaded yet, but if one can't be loaded from preferences,
    /// a new one will NOT be created.  This is useful for querying the connection state and information without triggering
    /// a VPN-access popup to the user.
    ///
    private func loadTunnelManager() async -> NETunnelProviderManager? {
        try? await NETunnelProviderManager.loadAllFromPreferences().first
    }

    private func loadOrMakeTunnelManager() async throws -> NETunnelProviderManager {
        guard let tunnelManager = await loadTunnelManager() else {
            let tunnelManager = NETunnelProviderManager()
            try await setupAndSave(tunnelManager)
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

    // MARK: - Initialization

    /// Default initializer
    ///
    /// - Parameters:
    ///         - notificationCenter: (meant for testing) the notification center that this object will use.
    ///         - logger: (meant for testing) the logger that this object will use.
    ///
    init(notificationCenter: NotificationCenter = .default,
         tokenStore: NetworkProtectionTokenStore = NetworkProtectionKeychainTokenStore(),
         logger: NetworkProtectionLogger = DefaultNetworkProtectionLogger()) {

        self.logger = logger
        self.tokenStore = tokenStore

        Task {
            // Make sure the tunnel is loaded
            _ = await loadTunnelManager()
        }
    }

    // MARK: - VPN Config Change Notifications

    private var configChangeCancellable: AnyCancellable?

    private func startObservingVPNConfigChanges(notificationCenter: NotificationCenter) {
        configChangeCancellable = notificationCenter.publisher(for: .NEVPNConfigurationChange)
            .sink(receiveValue: { _ in
                Task {
                    // As crazy as it seems, this calls fixes an issue with tunnel session
                    // having a nil manager, when in theory it should never be `nil`.  I don't know
                    // why this happens, but I believe it may be because we run multiple instances
                    // of our App controlling the session, and if any modification is made to the
                    // session, other instances should reload it from preferences.
                    //
                    // For better or worse, this line ensures the session's manager is not nil.
                    //
                    try? await NETunnelProviderManager.loadAllFromPreferences()
                }
            })
    }

    // MARK: - Tunnel Configuration

    /// Setups the tunnel manager if it's not set up already.
    ///
    private func setup(_ tunnelManager: NETunnelProviderManager) async throws {
        if tunnelManager.localizedDescription == nil {
            tunnelManager.localizedDescription = UserText.networkProtectionTunnelName
        }

        if !tunnelManager.isEnabled {
            tunnelManager.isEnabled = true
        }

        tunnelManager.protocolConfiguration = {
            let protocolConfiguration = NETunnelProviderProtocol()
            protocolConfiguration.serverAddress = "127.0.0.1" // Dummy address... the NetP service will take care of grabbing a real server
            protocolConfiguration.providerBundleIdentifier = NetworkProtectionBundle.extensionBundle().bundleIdentifier
            protocolConfiguration.providerConfiguration = [
                NetworkProtectionOptionKey.defaultPixelHeaders.rawValue: APIRequest.Headers().httpHeaders
            ]

            // always-on
            protocolConfiguration.disconnectOnSleep = false

            return protocolConfiguration
        }()

        // reconnect on reboot
        tunnelManager.onDemandRules = [NEOnDemandRuleConnect(interfaceType: .any)]
    }

    // MARK: - Connection Status Querying

    /// Queries Network Protection to know if its VPN is connected.
    ///
    /// - Returns: `true` if the VPN is connected, connecting or reasserting, and `false` otherwise.
    ///
    func isConnected() async -> Bool {
        guard let tunnelManager = await loadTunnelManager() else {
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
    private func ensureSystemExtensionIsActivated() async throws -> Bool {
        var activated = false

        for try await event in SystemExtensionManager().activate() {
            switch event {
            case .waitingForUserApproval:
                self.controllerErrorStore.lastErrorMessage = UserText.networkProtectionSystemSettings
            case .activated:
                self.controllerErrorStore.lastErrorMessage = nil
                activated = true
            case .willActivateAfterReboot:
                controllerErrorStore.lastErrorMessage = UserText.networkProtectionPleaseReboot
            }
        }

        try? await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)
        return activated
    }
#endif

    // MARK: - Starting & Stopping the VPN

    enum StartError: LocalizedError {
        case connectionStatusInvalid
        case simulateControllerFailureError

        var errorDescription: String? {
            switch self {
            case .connectionStatusInvalid:
                #if DEBUG
                return "[DEBUG] Connection status invalid"
                #else
                return "An unexpected error occurred, please try again"
                #endif
            case .simulateControllerFailureError:
                return "Simulated a controller error as requested"
            }
        }
    }

    /// Starts the VPN connection used for Network Protection
    ///
    func start() async {
        await start(enableLoginItems: true)
    }

    func start(enableLoginItems: Bool) async {
        controllerErrorStore.lastErrorMessage = nil

        if enableLoginItems {
            loginItemsManager.enableLoginItems()
        }

        do {
#if NETP_SYSTEM_EXTENSION
            guard try await ensureSystemExtensionIsActivated() else {
                return
            }
#endif

            let tunnelManager = try await loadOrMakeTunnelManager()

            switch tunnelManager.connection.status {
            case .invalid:
                throw StartError.connectionStatusInvalid
            case .connected:
                // Intentional no-op
                break
            default:
                try await start(tunnelManager)
            }
        } catch OSSystemExtensionError.requestSuperseded {
            await stop()
            // Even if the installation request is superseded we want to show the message that tells the user
            // to go to System Settings to allow the extension
            controllerErrorStore.lastErrorMessage = UserText.networkProtectionSystemSettings
        } catch {
            await stop()
            controllerErrorStore.lastErrorMessage = error.localizedDescription
        }
    }

    private func start(_ tunnelManager: NETunnelProviderManager) async throws {
        var options = [String: NSObject]()

        options["activationAttemptId"] = UUID().uuidString as NSString
        options["authToken"] = try tokenStore.fetchToken() as NSString?
        options["selectedServer"] = debugUtilities.selectedServerName() as NSString?
        options["keyValidity"] = debugUtilities.registrationKeyValidity().map(String.init(describing:)) as NSString?

        if Self.simulationOptions.isEnabled(.tunnelFailure) {
            Self.simulationOptions.setEnabled(false, option: .tunnelFailure)
            options["tunnelFailureSimulation"] = "true" as NSString
        }

        if Self.simulationOptions.isEnabled(.controllerFailure) {
            Self.simulationOptions.setEnabled(false, option: .controllerFailure)
            throw StartError.simulateControllerFailureError
        }

        try tunnelManager.connection.startVPNTunnel(options: options)
        try await statusTransitionAwaiter.waitUntilConnectionStarted()
    }

    /// Stops the VPN connection used for Network Protection
    ///
    func stop() async {
        guard let tunnelManager = await loadTunnelManager() else {
            return
        }

        do {
            try await stop(tunnelManager: tunnelManager)
        } catch {
            controllerErrorStore.lastErrorMessage = error.localizedDescription
        }
    }

    func stop(tunnelManager: NEVPNManager) async throws {
        // disable reconnect on demand if requested to stop
        if tunnelManager.isOnDemandEnabled {
            tunnelManager.isOnDemandEnabled = false
            try? await tunnelManager.saveToPreferences()
        }

        switch tunnelManager.connection.status {
        case .connected, .connecting, .reasserting:
            tunnelManager.connection.stopVPNTunnel()
            try await statusTransitionAwaiter.waitUntilConnectionStopped()
        default:
            break
        }
    }

    // MARK: - On Demand

    func enableOnDemand() async throws {
        let manager = try await loadOrMakeTunnelManager()

        manager.isOnDemandEnabled = true
        try await manager.saveToPreferences()
    }
}

#endif
