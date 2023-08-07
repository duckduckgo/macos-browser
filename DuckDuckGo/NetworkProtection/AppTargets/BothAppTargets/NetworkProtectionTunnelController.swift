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

@available(macOS 11.4, *)
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

    /// Enable On-Demand VPN activation rule
    @MainActor
    @UserDefaultsWrapper(key: .networkProtectionOnDemandActivation, defaultValue: NetworkProtectionUserDefaultsConstants.onDemandActivation)
    private(set) var isOnDemandEnabled: Bool

    /// Kill Switch: Enable enforceRoutes flag
    ///
    /// Applies enforceRoutes setting, sets up excludedRoutes in MacPacketTunnelProvider and disables disconnect on failure
    @MainActor
    @UserDefaultsWrapper(key: .networkProtectionShouldEnforceRoutes, defaultValue: NetworkProtectionUserDefaultsConstants.shouldEnforceRoutes)
    private(set) var shouldEnforceRoutes: Bool

    @MainActor
    @UserDefaultsWrapper(key: .networkProtectionShouldIncludeAllNetworks, defaultValue: NetworkProtectionUserDefaultsConstants.shouldIncludeAllNetworks)
    private(set) var shouldIncludeAllNetworks

    /// Test setting to exclude duckduckgo route from VPN
    @MainActor
    @UserDefaultsWrapper(key: .networkProtectionExcludedRoutes, defaultValue: [:])
    private(set) var excludedRoutesPreferences: [String: Bool]

    @MainActor
    @UserDefaultsWrapper(key: .networkProtectionShouldExcludeLocalRoutes, defaultValue: NetworkProtectionUserDefaultsConstants.shouldExcludeLocalRoutes)
    private(set) var shouldExcludeLocalRoutes: Bool

    /// When enabled VPN connection will be automatically initiated by DuckDuckGoAgentAppDelegate on launch even if disconnected manually (Always On rule disabled)
    @MainActor
    @UserDefaultsWrapper(key: .networkProtectionConnectOnLogIn, defaultValue: NetworkProtectionUserDefaultsConstants.shouldConnectOnLogIn, defaults: .shared)
    private(set) var shouldAutoConnectOnLogIn: Bool

    @MainActor
    @UserDefaultsWrapper(key: .networkProtectionConnectionTesterEnabled, defaultValue: NetworkProtectionUserDefaultsConstants.isConnectionTesterEnabled, defaults: .shared)
    private(set) var isConnectionTesterEnabled: Bool

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
        let tunnelManager = await loadTunnelManager() ?? NETunnelProviderManager()

        try await setupAndSave(tunnelManager)
        return tunnelManager
    }

    private func setupAndSave(_ tunnelManager: NETunnelProviderManager, isOnDemandEnabled: Bool? = nil) async throws {
        await setup(tunnelManager, isOnDemandEnabled: isOnDemandEnabled)
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
    }

    // MARK: - Tunnel Configuration

    /// Setups the tunnel manager if it's not set up already.
    ///
    @MainActor
    private func setup(_ tunnelManager: NETunnelProviderManager, isOnDemandEnabled: Bool?) {
        if tunnelManager.localizedDescription == nil {
            tunnelManager.localizedDescription = UserText.networkProtectionTunnelName
        }

        if !tunnelManager.isEnabled {
            tunnelManager.isEnabled = true
        }

        tunnelManager.protocolConfiguration = {
            let protocolConfiguration = tunnelManager.protocolConfiguration as? NETunnelProviderProtocol ?? NETunnelProviderProtocol()
            protocolConfiguration.serverAddress = "127.0.0.1" // Dummy address... the NetP service will take care of grabbing a real server
            protocolConfiguration.providerBundleIdentifier = NetworkProtectionBundle.extensionBundle().bundleIdentifier
            protocolConfiguration.providerConfiguration = [
                NetworkProtectionOptionKey.defaultPixelHeaders: APIRequest.Headers().httpHeaders,
                NetworkProtectionOptionKey.excludedRoutes: excludedRoutes().map(\.stringRepresentation) as NSArray,
                NetworkProtectionOptionKey.includedRoutes: includedRoutes().map(\.stringRepresentation) as NSArray,
                NetworkProtectionOptionKey.connectionTesterEnabled: NSNumber(value: isConnectionTesterEnabled)
            ]

            // always-on
            protocolConfiguration.disconnectOnSleep = false

            // kill switch
            protocolConfiguration.enforceRoutes = shouldEnforceRoutes
            // this setting breaks Connection Tester
            protocolConfiguration.includeAllNetworks = shouldIncludeAllNetworks

            protocolConfiguration.excludeLocalNetworks = shouldExcludeLocalRoutes

            return protocolConfiguration
        }()

        // auto-connect on any network request
        if isOnDemandEnabled ?? (self.isOnDemandEnabled || self.shouldEnforceRoutes) {
            tunnelManager.onDemandRules = [NEOnDemandRuleConnect(interfaceType: .any)]
            tunnelManager.isOnDemandEnabled = true
        } else {
            tunnelManager.isOnDemandEnabled = false
        }
    }

    // MARK: - Connection Status Querying

    /// Queries Network Protection to know if its VPN is connected.
    ///
    /// - Returns: `true` if the VPN is connected, connecting or reasserting, and `false` otherwise.
    ///
    var isConnected: Bool {
        get async {
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

        options[NetworkProtectionOptionKey.activationAttemptId] = UUID().uuidString as NSString
        options[NetworkProtectionOptionKey.authToken] = try tokenStore.fetchToken() as NSString?
        options[NetworkProtectionOptionKey.selectedServer] = debugUtilities.selectedServerName() as NSString?
        options[NetworkProtectionOptionKey.keyValidity] = debugUtilities.registrationKeyValidity.map(String.init(describing:)) as NSString?

        if Self.simulationOptions.isEnabled(.tunnelFailure) {
            Self.simulationOptions.setEnabled(false, option: .tunnelFailure)
            options[NetworkProtectionOptionKey.tunnelFailureSimulation] = NetworkProtectionOptionValue.true
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

    func stop(tunnelManager: NETunnelProviderManager) async throws {
        // disable reconnect on demand if requested to stop
        try? await disableOnDemand(tunnelManager: tunnelManager)

        switch tunnelManager.connection.status {
        case .connected, .connecting, .reasserting:
            tunnelManager.connection.stopVPNTunnel()
            try await statusTransitionAwaiter.waitUntilConnectionStopped()
        default:
            break
        }
    }

    // MARK: - On Demand & Kill Switch

    @MainActor
    func enableOnDemandRequestedByExtension() async throws {
        guard isOnDemandEnabled || shouldEnforceRoutes else {
            os_log("On-demand requested by Extension: declining, disabled", log: .networkProtection)
            return
        }

        try await self.enableOnDemand()
    }

    @MainActor
    func enableOnDemand() async throws {
        isOnDemandEnabled = true

        // calls setupAndSave where configuration is done
        _=try await loadOrMakeTunnelManager()
    }

    @MainActor
    func disableOnDemand(tunnelManager: NETunnelProviderManager? = nil) async throws {
        // disable on-demand flag on disconnect to prevent respawn but keep the defaults value
        guard let tunnelManager = await loadTunnelManager(),
              tunnelManager.isOnDemandEnabled else { return }

        try await setupAndSave(tunnelManager, isOnDemandEnabled: false)
    }

    @MainActor
    func enableEnforceRoutes() async throws {
        isOnDemandEnabled = true
        shouldEnforceRoutes = true

        // calls setupAndSave where configuration is done
        _=try await loadOrMakeTunnelManager()
    }

    @MainActor
    func disableEnforceRoutes() async throws {
        shouldEnforceRoutes = false

        guard let tunnelManager = await loadTunnelManager(),
              tunnelManager.protocolConfiguration?.enforceRoutes == true else { return }

        try await setupAndSave(tunnelManager)
    }

    @MainActor
    func enableIncludeAllNetworks() async throws {
        isOnDemandEnabled = true
        shouldIncludeAllNetworks = true

        // calls setupAndSave where configuration is done
        _=try await loadOrMakeTunnelManager()
    }

    @MainActor
    func disableIncludeAllNetworks() async throws {
        shouldIncludeAllNetworks = false

        guard let tunnelManager = await loadTunnelManager(),
              tunnelManager.protocolConfiguration?.includeAllNetworks == true else { return }

        try await setupAndSave(tunnelManager)
    }

    @MainActor
    func toggleOnDemandEnabled() {
        isOnDemandEnabled.toggle()
        if !isOnDemandEnabled {
            shouldEnforceRoutes = false
        }

        // update configuration if connected
        Task { [isOnDemandEnabled] in
            guard await isConnected else { return }

            if isOnDemandEnabled {
                try await enableOnDemand()
            } else {
                try await disableOnDemand()
            }
        }
    }

    @MainActor
    func toggleShouldEnforceRoutes() {
        shouldEnforceRoutes.toggle()

        // update configuration if connected
        Task { [shouldEnforceRoutes] in
            guard await isConnected else { return }

            if shouldEnforceRoutes {
                try await enableEnforceRoutes()
            } else {
                try await disableEnforceRoutes()
            }
        }
    }

    @MainActor
    func toggleShouldIncludeAllNetworks() {
        shouldIncludeAllNetworks.toggle()

        // update configuration if connected
        Task { [shouldIncludeAllNetworks] in
            guard await isConnected else { return }

            if shouldIncludeAllNetworks {
                try await enableIncludeAllNetworks()
            } else {
                try await disableIncludeAllNetworks()
            }
        }
    }

    // TO BE Refactored when the Exclusion List is added
    enum ExclusionListItem {
        case section(String)
        case exclusion(range: NetworkProtection.IPAddressRange, description: String? = nil, `default`: Bool)
    }
    static let exclusionList: [ExclusionListItem] = [
        .section("IPv4 Local Routes"),

        .exclusion(range: "10.0.0.0/8"     /* 255.0.0.0 */, description: "disabled for enforceRoutes", default: true),
        .exclusion(range: "172.16.0.0/12"  /* 255.240.0.0 */, default: true),
        .exclusion(range: "192.168.0.0/16" /* 255.255.0.0 */, default: true),
        .exclusion(range: "169.254.0.0/16" /* 255.255.0.0 */, description: "Link-local", default: true),
        .exclusion(range: "127.0.0.0/8"    /* 255.0.0.0 */, description: "Loopback", default: true),
        .exclusion(range: "224.0.0.0/4"    /* 240.0.0.0 (corrected subnet mask) */, description: "Multicast", default: true),
        .exclusion(range: "100.64.0.0/16"  /* 255.255.0.0 */, description: "Shared Address Space", default: true),

        .section("IPv6 Local Routes"),
        .exclusion(range: "fe80::/10", description: "link local", default: false),
        .exclusion(range: "ff00::/8", description: "multicast", default: false),
        .exclusion(range: "fc00::/7", description: "local unicast", default: false),
        .exclusion(range: "::1/128", description: "loopback", default: false),

        .section("duckduckgo.com"),
        .exclusion(range: "52.142.124.215/32", default: false),
        .exclusion(range: "52.250.42.157/32", default: false),
        .exclusion(range: "40.114.177.156/32", default: false),
    ]

    @MainActor
    private func excludedRoutes() -> [NetworkProtection.IPAddressRange] {
        Self.exclusionList.compactMap { [excludedRoutesPreferences] item -> NetworkProtection.IPAddressRange? in
            guard case .exclusion(range: let range, description: _, default: let defaultValue) = item,
                  excludedRoutesPreferences[range.stringRepresentation, default: defaultValue] == true
            else { return nil }
            // TO BE fixed:
            // when 10.11.12.1 DNS is used 10.0.0.0/8 should be included (not excluded)
            // but marking 10.11.12.1 as an Included Route breaks tunnel (probably these routes are conflicting)
            if shouldEnforceRoutes && range == "10.0.0.0/8" {
                return nil
            }

            return range
        }
    }

    /// extra Included Routes appended to 0.0.0.0, ::/0 (peers) and interface.addresses
    @MainActor
    private func includedRoutes() -> [NetworkProtection.IPAddressRange] {
        []
    }

    @MainActor
    func toggleShouldExcludeLocalRoutes() {
        shouldExcludeLocalRoutes.toggle()
        updateRoutes()
    }

    @MainActor
    func setExcludedRoute(_ route: String, enabled: Bool) {
        excludedRoutesPreferences[route] = enabled
        updateRoutes()
    }

    @MainActor
    func isExcludedRouteEnabled(_ route: String) -> Bool {
        guard let range = IPAddressRange(from: route),
              let exclusionListItem = Self.exclusionList.first(where: {
                  if case .exclusion(range: range, description: _, default: _) = $0 { return true }
                  return false
              }),
              case .exclusion(range: _, description: _, default: let defaultValue) = exclusionListItem else {

            assertionFailure("Invalid route \(route)")
            return false
        }
        // TO BE fixed: see excludedRoutes()
        if shouldEnforceRoutes && route == "10.0.0.0/8" {
            return false
        }
        return excludedRoutesPreferences[route, default: defaultValue]
    }

    func updateRoutes() {
        Task {
            guard let activeSession = try await ConnectionSessionUtilities.activeSession() else { return }

            try await activeSession.sendProviderMessage(.setIncludedRoutes(includedRoutes()))
            try await activeSession.sendProviderMessage(.setExcludedRoutes(excludedRoutes()))
        }
    }

    @MainActor
    func toggleShouldAutoConnectOnLogIn() {
        shouldAutoConnectOnLogIn.toggle()
    }

    @MainActor
    func toggleConnectionTesterEnabled() {
        isConnectionTesterEnabled.toggle()
    }

    @MainActor
    private func simulateTunnelFailure() async throws {
        Self.simulationOptions.setEnabled(true, option: .tunnelFailure)

        guard await isConnected,
              let activeSession = try await ConnectionSessionUtilities.activeSession() else { return }

        let errorMessage: ExtensionMessageString? = try await activeSession.sendProviderMessage(.simulateTunnelFailure)
        if let errorMessage {
            throw TunnelFailureError(errorDescription: errorMessage.value)
        }
    }

    struct TunnelFailureError: LocalizedError {
        let errorDescription: String?
    }

    @MainActor
    func toggleShouldSimulateTunnelFailure() async throws {
        if Self.simulationOptions.isEnabled(.tunnelFailure) {
            Self.simulationOptions.setEnabled(false, option: .tunnelFailure)
        } else {
            try await simulateTunnelFailure()
        }
    }

}

#endif
