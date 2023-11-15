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
import NetworkProtectionUI
import SystemExtensionManager
import SystemExtensions
import Networking
import PixelKit

typealias NetworkProtectionStatusChangeHandler = (NetworkProtection.ConnectionStatus) -> Void
typealias NetworkProtectionConfigChangeHandler = () -> Void

final class NetworkProtectionTunnelController: NetworkProtection.TunnelController {

    let settings: TunnelSettings

    // MARK: - Combine Cancellables

    private var cancellables = Set<AnyCancellable>()

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

    // MARK: - Debug Options Support

    private let networkExtensionBundleID: String
    private let networkExtensionController: NetworkExtensionController

    // MARK: - User Defaults

    /// Test setting to exclude duckduckgo route from VPN
    @MainActor
    @UserDefaultsWrapper(key: .networkProtectionExcludedRoutes, defaultValue: [:])
    private(set) var excludedRoutesPreferences: [String: Bool]

    @UserDefaultsWrapper(key: .networkProtectionOnboardingStatusRawValue, defaultValue: OnboardingStatus.default.rawValue, defaults: .shared)
    private(set) var onboardingStatusRawValue: OnboardingStatus.RawValue

    // MARK: - Connection Status

    private let statusTransitionAwaiter = ConnectionStatusTransitionAwaiter(statusObserver: ConnectionStatusObserverThroughSession(platformNotificationCenter: NSWorkspace.shared.notificationCenter, platformDidWakeNotification: NSWorkspace.didWakeNotification), transitionTimeout: .seconds(4))

    // MARK: - Tunnel Manager

    /// The tunnel manager: will try to load if it its not loaded yet, but if one can't be loaded from preferences,
    /// a new one will NOT be created.  This is useful for querying the connection state and information without triggering
    /// a VPN-access popup to the user.
    ///
    private func loadTunnelManager() async -> NETunnelProviderManager? {
        let tunnels = try? await NETunnelProviderManager.loadAllFromPreferences()
        return tunnels?.first {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == networkExtensionBundleID
        }
    }

    private func loadOrMakeTunnelManager() async throws -> NETunnelProviderManager {
        let tunnelManager = await loadTunnelManager() ?? NETunnelProviderManager()

        try await setupAndSave(tunnelManager)
        return tunnelManager
    }

    private func setupAndSave(_ tunnelManager: NETunnelProviderManager) async throws {
        await setup(tunnelManager)
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
    init(networkExtensionBundleID: String,
         networkExtensionController: NetworkExtensionController,
         settings: TunnelSettings,
         notificationCenter: NotificationCenter = .default,
         tokenStore: NetworkProtectionTokenStore = NetworkProtectionKeychainTokenStore(),
         logger: NetworkProtectionLogger = DefaultNetworkProtectionLogger()) {

        self.logger = logger
        self.networkExtensionBundleID = networkExtensionBundleID
        self.networkExtensionController = networkExtensionController
        self.settings = settings
        self.tokenStore = tokenStore

        subscribeToSettingsChanges()
    }

    // MARK: - Tunnel Settings

    private func subscribeToSettingsChanges() {
        settings.changePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                guard let self else { return }

                Task {
                    // Offer the extension a chance to handle the settings change
                    try? await self.relaySettingsChange(change)

                    // Handle the settings change right in the controller
                    try? await self.handleSettingsChange(change)
                }
            }
            .store(in: &cancellables)
    }

    /// This is where the tunnel owner has a chance to handle the settings change locally.
    ///
    /// The extension can also handle these changes so not everything needs to be handled here.
    ///
    private func handleSettingsChange(_ change: TunnelSettings.Change) async throws {
        switch change {
        case .setIncludeAllNetworks(let includeAllNetworks):
            try await handleSetIncludeAllNetworks(includeAllNetworks)
        case .setEnforceRoutes(let enforceRoutes):
            try await handleSetEnforceRoutes(enforceRoutes)
        case .setExcludeLocalNetworks(let excludeLocalNetworks):
            try await handleSetExcludeLocalNetworks(excludeLocalNetworks)
        case .setConnectOnLogin,
                .setRegistrationKeyValidity,
                .setSelectedServer,
                .setSelectedEnvironment,
                .setSelectedLocation,
                .setShowInMenuBar:
            // Intentional no-op as this is handled by the extension or the agent's app delegate
            break
        }
    }

    private func handleSetIncludeAllNetworks(_ includeAllNetworks: Bool) async throws {
        guard let tunnelManager = await loadTunnelManager(),
              tunnelManager.protocolConfiguration?.includeAllNetworks == !includeAllNetworks else {
            return
        }

        try await setupAndSave(tunnelManager)
    }

    private func handleSetEnforceRoutes(_ enforceRoutes: Bool) async throws {
        guard let tunnelManager = await loadTunnelManager(),
              tunnelManager.protocolConfiguration?.enforceRoutes == !enforceRoutes else {
            return
        }

        try await setupAndSave(tunnelManager)
    }

