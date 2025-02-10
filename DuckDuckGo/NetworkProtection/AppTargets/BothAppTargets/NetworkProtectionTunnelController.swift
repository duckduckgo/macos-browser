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

import Foundation
import Combine
import SwiftUI
import Common
import FeatureFlags
import NetworkExtension
import NetworkProtection
import NetworkProtectionProxy
import NetworkProtectionUI
import Networking
import PixelKit
import os.log

#if NETP_SYSTEM_EXTENSION
import SystemExtensionManager
import SystemExtensions
#endif

import Subscription
import BrowserServicesKit

typealias NetworkProtectionStatusChangeHandler = (NetworkProtection.ConnectionStatus) -> Void
typealias NetworkProtectionConfigChangeHandler = () -> Void

final class NetworkProtectionTunnelController: TunnelController, TunnelSessionProvider {

    // MARK: - Configuration

    private let featureFlagger: FeatureFlagger
    let settings: VPNSettings
    let defaults: UserDefaults

    // MARK: - Combine Cancellables

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Debug Helpers

    /// Debug simulation options to aid with testing NetP.
    ///
    /// This is static because we want these options to be shared across all instances of `NetworkProtectionProvider`.
    ///
    static var simulationOptions = NetworkProtectionSimulationOptions()

    /// Stores the last controller error for the purpose of updating the UI as needed.
    ///
    private let controllerErrorStore = NetworkProtectionControllerErrorStore()

    private let knownFailureStore = NetworkProtectionKnownFailureStore()

    // MARK: - Subscriptions

    private let accessTokenStorage: SubscriptionTokenKeychainStorage

    // MARK: - Debug Options Support

    private let networkExtensionBundleID: String
    private let networkExtensionController: NetworkExtensionController

    // MARK: - Notification Center

    private let notificationCenter: NotificationCenter

    /// The tunnel manager
    ///
    /// We're keeping a reference to this because we don't want to be calling `loadAllFromPreferences` more than
    /// once.
    ///
    /// For reference read: https://app.asana.com/0/1203137811378537/1206513608690551/f
    ///
    private var internalManager: NETunnelProviderManager?

    /// Simply clears the internal manager so the VPN manager is reloaded next time it's requested.
    ///
    @MainActor
    private func clearInternalManager() {
        internalManager = nil
    }

    /// The last known VPN status.
    ///
    /// Should not be used for checking the current status.
    ///
    private var previousStatus: NEVPNStatus = .invalid

    // MARK: - User Defaults

    @UserDefaultsWrapper(key: .networkProtectionOnboardingStatusRawValue, defaultValue: OnboardingStatus.default.rawValue, defaults: .netP)
    private(set) var onboardingStatusRawValue: OnboardingStatus.RawValue

    // MARK: - Tunnel Manager

