//
//  PacketTunnelProvider.swift
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

// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import Common
import Networking
import Foundation
import NetworkExtension
import NetworkProtection
import PixelKit
import UserNotifications

// swiftlint:disable:next type_body_length
final class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: - Error Handling

    enum TunnelError: LocalizedError {
        case couldNotGenerateTunnelConfiguration(internalError: Error)
        case couldNotFixConnection
        case simulateTunnelFailureError

        var errorDescription: String? {
            switch self {
            case .couldNotGenerateTunnelConfiguration(let internalError):
                return "Failed to generate a tunnel configuration: \(internalError.localizedDescription)"
            case .simulateTunnelFailureError:
                return "Simulated a tunnel error as requested"
            default:
                // This is probably not the most elegant error to show to a user but
                // it's a great way to get detailed reports for those cases we haven't
                // provided good descriptions for yet.
                return "Tunnel error: \(String(describing: self))"
            }
        }
    }

    // MARK: - WireGuard

    private lazy var adapter: WireGuardAdapter = {
        WireGuardAdapter(with: self) { logLevel, message in
            if logLevel == .error {
                os_log("🔵 Received error from adapter: %{public}@", log: .networkProtection, type: .error, message)
            } else {
                os_log("🔵 Received message from adapter: %{public}@", log: .networkProtection, type: .info, message)
            }
        }
    }()

    // MARK: - Timers Support

    private let timerQueue = DispatchQueue(label: "com.duckduckgo.network-protection.PacketTunnelProvider.timerQueue")

    // MARK: - Distributed Notifications

    private var distributedNotificationCenter = DistributedNotificationCenter.forType(.networkProtection)

    // MARK: - Status

    override var reasserting: Bool {
        get {
            super.reasserting
        }

        set {
            if newValue {
                connectionStatus = .reasserting
            } else {
                connectionStatus = .connected(connectedDate: Date())
            }

            super.reasserting = newValue
        }
    }

    private var connectionStatus: ConnectionStatus = .disconnected {
        didSet {
            if oldValue != connectionStatus {
                broadcastConnectionStatus()
            }
        }
    }

    private func broadcastConnectionStatus() {
        let data = ConnectionStatusEncoder().encode(connectionStatus)
        distributedNotificationCenter.post(.statusDidChange, object: data)
    }

    // MARK: - Server Selection

    let selectedServerStore = NetworkProtectionSelectedServerUserDefaultsStore()

    var lastSelectedServerInfo: NetworkProtectionServerInfo? {
        didSet {
            broadcastLastSelectedServerInfo()
        }
    }

    private func broadcastLastSelectedServerInfo() {
        guard let serverInfo = lastSelectedServerInfo else {
            return
        }

        let serverStatusInfo = NetworkProtectionStatusServerInfo(serverLocation: serverInfo.serverLocation, serverAddress: serverInfo.endpoint?.description)
        let payload: String?

        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(serverStatusInfo)

            payload = String(data: jsonData, encoding: .utf8)

            if payload == nil {
                os_log("Error encoding serverInfo Data to String: %{public}@", log: .networkProtection, type: .error, String(describing: jsonData))
                // Continue anyway, we'll just update the UI to show "Unknown" server info, which is better
                // than showing the info from the previous server.
            }
        } catch {
            os_log("Error encoding serverInfo to Data: %{public}@", log: .networkProtection, type: .error, error.localizedDescription)
            // Continue anyway, we'll just update the UI to show "Unknown" server info, which is better
            // than showing the info from the previous server.
            payload = nil
        }

        distributedNotificationCenter.post(.serverSelected, object: payload)
        // Update shared userdefaults
    }

    // MARK: - User Notifications

    private lazy var notificationsPresenter: NetworkProtectionNotificationsPresenter = {
#if NETP_SYSTEM_EXTENSION
        NetworkProtectionIPCNotificationsPresenter(ipcConnection: self.ipcConnection)
#else
        let parentBundlePath = "../../../"
        let mainAppURL: URL

        if #available(macOS 13, *) {
            mainAppURL = URL(filePath: parentBundlePath, relativeTo: Bundle.main.bundleURL)
        } else {
            mainAppURL = URL(fileURLWithPath: parentBundlePath, relativeTo: Bundle.main.bundleURL)
        }

        return NetworkProtectionUNNotificationsPresenter(mainAppURL: mainAppURL)