    private func handleSetExcludeLocalNetworks(_ excludeLocalNetworks: Bool) async throws {
        guard let tunnelManager = await loadTunnelManager(),
              tunnelManager.protocolConfiguration?.excludeLocalNetworks == !excludeLocalNetworks else {
            return
        }

        try await setupAndSave(tunnelManager)
        updateRoutes()
    }

    private func relaySettingsChange(_ change: TunnelSettings.Change) async throws {
        guard await isConnected,
              let activeSession = try await ConnectionSessionUtilities.activeSession(networkExtensionBundleID: networkExtensionBundleID) else { return }

        let errorMessage: ExtensionMessageString? = try await activeSession.sendProviderRequest(.changeTunnelSetting(change))
        if let errorMessage {
            throw TunnelFailureError(errorDescription: errorMessage.value)
        }
    }

    // MARK: - Tunnel Configuration

    /// Setups the tunnel manager if it's not set up already.
    ///
    @MainActor
    private func setup(_ tunnelManager: NETunnelProviderManager) {
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
                NetworkProtectionOptionKey.includedRoutes: includedRoutes().map(\.stringRepresentation) as NSArray
            ]

            // always-on
            protocolConfiguration.disconnectOnSleep = false

            // kill switch
            protocolConfiguration.enforceRoutes = settings.enforceRoutes
            // this setting breaks Connection Tester
            protocolConfiguration.includeAllNetworks = settings.includeAllNetworks
            protocolConfiguration.excludeLocalNetworks = settings.excludeLocalNetworks

            return protocolConfiguration
        }()
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
    /// Ensures that the system extension is activated if necessary.
    ///
    private func activateSystemExtension(waitingForUserApproval: @escaping () -> Void) async throws {
        do {
            try await networkExtensionController.activateSystemExtension(
                waitingForUserApproval: waitingForUserApproval)
        } catch {
            switch error {
            case OSSystemExtensionError.requestSuperseded:
                // Even if the installation request is superseded we want to show the message that tells the user
                // to go to System Settings to allow the extension
                controllerErrorStore.lastErrorMessage = UserText.networkProtectionSystemSettings
            case SystemExtensionRequestError.unknownRequestResult:
                controllerErrorStore.lastErrorMessage = UserText.networkProtectionUnknownActivationError

                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionSystemExtensionUnknownActivationResult,
                    frequency: .standard,
                    includeAppVersionParameter: true)
            case SystemExtensionRequestError.willActivateAfterReboot:
                controllerErrorStore.lastErrorMessage = UserText.networkProtectionPleaseReboot
            default:
                controllerErrorStore.lastErrorMessage = error.localizedDescription
            }

            return
        }

        self.controllerErrorStore.lastErrorMessage = nil

        // We'll only update to completed if we were showing the onboarding step to
        // allow the system extension.  Otherwise we may override the allow-VPN
        // onboarding step.
        //
        // Additionally if the onboarding step was allowing the system extension, we won't
        // start the tunnel at once, and instead require that the user enables the toggle.
        //
        if onboardingStatusRawValue == OnboardingStatus.isOnboarding(step: .userNeedsToAllowExtension).rawValue {
            onboardingStatusRawValue = OnboardingStatus.isOnboarding(step: .userNeedsToAllowVPNConfiguration).rawValue
            return
        }
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
        controllerErrorStore.lastErrorMessage = nil

#if NETP_SYSTEM_EXTENSION
        do {
            try await activateSystemExtension { [weak self] in
                // If we're waiting for user approval we wanna make sure the
                // onboarding step is set correctly.  This can be useful to
                // help prevent the value from being de-synchronized.
                self?.onboardingStatusRawValue = OnboardingStatus.isOnboarding(step: .userNeedsToAllowExtension).rawValue
            }
        } catch {
            await stop()
            return
        }