    /// Loads the configuration matching our ``extensionID``.
    ///
    @MainActor
    public var manager: NETunnelProviderManager? {
        get async {
            if let internalManager {
                return internalManager
            }

            let manager = try? await NETunnelProviderManager.loadAllFromPreferences().first { manager in
                (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == networkExtensionBundleID
            }
            internalManager = manager
            return manager
        }
    }

    @MainActor
    private func loadOrMakeTunnelManager() async throws -> NETunnelProviderManager {
        let tunnelManager = await manager ?? {
            let manager = NETunnelProviderManager()
            internalManager = manager
            return manager
        }()

        try await setupAndSave(tunnelManager)
        return tunnelManager
    }

    @MainActor
    private func setupAndSave(_ tunnelManager: NETunnelProviderManager) async throws {
        setup(tunnelManager)
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
         featureFlagger: FeatureFlagger,
         settings: VPNSettings,
         defaults: UserDefaults,
         notificationCenter: NotificationCenter = .default,
         accessTokenStorage: SubscriptionTokenKeychainStorage) {

        self.featureFlagger = featureFlagger
        self.networkExtensionBundleID = networkExtensionBundleID
        self.networkExtensionController = networkExtensionController
        self.notificationCenter = notificationCenter
        self.settings = settings
        self.defaults = defaults
        self.accessTokenStorage = accessTokenStorage

        subscribeToSettingsChanges()
        subscribeToStatusChanges()
        subscribeToConfigurationChanges()
    }

    // MARK: - Observing Status Changes

    private func subscribeToStatusChanges() {
        notificationCenter.publisher(for: .NEVPNStatusDidChange)
            .sink { [weak self] status in
                self?.handleStatusChange(status)
            }
            .store(in: &cancellables)
    }

    private func handleStatusChange(_ notification: Notification) {
        guard let session = (notification.object as? NETunnelProviderSession),
              session.status != previousStatus,
              let manager = session.manager as? NETunnelProviderManager else {

            return
        }

        Task { @MainActor in
            previousStatus = session.status

            switch session.status {
            case .connected:
                try await enableOnDemand(tunnelManager: manager)
            default:
                break
            }

        }
    }

    // MARK: - Observing Configuation Changes

    private func subscribeToConfigurationChanges() {
        notificationCenter.publisher(for: .NEVPNConfigurationChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }

                Task { @MainActor in
                    guard let manager = await self.manager else {
                        return
                    }

                    do {
                        try await manager.loadFromPreferences()

                        if manager.connection.status == .invalid {
                            self.clearInternalManager()
                        }
                    } catch {
                        self.clearInternalManager()
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Subscriptions

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

    // MARK: - Handling Settings Changes

    /// This is where the tunnel owner has a chance to handle the settings change locally.
    ///
    /// The extension can also handle these changes so not everything needs to be handled here.
    ///
    private func handleSettingsChange(_ change: VPNSettings.Change) async throws {
        switch change {
        case .setIncludeAllNetworks(let includeAllNetworks):
            try await handleSetIncludeAllNetworks(includeAllNetworks)
        case .setEnforceRoutes(let enforceRoutes):
            try await handleSetEnforceRoutes(enforceRoutes)
        case .setExcludeLocalNetworks(let excludeLocalNetworks):
            try await handleSetExcludeLocalNetworks(excludeLocalNetworks)
        case .setConnectOnLogin,
                .setNotifyStatusChanges,
                .setRegistrationKeyValidity,
                .setSelectedServer,
                .setSelectedEnvironment,
                .setSelectedLocation,
                .setDNSSettings,
                .setShowInMenuBar,
                .setDisableRekeying:
            // Intentional no-op as this is handled by the extension or the agent's app delegate
            break
        }
    }

    private func handleSetIncludeAllNetworks(_ includeAllNetworks: Bool) async throws {
        guard let tunnelManager = await manager,
              tunnelManager.protocolConfiguration?.includeAllNetworks == !includeAllNetworks else {
            return
        }

        try await setupAndSave(tunnelManager)
    }

    private func handleSetEnforceRoutes(_ enforceRoutes: Bool) async throws {
        guard let tunnelManager = await manager,
              tunnelManager.protocolConfiguration?.enforceRoutes == !enforceRoutes else {
            return
        }

        try await setupAndSave(tunnelManager)
    }

    private func handleSetExcludeLocalNetworks(_ excludeLocalNetworks: Bool) async throws {
        guard let tunnelManager = await manager else {
            return
        }

        try await setupAndSave(tunnelManager)
    }

    private func relaySettingsChange(_ change: VPNSettings.Change) async throws {
        guard await isConnected,
              let session = await session else {
            return
        }

        let errorMessage: ExtensionMessageString? = try await session.sendProviderRequest(.changeTunnelSetting(change))
        if let errorMessage {
            throw TunnelFailureError(errorDescription: errorMessage.value)
        }
    }

    // MARK: - Debug Command support

    func relay(_ command: VPNCommand) async throws {
        guard await isConnected,
              let session = await session else {
            return
        }

        let errorMessage: ExtensionMessageString? = try await session.sendProviderRequest(.command(command))
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
            protocolConfiguration.providerBundleIdentifier = Bundle.tunnelExtensionBundleID
            protocolConfiguration.providerConfiguration = [
                NetworkProtectionOptionKey.defaultPixelHeaders: APIRequest.Headers().httpHeaders,
            ]

            // always-on
            protocolConfiguration.disconnectOnSleep = false

            // kill switch
            protocolConfiguration.enforceRoutes = enforceRoutes

            // this setting breaks Connection Tester
            protocolConfiguration.includeAllNetworks = settings.includeAllNetworks

            // This messes up the routing, so please keep it always disabled
            protocolConfiguration.excludeLocalNetworks = false

            return protocolConfiguration
        }()
    }

    // MARK: - Connection & Session

    public var connection: NEVPNConnection? {
        get async {
            await manager?.connection
        }
    }

    public func activeSession() async -> NETunnelProviderSession? {
        await session
    }

    public var session: NETunnelProviderSession? {
        get async {
            guard let manager = await manager,
                  let session = manager.connection as? NETunnelProviderSession else {

                // The active connection is not running, so there's no session, this is acceptable
                return nil
            }

            return session
        }
    }

    // MARK: - Connection

    public var status: NEVPNStatus {
        get async {
            await connection?.status ?? .disconnected
        }
    }

    // MARK: - Connection Status Querying

    /// Queries the VPN to know if it's connected.
    ///
    /// - Returns: `true` if the VPN is connected, connecting or reasserting, and `false` otherwise.
    ///
    var isConnected: Bool {
        get async {
            switch await connection?.status {
            case .connected, .connecting, .reasserting:
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Activate System Extension

#if NETP_SYSTEM_EXTENSION
    /// Ensures that the system extension is activated if necessary.
    ///
    private func activateSystemExtension(waitingForUserApproval: @escaping () -> Void) async throws {
        do {
            try await networkExtensionController.activateSystemExtension(waitingForUserApproval: waitingForUserApproval)
        } catch {
            switch error {
            case OSSystemExtensionError.requestSuperseded:
                // Even if the installation request is superseded we want to show the message that tells the user
                // to go to System Settings to allow the extension
                controllerErrorStore.lastErrorMessage = UserText.networkProtectionSystemSettings
            case SystemExtensionRequestError.unknownRequestResult:
                controllerErrorStore.lastErrorMessage = UserText.networkProtectionUnknownActivationError
            case OSSystemExtensionError.extensionNotFound,
                SystemExtensionRequestError.willActivateAfterReboot:
                controllerErrorStore.lastErrorMessage = UserText.networkProtectionPleaseReboot
            default:
                controllerErrorStore.lastErrorMessage = error.localizedDescription
            }

            PixelKit.fire(
                NetworkProtectionPixelEvent.networkProtectionSystemExtensionActivationFailure(error),
                frequency: .standard,
                includeAppVersionParameter: true
            )

            throw error
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

    enum StartError: LocalizedError, CustomNSError {
        case cancelled
        case noAuthToken
        case connectionStatusInvalid
        case connectionAlreadyStarted
        case simulateControllerFailureError
        case startTunnelFailure(_ error: Error)

        var errorDescription: String? {
            switch self {
            case .cancelled:
                return nil
            case .noAuthToken:
                return "You need a subscription to start the VPN"
            case .connectionAlreadyStarted:
#if DEBUG
                return "[Debug] Connection already started"
#else
                return nil
#endif

            case .connectionStatusInvalid:
#if DEBUG
                return "[DEBUG] Connection status invalid"
#else
                return "An unexpected error occurred, please try again"
#endif
            case .simulateControllerFailureError:
                return "Simulated a controller error as requested"
            case .startTunnelFailure(let error):
                return error.localizedDescription
            }
        }

        var errorCode: Int {
            switch self {
            case .cancelled: return 0
                // MARK: Setup errors
            case .noAuthToken: return 1
            case .connectionStatusInvalid: return 2
            case .connectionAlreadyStarted: return 3
            case .simulateControllerFailureError: return 4
                // MARK: Actual connection attempt issues
            case .startTunnelFailure: return 100
            }
        }

        var errorUserInfo: [String: Any] {
            switch self {
            case .cancelled,
                    .noAuthToken,
                    .connectionStatusInvalid,
                    .connectionAlreadyStarted,
                    .simulateControllerFailureError:
                return [:]
            case .startTunnelFailure(let error):
                return [NSUnderlyingErrorKey: error]
            }
        }
    }

    /// Starts the VPN connection
    ///
    func start() async {
        Logger.networkProtection.log("Start VPN")
        VPNOperationErrorRecorder().beginRecordingControllerStart()
        PixelKit.fire(NetworkProtectionPixelEvent.networkProtectionControllerStartAttempt,
                      frequency: .legacyDailyAndCount)
        controllerErrorStore.lastErrorMessage = nil

        do {
#if NETP_SYSTEM_EXTENSION
            try await activateSystemExtension { [weak self] in
                // If we're waiting for user approval we wanna make sure the
                // onboarding step is set correctly.  This can be useful to
                // help prevent the value from being de-synchronized.
                self?.onboardingStatusRawValue = OnboardingStatus.isOnboarding(step: .userNeedsToAllowExtension).rawValue
            }
#endif

            let tunnelManager: NETunnelProviderManager

            do {
                tunnelManager = try await loadOrMakeTunnelManager()
            } catch {
                if case NEVPNError.configurationReadWriteFailed = error {
                    onboardingStatusRawValue = OnboardingStatus.isOnboarding(step: .userNeedsToAllowVPNConfiguration).rawValue

                    throw StartError.cancelled
                }

                throw error
            }
            onboardingStatusRawValue = OnboardingStatus.completed.rawValue

            switch tunnelManager.connection.status {
            case .invalid:
                throw StartError.connectionStatusInvalid
            case .connected:
                throw StartError.connectionAlreadyStarted
            default:
                try await start(tunnelManager)

                // It's important to note that we've seen instances where the above call to start()
                // doesn't throw any errors, yet the tunnel fails to start.  In any case this pixel
                // should be interpreted as "the controller successfully requested the tunnel to be
                // started".  Meaning there's no error caught in this start attempt.  There are pixels
                // in the packet tunnel provider side that can be used to debug additional logic.
                //
                PixelKit.fire(NetworkProtectionPixelEvent.networkProtectionControllerStartSuccess,
                              frequency: .legacyDailyAndCount)
            }
        } catch {
            Logger.networkProtection.error("Starting tunnel error: \(error, privacy: .public)")

            VPNOperationErrorRecorder().recordControllerStartFailure(error)
            knownFailureStore.lastKnownFailure = KnownFailure(error)

            if case StartError.cancelled = error {
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionControllerStartCancelled, frequency: .legacyDailyAndCount, includeAppVersionParameter: true
                )
            } else {
                PixelKit.fire(
                    NetworkProtectionPixelEvent.networkProtectionControllerStartFailure(error), frequency: .legacyDailyAndCount, includeAppVersionParameter: true
                )
            }

            // Always keep the first error message shown, as it's the more actionable one.
            if controllerErrorStore.lastErrorMessage == nil {
                controllerErrorStore.lastErrorMessage = error.localizedDescription
            }
        }
    }

    private func start(_ tunnelManager: NETunnelProviderManager) async throws {
        var options = [String: NSObject]()

        options[NetworkProtectionOptionKey.activationAttemptId] = UUID().uuidString as NSString
        guard let authToken = try fetchAuthToken() else {
            throw StartError.noAuthToken
        }
        options[NetworkProtectionOptionKey.authToken] = authToken
        options[NetworkProtectionOptionKey.selectedEnvironment] = settings.selectedEnvironment.rawValue as NSString
        options[NetworkProtectionOptionKey.selectedServer] = settings.selectedServer.stringValue as? NSString

        options[NetworkProtectionOptionKey.excludeLocalNetworks] = NSNumber(value: settings.excludeLocalNetworks)

#if NETP_SYSTEM_EXTENSION
        if let data = try? JSONEncoder().encode(settings.selectedLocation) {
            options[NetworkProtectionOptionKey.selectedLocation] = NSData(data: data)
        }
#endif

        if let data = try? JSONEncoder().encode(settings.dnsSettings) {
            options[NetworkProtectionOptionKey.dnsSettings] = NSData(data: data)
        }

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

        do {
            Logger.networkProtection.log("Starting NetworkProtectionTunnelController, options: \(options, privacy: .public)")
            try tunnelManager.connection.startVPNTunnel(options: options)
        } catch {
            Logger.networkProtection.fault("Failed to start VPN tunnel: \(error, privacy: .public)")
            throw StartError.startTunnelFailure(error)
        }

        PixelKit.fire(
            NetworkProtectionPixelEvent.networkProtectionNewUser,
            frequency: .uniqueByName,
            includeAppVersionParameter: true) { [weak self] fired, error in
                guard let self, error == nil, fired else { return }
                self.defaults.vpnFirstEnabled = PixelKit.pixelLastFireDate(event: NetworkProtectionPixelEvent.networkProtectionNewUser)
            }
    }

    /// Stops the VPN connection
    ///
    @MainActor
    func stop() async {
        Logger.networkProtection.log("Stop VPN")
        await stop(disableOnDemand: true)
    }

    @MainActor
    func stop(disableOnDemand: Bool) async {
        guard let manager = await manager else {
            return
        }

        await stop(tunnelManager: manager, disableOnDemand: disableOnDemand)
    }

    @MainActor
    private func stop(tunnelManager: NETunnelProviderManager, disableOnDemand: Bool) async {
        if disableOnDemand {
            try? await self.disableOnDemand(tunnelManager: tunnelManager)
        }

        switch tunnelManager.connection.status {
        case .connected, .connecting, .reasserting:
            tunnelManager.connection.stopVPNTunnel()
        default:
            break
        }
    }

    func command(_ command: VPNCommand) async throws {
        try await sendProviderMessageToActiveSession(.request(.command(command)))
    }

    /// Restarts the tunnel.
    ///
    @MainActor
    func restart() async {
        await stop(disableOnDemand: false)
    }

    // MARK: - On Demand & Kill Switch

    @MainActor
    func enableOnDemand(tunnelManager: NETunnelProviderManager) async throws {
        try await tunnelManager.loadFromPreferences()

        let rule = NEOnDemandRuleConnect()
        rule.interfaceTypeMatch = .any

        tunnelManager.onDemandRules = [rule]
        tunnelManager.isOnDemandEnabled = true

        try await tunnelManager.saveToPreferences()
    }

    @MainActor
    func disableOnDemand(tunnelManager: NETunnelProviderManager) async throws {
        try await tunnelManager.loadFromPreferences()

        guard tunnelManager.connection.status != .invalid else {
            // An invalid connection status means the VPN isn't really configured
            // so we don't want to save changed because that would re-create the VPN
            // configuration.
            clearInternalManager()
            return
        }

        tunnelManager.isOnDemandEnabled = false

        try await tunnelManager.saveToPreferences()
    }

    // MARK: - Routing

    private var enforceRoutes: Bool {
        featureFlagger.isFeatureOn(.networkProtectionEnforceRoutes)
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
    private func sendProviderRequestToActiveSession(_ request: ExtensionRequest) async throws {
        try await sendProviderMessageToActiveSession(.request(request))
    }

    @MainActor
    private func sendProviderMessageToActiveSession(_ message: ExtensionMessage) async throws {
        guard await isConnected,
              let session = await session else {
            return
        }

        let errorMessage: ExtensionMessageString? = try await session.sendProviderMessage(message)
        if let errorMessage {
            throw TunnelFailureError(errorDescription: errorMessage.value)
        }
    }

    private func fetchAuthToken() throws -> NSString? {
        if let accessToken = try? accessTokenStorage.getAccessToken() {
            Logger.networkProtection.log("🟢 TunnelController found token")
            return Self.adaptAccessTokenForVPN(accessToken) as NSString?
        } else {
            Logger.networkProtection.error("TunnelController found no token")
            return nil
        }
    }

    private static func adaptAccessTokenForVPN(_ token: String) -> String {
        "ddg:\(token)"
    }
}