#endif
    }()

    // MARK: - Registration Key

    private lazy var keyStore = NetworkProtectionKeychainKeyStore(useSystemKeychain: NetworkProtectionBundle.usesSystemKeychain(),
                                                                  errorEvents: networkProtectionDebugEvents)

    private lazy var tokenStore = NetworkProtectionKeychainTokenStore(useSystemKeychain: NetworkProtectionBundle.usesSystemKeychain(),
                                                                      errorEvents: networkProtectionDebugEvents)

    /// This is for overriding the defaults.  A `nil` value means NetP will just use the defaults.
    ///
    private var keyValidity: TimeInterval?

    private static let defaultRetryInterval = TimeInterval(60)

    /// Normally we'll retry using the default interval, but since we can override the key validity interval for testing purposes
    /// we'll retry sooner if it's been overridden with values lower than the default retry interval.
    ///
    /// In practical terms this means that if the validity interval is 15 secs, the retry will also be 15 secs instead of 1 minute.
    ///
    private var retryInterval: TimeInterval {
        guard let keyValidity = keyValidity else {
            return Self.defaultRetryInterval
        }

        return keyValidity > Self.defaultRetryInterval ? Self.defaultRetryInterval : keyValidity
    }

    private func resetRegistrationKey() {
        os_log("Resetting the current registration key", log: .networkProtectionKeyManagement, type: .info)
        keyStore.resetCurrentKeyPair()
    }

    private var isKeyExpired: Bool {
        keyStore.currentKeyPair().expirationDate <= Date()
    }

    private func rekeyIfExpired() async {
        guard isKeyExpired else {
            return
        }

        await rekey()
    }

    private func rekey() async {
        os_log("Rekeying...", log: .networkProtectionKeyManagement, type: .info)

        Pixel.fire(.networkProtectionActiveUser, frequency: .dailyOnly, includeAppVersionParameter: true)
        Pixel.fire(.networkProtectionRekeyCompleted, frequency: .dailyAndContinuous, includeAppVersionParameter: true)

        self.resetRegistrationKey()

        do {
            try await updateTunnelConfiguration(selectedServer: selectedServerStore.selectedServer, reassert: false)
        } catch {
            os_log("Rekey attempt failed.  This is not an error if you're using debug Key Management options: %{public}@", log: .networkProtectionKeyManagement, type: .error, String(describing: error))
        }
    }

    private func setKeyValidity(_ interval: TimeInterval?) {
        guard keyValidity != interval,
            let interval = interval else {

            return
        }

        let firstExpirationDate = Date().addingTimeInterval(interval)

        os_log("Setting key validity to %{public}@ seconds (next expiration date %{public}@)",
               log: .networkProtectionKeyManagement,
               type: .info,
               String(describing: interval),
               String(describing: firstExpirationDate))
        keyStore.setValidityInterval(interval)
    }

    // MARK: - Bandwidth Analyzer

    private func updateBandwidthAnalyzerAndRekeyIfExpired() {
        Task {
            await updateBandwidthAnalyzer()

            guard self.bandwidthAnalyzer.isConnectionIdle() else {
                return
            }

            await rekeyIfExpired()
        }
    }

    /// Updates the bandwidth analyzer with the latest data from the WireGuard Adapter
    ///
    private func updateBandwidthAnalyzer() async {
        guard let (rx, tx) = try? await adapter.getBytesTransmitted() else {
            self.bandwidthAnalyzer.preventIdle()
            return
        }

        bandwidthAnalyzer.record(rxBytes: rx, txBytes: tx)
    }

    // MARK: - IPC

#if NETP_SYSTEM_EXTENSION
    let ipcConnection = IPCConnection(log: .networkProtectionIPCLog, memoryManagementLog: .networkProtectionMemoryLog)