#endif

        do {
            let tunnelManager: NETunnelProviderManager

            do {
                tunnelManager = try await loadOrMakeTunnelManager()
            } catch {
                if case NEVPNError.configurationReadWriteFailed = error {
                    onboardingStatusRawValue = OnboardingStatus.isOnboarding(step: .userNeedsToAllowVPNConfiguration).rawValue
                }

                throw error
            }
            onboardingStatusRawValue = OnboardingStatus.completed.rawValue

            switch tunnelManager.connection.status {
            case .invalid:
                throw StartError.connectionStatusInvalid
            case .connected:
                // Intentional no-op
                break
            default:
                try await start(tunnelManager)
            }
        } catch {
            await stop()
            controllerErrorStore.lastErrorMessage = error.localizedDescription
        }
    }

    private func start(_ tunnelManager: NETunnelProviderManager) async throws {
        var options = [String: NSObject]()

        options[NetworkProtectionOptionKey.activationAttemptId] = UUID().uuidString as NSString
        options[NetworkProtectionOptionKey.authToken] = try tokenStore.fetchToken() as NSString?
        options[NetworkProtectionOptionKey.selectedEnvironment] = settings.selectedEnvironment.rawValue as? NSString
        options[NetworkProtectionOptionKey.selectedServer] = settings.selectedServer.stringValue as? NSString

        if case .custom(let keyValidity) = settings.registrationKeyValidity {
            options[NetworkProtectionOptionKey.keyValidity] = String(describing: keyValidity) as NSString
        }

        if Self.simulationOptions.isEnabled(.tunnelFailure) {
            Self.simulationOptions.setEnabled(false, option: .tunnelFailure)
            options[NetworkProtectionOptionKey.tunnelFailureSimulation] = NSNumber(value: true)
        }

        if Self.simulationOptions.isEnabled(.crashFatalError) {
            Self.simulationOptions.setEnabled(false, option: .crashFatalError)
            options[NetworkProtectionOptionKey.tunnelFatalErrorCrashSimulation] = NSNumber(value: true)
        }

        if Self.simulationOptions.isEnabled(.controllerFailure) {
            Self.simulationOptions.setEnabled(false, option: .controllerFailure)
            throw StartError.simulateControllerFailureError
        }

        try tunnelManager.connection.startVPNTunnel(options: options)
        try await statusTransitionAwaiter.waitUntilConnectionStarted()
        try await enableOnDemand(tunnelManager: tunnelManager)
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
    func enableOnDemand(tunnelManager: NETunnelProviderManager) async throws {
        let rule = NEOnDemandRuleConnect()
        rule.interfaceTypeMatch = .any

        tunnelManager.onDemandRules = [rule]
        tunnelManager.isOnDemandEnabled = true

        try await tunnelManager.saveToPreferences()
    }

    @MainActor
    func disableOnDemand(tunnelManager: NETunnelProviderManager) async throws {
        tunnelManager.isOnDemandEnabled = false

        try await tunnelManager.saveToPreferences()
    }

    @MainActor
    private func excludedRoutes() -> [NetworkProtection.IPAddressRange] {
        settings.exclusionList.compactMap { [excludedRoutesPreferences] item -> NetworkProtection.IPAddressRange? in
            guard case .exclusion(range: let range, description: _, default: let defaultValue) = item,
                  excludedRoutesPreferences[range.stringRepresentation, default: defaultValue] == true
            else { return nil }
            // TO BE fixed:
            // when 10.11.12.1 DNS is used 10.0.0.0/8 should be included (not excluded)
            // but marking 10.11.12.1 as an Included Route breaks tunnel (probably these routes are conflicting)
            if settings.enforceRoutes && range == "10.0.0.0/8" {
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
    func setExcludedRoute(_ route: String, enabled: Bool) {
        excludedRoutesPreferences[route] = enabled
        updateRoutes()
    }

    @MainActor
    func isExcludedRouteEnabled(_ route: String) -> Bool {
        guard let range = IPAddressRange(from: route),
              let exclusionListItem = settings.exclusionList.first(where: {
                  if case .exclusion(range: range, description: _, default: _) = $0 { return true }
                  return false
              }),
              case .exclusion(range: _, description: _, default: let defaultValue) = exclusionListItem else {

            assertionFailure("Invalid route \(route)")
            return false
        }
        // TO BE fixed: see excludedRoutes()
        if settings.enforceRoutes && route == "10.0.0.0/8" {
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

    struct TunnelFailureError: LocalizedError {
        let errorDescription: String?
    }

    @MainActor
    func toggleShouldSimulateTunnelFailure() async throws {
        if Self.simulationOptions.isEnabled(.tunnelFailure) {
            Self.simulationOptions.setEnabled(false, option: .tunnelFailure)
        } else {
            Self.simulationOptions.setEnabled(true, option: .tunnelFailure)
            try await sendProviderMessageToActiveSession(.simulateTunnelFailure)
        }
    }

    @MainActor
    func toggleShouldSimulateTunnelFatalError() async throws {
        if Self.simulationOptions.isEnabled(.crashFatalError) {
            Self.simulationOptions.setEnabled(false, option: .crashFatalError)
        } else {
            Self.simulationOptions.setEnabled(true, option: .crashFatalError)
            try await sendProviderMessageToActiveSession(.simulateTunnelFatalError)
        }
    }

    @MainActor
    func toggleShouldSimulateConnectionInterruption() async throws {
        if Self.simulationOptions.isEnabled(.connectionInterruption) {
            Self.simulationOptions.setEnabled(false, option: .connectionInterruption)
        } else {
            Self.simulationOptions.setEnabled(true, option: .connectionInterruption)
            try await sendProviderMessageToActiveSession(.simulateConnectionInterruption)
        }
    }

    @MainActor
    private func sendProviderMessageToActiveSession(_ message: ExtensionMessage) async throws {
        guard await isConnected,
              let activeSession = try await ConnectionSessionUtilities.activeSession() else { return }

        let errorMessage: ExtensionMessageString? = try await activeSession.sendProviderMessage(message)
        if let errorMessage {
            throw TunnelFailureError(errorDescription: errorMessage.value)
        }
    }
}

#endif