#endif

    // MARK: - Connection tester

    private lazy var connectionTester: NetworkProtectionConnectionTester = {
        NetworkProtectionConnectionTester(timerQueue: timerQueue, log: .networkProtectionConnectionTesterLog) { @MainActor [weak self] result in
            guard let self else { return }

            switch result {
            case .connected:
                self.tunnelHealth.isHavingConnectivityIssues = false
                self.updateBandwidthAnalyzerAndRekeyIfExpired()
                self.startLatencyReporter()

            case .reconnected:
                self.tunnelHealth.isHavingConnectivityIssues = false
                self.notificationsPresenter.showReconnectedNotification()
                self.reasserting = false
                self.updateBandwidthAnalyzerAndRekeyIfExpired()
                self.startLatencyReporter()

            case .disconnected(let failureCount):
                self.tunnelHealth.isHavingConnectivityIssues = true
                self.bandwidthAnalyzer.reset()
                self.latencyReporter.stop()

                if failureCount == 1 {
                    self.notificationsPresenter.showReconnectingNotification()
                    self.reasserting = true
                    self.fixTunnel()
                } else if failureCount == 2 {
                    self.notificationsPresenter.showConnectionFailureNotification()
                    self.stopTunnel(with: TunnelError.couldNotFixConnection)
                }
            }
        }
    }()

    @MainActor
    private func startLatencyReporter() {
        guard let lastSelectedServerInfo,
              let ip = lastSelectedServerInfo.ipv4 else {
            assertionFailure("could not get server IPv4 address")
            self.latencyReporter.stop()
            return
        }
        if self.latencyReporter.isStarted {
            if self.latencyReporter.currentIP == ip {
                return
            }
            self.latencyReporter.stop()
        }

        self.latencyReporter.start(ip: ip) { [serverName=lastSelectedServerInfo.name] latency, networkType in
            Pixel.fire(.networkProtectionLatency(ms: Int(latency * 1000), server: serverName, networkType: networkType), frequency: .standard)
        }
    }

    private var lastTestFailed = false
    private let bandwidthAnalyzer = NetworkProtectionConnectionBandwidthAnalyzer()
    private let tunnelHealth = NetworkProtectionTunnelHealthStore()
    private let controllerErrorStore = NetworkProtectionTunnelErrorStore()
    private let latencyReporter = NetworkProtectionLatencyReporter(log: .networkProtection)

    // MARK: - Notifications: Observation Tokens

    private var observationTokens = [NotificationToken]()

    // MARK: - Initializers

    override init() {
        os_log("[+] PacketTunnelProvider", log: .networkProtectionMemoryLog, type: .debug)

        super.init()

        #if NETP_SYSTEM_EXTENSION
        ipcConnection.startListener()
        #endif

        observationTokens.append(distributedNotificationCenter.addObserver(for: .requestStatusUpdate, object: nil, queue: nil) { [weak self] _ in

            self?.broadcastConnectionStatus()
            self?.broadcastLastSelectedServerInfo()
        })

        connectionStatus = .disconnected
    }

    deinit {
        os_log("[-] PacketTunnelProvider", log: .networkProtectionMemoryLog, type: .debug)
    }

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

    private var tunnelProviderProtocol: NETunnelProviderProtocol? {
        protocolConfiguration as? NETunnelProviderProtocol
    }

    private func load(options: [String: NSObject]?) {
        guard let options = options else {
            os_log("🔵 Tunnel options are not set", log: .networkProtection)
            assertionFailure("Tunnel options are not set")
            return
        }

        loadVendorOptions(from: options)
        loadKeyValidity(from: options)
        loadSelectedServer(from: options)
        loadAuthToken(from: options)
    }

    private func loadVendorOptions(from options: [String: AnyObject]) {
        guard let vendorOptions = options["VendorData"] as? [String: AnyObject] else {
            os_log("🔵 VendorData is not set", log: .networkProtection)
            assertionFailure("VendorData is not set")
            return
        }

        loadDefaultPixelHeaders(from: vendorOptions)
    }

    private func loadDefaultPixelHeaders(from options: [String: AnyObject]) {
        guard let defaultPixelHeaders = options[NetworkProtectionOptionKey.defaultPixelHeaders.rawValue] as? [String: String] else {

            os_log("🔵 Pixel options are not set", log: .networkProtection)
            assertionFailure("Default pixel headers are not set")
            return
        }

        setupPixels(defaultHeaders: defaultPixelHeaders)
    }

    private func loadKeyValidity(from options: [String: AnyObject]) {
        guard let keyValidityString = options["keyValidity"] as? String,
           let keyValidity = TimeInterval(keyValidityString) else {
            return
        }

        setKeyValidity(keyValidity)
    }

    private func loadSelectedServer(from options: [String: AnyObject]) {
        guard let serverName = options["selectedServer"] as? String else {
            return
        }

        selectedServerStore.selectedServer = .endpoint(serverName)
    }

    private func loadAuthToken(from options: [String: AnyObject]) {
        guard let authToken = options["authToken"] as? String else {
            return
        }

        tokenStore.store(authToken)
    }

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        connectionStatus = .connecting

        let internalCompletionHandler = { (error: Error?) in
            if error != nil {
                self.connectionStatus = .disconnected
            }

            completionHandler(error)
        }

        let activationAttemptId = options?["activationAttemptId"] as? String

        tunnelHealth.isHavingConnectivityIssues = false
        controllerErrorStore.lastErrorMessage = nil

        os_log("🔵 Will load options\n%{public}@", log: .networkProtection, type: .info, String(describing: options))

        if options?["tunnelFailureSimulation"] as? String == "true" {
            internalCompletionHandler(TunnelError.simulateTunnelFailureError)
            controllerErrorStore.lastErrorMessage = TunnelError.simulateTunnelFailureError.localizedDescription
            return
        }

        load(options: options)
        os_log("🔵 Done!", log: .networkProtection, type: .info)

        os_log("🔵 Starting tunnel from the %{public}@", log: .networkProtection, type: .info, activationAttemptId == nil ? "OS directly, rather than the app" : "app")

        startTunnel(selectedServer: selectedServerStore.selectedServer, completionHandler: internalCompletionHandler)
    }

    private func startTunnel(selectedServer: SelectedNetworkProtectionServer, completionHandler: @escaping (Error?) -> Void) {

        Task {
            let serverSelectionMethod: NetworkProtectionServerSelectionMethod

            switch selectedServerStore.selectedServer {
            case .automatic:
                serverSelectionMethod = .automatic
            case .endpoint(let serverName):
                serverSelectionMethod = .preferredServer(serverName: serverName)
            }

            do {
                os_log("🔵 Generating tunnel config", log: .networkProtection, type: .info)
                let tunnelConfiguration = try await generateTunnelConfiguration(serverSelectionMethod: serverSelectionMethod)
                startTunnel(with: tunnelConfiguration, completionHandler: completionHandler)
                os_log("🔵 Done generating tunnel config", log: .networkProtection, type: .info)
            } catch {
                os_log("🔵 Error starting tunnel: %{public}@", log: .networkProtection, type: .info, error.localizedDescription)

                controllerErrorStore.lastErrorMessage = error.localizedDescription

                let error = NSError(domain: NEVPNErrorDomain, code: NEVPNError.configurationInvalid.rawValue)
                completionHandler(error)
            }
        }
    }

    private func startTunnel(with tunnelConfiguration: TunnelConfiguration, completionHandler: @escaping (Error?) -> Void) {
        adapter.start(tunnelConfiguration: tunnelConfiguration) { error in
            if let error = error {
                self.handle(wireGuardAdapterError: error, completionHandler: completionHandler)
                return
            }

            Task {
                await self.handleAdapterStarted()
                completionHandler(nil)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        connectionStatus = .disconnecting
        os_log("Stopping tunnel with reason %{public}@", log: .networkProtection, type: .info, String(describing: reason))

        adapter.stop { error in
            if let error = error {
                os_log("🔵 Failed to stop WireGuard adapter: %{public}@", log: .networkProtection, type: .info, error.localizedDescription)
                return
            }

            Task {
                await self.handleAdapterStopped()
                completionHandler()
            }
        }
    }

    /// Do not cancel, directly... call this method so that the adapter and tester are stopped too.
    private func stopTunnel(with stopError: Error) {
        connectionStatus = .disconnecting

        os_log("Stopping tunnel with error %{public}@", log: .networkProtection, type: .info, stopError.localizedDescription)

        Task {
            await handleAdapterStopped()
        }

        self.adapter.stop { error in
            if let error = error {
                os_log("Error while stopping adapter: %{public}@", log: .networkProtection, type: .info, error.localizedDescription)
            }

            self.cancelTunnelWithError(stopError)
        }
    }

    /// Intentionally not async, so that we won't lock whoever called this method.  This method will race against the tester
    /// to see if it can fix the connection before the next failure.
    ///
    private func fixTunnel() {
        Task {
            let serverSelectionMethod: NetworkProtectionServerSelectionMethod

            if let lastServerName = lastSelectedServerInfo?.name {
                serverSelectionMethod = .avoidServer(serverName: lastServerName)
            } else {
                assertionFailure("We should not have a situation where the VPN is trying to fix the tunnel and there's no previous server info")
                serverSelectionMethod = .automatic
            }

            do {
                try await updateTunnelConfiguration(serverSelectionMethod: serverSelectionMethod)
            } catch {
                return
            }
        }
    }

    private func updateTunnelConfiguration(selectedServer: SelectedNetworkProtectionServer, reassert: Bool = true) async throws {
        let serverSelectionMethod: NetworkProtectionServerSelectionMethod

        switch selectedServerStore.selectedServer {
        case .automatic:
            serverSelectionMethod = .automatic
        case .endpoint(let serverName):
            serverSelectionMethod = .preferredServer(serverName: serverName)
        }

        try await updateTunnelConfiguration(serverSelectionMethod: serverSelectionMethod, reassert: reassert)
    }

    private func updateTunnelConfiguration(serverSelectionMethod: NetworkProtectionServerSelectionMethod, reassert: Bool = true) async throws {

        let tunnelConfiguration = try await generateTunnelConfiguration(serverSelectionMethod: serverSelectionMethod)

        try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Void, Error>) in
            guard let self = self else {
                continuation.resume()
                return
            }

            self.adapter.update(tunnelConfiguration: tunnelConfiguration, reassert: reassert) { error in
                if let error = error {
                    os_log("🔵 Failed to update the configuration: %{public}@", type: .error, error.localizedDescription)
                    continuation.resume(throwing: error)
                    return
                }

                Task {
                    await self.handleAdapterStarted(resumed: false)
                    continuation.resume()
                }
            }
        }
    }

    private func generateTunnelConfiguration(serverSelectionMethod: NetworkProtectionServerSelectionMethod) async throws -> TunnelConfiguration {

        let configurationResult: (TunnelConfiguration, NetworkProtectionServerInfo)

        do {
            let deviceManager = NetworkProtectionDeviceManager(tokenStore: tokenStore,
                                                               keyStore: keyStore,
                                                               errorEvents: networkProtectionDebugEvents)

            configurationResult = try await deviceManager.generateTunnelConfiguration(selectionMethod: serverSelectionMethod)
        } catch {
            throw TunnelError.couldNotGenerateTunnelConfiguration(internalError: error)
        }

        let selectedServerInfo = configurationResult.1
        self.lastSelectedServerInfo = selectedServerInfo

        os_log("🔵 Generated tunnel configuration for server at location: %{public}s (preferred server is %{public}s)",
               log: .networkProtection,
               selectedServerInfo.serverLocation,
               selectedServerInfo.name)

        let tunnelConfiguration = configurationResult.0

        return tunnelConfiguration
    }

    // MARK: - App Messages

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        guard let message = ExtensionMessage(rawValue: messageData[0]) else {
            completionHandler?(nil)
            return
        }

        switch message {
        case .expireRegistrationKey:
            handleExpireRegistrationKey(completionHandler: completionHandler)
        case .getLastErrorMessage:
            handleGetLastErrorMessage(messageData, completionHandler: completionHandler)
        case .getRuntimeConfiguration:
            handleGetRuntimeConfiguration(messageData, completionHandler: completionHandler)
        case .isHavingConnectivityIssues:
            handleIsHavingConnectivityIssues(messageData, completionHandler: completionHandler)
        case .setSelectedServer:
            handleSetSelectedServer(messageData, completionHandler: completionHandler)
        case .getServerLocation:
            handleGetServerLocation(messageData, completionHandler: completionHandler)
        case .getServerAddress:
            handleGetServerAddress(messageData, completionHandler: completionHandler)
        case .setKeyValidity:
            handleSetKeyValidity(messageData, completionHandler: completionHandler)
        case .resetAllState:
            handleResetAllState(messageData, completionHandler: completionHandler)
        }
    }

    // MARK: - App Messages: Handling

    private func handleExpireRegistrationKey(completionHandler: ((Data?) -> Void)? = nil) {
        Task {
            await rekey()
            completionHandler?(nil)
        }
    }

    private func handleResetAllState(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        resetRegistrationKey()

        let serverCache = NetworkProtectionServerListFileSystemStore(errorEvents: nil)
        try? serverCache.removeServerList()
        // This is not really an error, we received a command to reset the connection
        cancelTunnelWithError(nil)
        completionHandler?(nil)
    }

    private func handleGetLastErrorMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        let data = controllerErrorStore.lastErrorMessage?.data(using: ExtensionMessage.preferredStringEncoding)
        completionHandler?(data)
    }

    private func handleGetRuntimeConfiguration(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        adapter.getRuntimeConfiguration { settings in
            var data: Data?
            if let settings = settings {
                data = settings.data(using: .utf8)!
            }
            completionHandler?(data)
        }
    }

    private func handleIsHavingConnectivityIssues(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        let data = Data([tunnelHealth.isHavingConnectivityIssues ? 1 : 0])
        completionHandler?(data)
    }

    private func handleSetSelectedServer(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        Task {
            let remainingData = messageData.suffix(messageData.count - 1)

            guard remainingData.count > 0 else {
                if case .endpoint = selectedServerStore.selectedServer {
                    selectedServerStore.selectedServer = .automatic
                    try? await updateTunnelConfiguration(serverSelectionMethod: .automatic)
                }
                completionHandler?(nil)
                return
            }

            guard let serverName = String(data: remainingData, encoding: ExtensionMessage.preferredStringEncoding) else {

                if case .endpoint = selectedServerStore.selectedServer {
                    selectedServerStore.selectedServer = .automatic
                    try? await updateTunnelConfiguration(serverSelectionMethod: .automatic)
                }
                completionHandler?(nil)
                return
            }

            guard selectedServerStore.selectedServer.stringValue != serverName else {
                completionHandler?(nil)
                return
            }

            selectedServerStore.selectedServer = .endpoint(serverName)
            try? await updateTunnelConfiguration(serverSelectionMethod: .preferredServer(serverName: serverName))
            completionHandler?(nil)
        }
    }

    private func handleGetServerLocation(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        guard let serverLocation = lastSelectedServerInfo?.serverLocation else {
            completionHandler?(nil)
            return
        }

        completionHandler?(serverLocation.data(using: ExtensionMessage.preferredStringEncoding))
    }

    private func handleGetServerAddress(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        guard let endpoint = lastSelectedServerInfo?.endpoint else {
            completionHandler?(nil)
            return
        }

        completionHandler?(endpoint.description.data(using: ExtensionMessage.preferredStringEncoding))
    }

    private func handleSetKeyValidity(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        Task {
            let remainingData = messageData.suffix(messageData.count - 1)

            guard remainingData.count > 0 else {
                setKeyValidity(nil)
                completionHandler?(nil)
                return
            }

            let keyValidity = TimeInterval(remainingData.withUnsafeBytes {
                $0.loadUnaligned(as: UInt.self).littleEndian
            })

            setKeyValidity(keyValidity)
            completionHandler?(nil)
        }
    }

    // MARK: - Adapter start completion handling

    /// Called when the adapter reports that the tunnel was successfully started.
    ///
    private func handleAdapterStarted(resumed: Bool = false) async {
        if !resumed {
            connectionStatus = .connected(connectedDate: Date())
        }

        guard !isKeyExpired else {
            await rekey()
            return
        }

        os_log("🔵 Tunnel interface is %{public}@", log: .networkProtection, type: .info, adapter.interfaceName ?? "unknown")
        Pixel.fire(.networkProtectionActiveUser, frequency: .dailyOnly, includeAppVersionParameter: true)

        if let interfaceName = adapter.interfaceName {
            do {
                try await connectionTester.start(tunnelIfName: interfaceName)
            } catch {
                os_log("🔵 Error: the VPN connection tester could not be started: %{public}@", log: .networkProtection, type: .error, error.localizedDescription)
            }
        } else {
            os_log("🔵 Error: the VPN connection tester could not be started since we could not retrieve the tunnel interface name", log: .networkProtection, type: .error)
        }
    }

    private func handleAdapterStopped() async {
        connectionStatus = .disconnected
        await self.connectionTester.stop()
    }

    /// Called when the adapter reports that the tunnel failed to start with an error.
    ///
    private func handle(wireGuardAdapterError error: WireGuardAdapterError, completionHandler: @escaping (Error?) -> Void) {

        switch error {
        case .cannotLocateTunnelFileDescriptor:
            os_log("🔵 Starting tunnel failed: could not determine file descriptor", log: .networkProtection, type: .error)

            completionHandler(PacketTunnelProviderError.couldNotDetermineFileDescriptor)

        case .dnsResolution(let dnsErrors):
            let hostnamesWithDnsResolutionFailure = dnsErrors.map { $0.address }
                .joined(separator: ", ")
            os_log("🔵 DNS resolution failed for the following hostnames: %{public}@", log: .networkProtection, type: .error, hostnamesWithDnsResolutionFailure)

            completionHandler(PacketTunnelProviderError.dnsResolutionFailure)

        case .setNetworkSettings(let error):
            os_log("🔵 Starting tunnel failed with setTunnelNetworkSettings returning: %{public}@", log: .networkProtection, type: .error, error.localizedDescription)

            completionHandler(PacketTunnelProviderError.couldNotSetNetworkSettings)

        case .startWireGuardBackend(let errorCode):
            os_log("🔵 Starting tunnel failed with wgTurnOn returning: %{public}@", log: .networkProtection, type: .error, errorCode)

            completionHandler(PacketTunnelProviderError.couldNotStartBackend)

        case .invalidState:
            os_log("🔵 Starting tunnel failed with invalid error", log: .networkProtection, type: .error)

            completionHandler(PacketTunnelProviderError.invalidState)
        }
    }

    // MARK: - Computer sleeping

    override func sleep() async {
        os_log("Sleep", log: .networkProtectionSleepLog, type: .info)

        await connectionTester.stop()
    }

    override func wake() {
        os_log("Wake up", log: .networkProtectionSleepLog, type: .info)

        Task {
            await handleAdapterStarted(resumed: true)
        }
    }

    // MARK: - Error Reporting

    private lazy var networkProtectionDebugEvents: EventMapping<NetworkProtectionError>? = .init { [weak self] event, _, _, _ in

        guard let self = self else {
            return
        }

        let domainEvent: NetworkProtectionPixelEvent

#if DEBUG
        // Makes sure we see the assertion failure in the yellow NetP alert.
        self.controllerErrorStore.lastErrorMessage = "[Debug] Error event: \(event.localizedDescription)"

        guard !event.asserts else {
            assertionFailure(event.localizedDescription)
            return
        }
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
