// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import Common
import Foundation
import NetworkExtension
import NetworkProtection
import os
import PixelKit
import UserNotifications

final class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: - Error Handling

    enum TunnelError: LocalizedError {
        case couldNotGenerateTunnelConfiguration(internalError: Error)
        case couldNotFixConnection

        var errorDescription: String? {
            switch self {
            case .couldNotGenerateTunnelConfiguration(let internalError):
                return "Failed to generate a tunnel configuration: \(internalError.localizedDescription)"
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

    // MARK: - Distributed Notifications

    private var distributedNotificationCenter = DistributedNotificationCenter.forType(.networkProtection)

    // MARK: - Server Selection

    let selectedServerStore = NetworkProtectionSelectedServerUserDefaultsStore()

    var lastSelectedServerInfo: NetworkProtectionServerInfo? {
        didSet {
            guard lastSelectedServerInfo != nil else {
                return
            }

            distributedNotificationCenter.postNotificationName(.NetPServerSelected, object: nil, userInfo: nil, options: [.deliverImmediately, .postToAllSessions])
        }
    }

    // MARK: - User Notifications

    private let notificationsPresenter: NetworkProtectionNotificationsPresenter = {
#if NETP_SYSTEM_EXTENSION
        NetworkProtectionIPCNotificationsPresenter()
#else
        NetworkProtectionUNNotificationsPresenter()
#endif
    }()

    // MARK: - Connection testing & reassertion

    private lazy var connectionTester: NetworkProtectionConnectionTester = {
        NetworkProtectionConnectionTester { [weak self] result in
            guard let self = self else {
                return
            }

            switch result {
            case .connected:
                self.tunnelHealth.isHavingConnectivityIssues = false
            case .reconnected:
                self.tunnelHealth.isHavingConnectivityIssues = false
                self.notificationsPresenter.showReconnectedNotification()
                self.reasserting = false
            case .disconnected(let failureCount):
                self.tunnelHealth.isHavingConnectivityIssues = true

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
    private var lastTestFailed = false
    private let tunnelHealth = NetworkProtectionTunnelHealthStore()
    private let controllerErrorStore = NetworkProtectionTunnelErrorStore()

    // MARK: - Initializers

    override init() {
        os_log("🔵 Initializing NetP packet tunnel provider", log: .networkProtection, type: .error)

        super.init()

        #if NETP_SYSTEM_EXTENSION
        IPCConnection.shared.startListener()
        #endif
    }

    private func setupPixels(userAgent: String, baseURL: String) {
        let dryRun: Bool
#if DEBUG
        dryRun = true
#else
        dryRun = false
#endif

        Pixel.setUp(dryRun: dryRun, userAgent: userAgent, log: .networkProtection) { (pixelName: String, headers: [String: String], parameters: [String: String], allowedQueryReservedCharacters: CharacterSet?, callBackOnMainThread: Bool, onComplete: @escaping (Error?) -> Void) in

            let url = URL.pixelUrl(forPixelNamed: pixelName)
            APIRequest.request(
                url: url,
                parameters: parameters,
                allowedQueryReservedCharacters: allowedQueryReservedCharacters,
                headers: headers,
                callBackOnMainThread: callBackOnMainThread
            ) { (_, error) in
                onComplete(error)
            }
        }
    }

    private var tunnelProviderProtocol: NETunnelProviderProtocol? {
        protocolConfiguration as? NETunnelProviderProtocol
    }

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let activationAttemptId = options?["activationAttemptId"] as? String

        if let userAgent = options?["userAgent"] as? String,
           let pixelBaseURL = options?["pixelBaseURL"] as? String {

            setupPixels(userAgent: userAgent, baseURL: pixelBaseURL)
        }

        tunnelHealth.isHavingConnectivityIssues = false
        controllerErrorStore.lastErrorMessage = nil

        if let serverName = options?["selectedServer"] as? String {
            selectedServerStore.selectedServer = .endpoint(serverName)
        }

        os_log("🔵 Starting tunnel from the %{public}@", log: .networkProtection, type: .info, activationAttemptId == nil ? "OS directly, rather than the app" : "app")
        // - TODO: We could also add other conditions for updating the server, such as an expiration timestamp.

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

            self.handleAdapterStarted()
            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("🔵 Stopping tunnel", log: .networkProtection, type: .info)

        adapter.stop { error in
            if let error = error {
                os_log("🔵 Failed to stop WireGuard adapter: %{public}@", log: .networkProtection, type: .info, error.localizedDescription)
                return
            }

            self.connectionTester.stop()

            completionHandler()

            #if os(macOS)
            // HACK: This is a filthy hack to work around Apple bug 32073323 (dup'd by us as 47526107).
            // Remove it when they finally fix this upstream and the fix has been rolled out to
            // sufficient quantities of users.
            exit(0)
            #endif
        }
    }

    /// Do not cancel, directly... call this method so that the adapter and tester are stopped too.
    private func stopTunnel(with stopError: Error) {
        self.connectionTester.stop()
        self.adapter.stop { error in
            if let error = error {
                os_log("🔵 Error while stopping adapter: %{public}@", log: .networkProtection, type: .info, error.localizedDescription)
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

    private func updateTunnelConfiguration(serverSelectionMethod: NetworkProtectionServerSelectionMethod) async throws {
        let tunnelConfiguration = try await generateTunnelConfiguration(serverSelectionMethod: serverSelectionMethod)

        self.adapter.update(tunnelConfiguration: tunnelConfiguration) { error in
            if let error = error {
                os_log("🔵 Failed to update the configuration: %{public}@", type: .error, error.localizedDescription)
                return
            }
        }
    }

    private func generateTunnelConfiguration(serverSelectionMethod: NetworkProtectionServerSelectionMethod) async throws -> TunnelConfiguration {

        os_log("🔵 serverSelectionMethod %{public}@", String(describing: serverSelectionMethod))

        let configurationResult: (TunnelConfiguration, NetworkProtectionServerInfo)

        do {
            let keyStore = NetworkProtectionKeychainStore(useSystemKeychain: NetworkProtectionBundle.usesSystemKeychain(),
                                                          errorEvents: networkProtectionDebugEvents)
            let deviceManager = NetworkProtectionDeviceManager(keyStore: keyStore,
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

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        os_log("🔵 App message received ", log: .networkProtection, type: .info)

        guard let request = NetworkProtectionAppRequest(rawValue: messageData[0]) else {
            completionHandler?(nil)
            return
        }

        switch request {
        case .resetAllState:
            handleResetAllState(messageData, completionHandler: completionHandler)
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
        }
    }

    private func handleResetAllState(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        NetworkProtectionKeychain.deleteReferences()
        let serverCache = NetworkProtectionServerListFileSystemStore()
        try? serverCache.removeServerList()
        // This is not really an error, we received a command to reset the connection
        cancelTunnelWithError(nil)
        completionHandler?(nil)
    }

    private func handleGetLastErrorMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        let data = controllerErrorStore.lastErrorMessage?.data(using: NetworkProtectionAppRequest.preferredStringEncoding)
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

            guard let serverName = String(data: remainingData, encoding: NetworkProtectionAppRequest.preferredStringEncoding) else {

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
        }
    }

    private func handleGetServerLocation(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        guard let serverLocation = lastSelectedServerInfo?.serverLocation else {
            completionHandler?(nil)
            return
        }

        completionHandler?(serverLocation.data(using: NetworkProtectionAppRequest.preferredStringEncoding))
    }

    private func handleGetServerAddress(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        guard let serverAddress = lastSelectedServerInfo?.serverAddresses.first else {
            completionHandler?(nil)
            return
        }

        completionHandler?(serverAddress.data(using: NetworkProtectionAppRequest.preferredStringEncoding))
    }

    // MARK: - Adapter start completion handling

    private var testerStartRetryTimer: DispatchSourceTimer?

    /// Called when the adapter reports that the tunnel was successfully started.
    ///
    private func handleAdapterStarted() {
        os_log("🔵 Tunnel interface is %{public}@", log: .networkProtection, type: .info, adapter.interfaceName ?? "unknown")

        if let interfaceName = adapter.interfaceName {
            connectionTester.start(tunnelIfName: interfaceName)
        } else {
            os_log("🔵 Error: the VPN connection tester could not be started since we could not retrieve the tunnel interface name", log: .networkProtection, type: .error)
        }
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

    override func sleep(completionHandler: @escaping () -> Void) {
        connectionTester.stop()
    }

    override func wake() {
        handleAdapterStarted()
    }

    // MARK: - Error Reporting

    private lazy var networkProtectionDebugEvents: EventMapping<NetworkProtectionError>? = .init { event, _, _, _ in
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

        // NetworkProtectionServerListStoreError
            
        case .failedToEncodeServerList:
            domainEvent = .networkProtectionServerListStoreFailedToEncodeServerList
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
        case .keychainDeleteError(let field, let status):
            domainEvent = .networkProtectionKeychainDeleteError(field: field, status: status)

        case .unhandledError(function: let function, line: let line, error: let error):
            domainEvent = .networkProtectionUnhandledError(function: function, line: line, error: error)
        }

        os_log("🔴 Firing pixel: %{public}@", log: .networkProtection, type: .info, String(describing: domainEvent))
        Pixel.fire(domainEvent, includeAppVersionParameter: true)
    }
}

extension WireGuardLogLevel {
    var osLogLevel: OSLogType {
        switch self {
        case .verbose:
            return .debug
        case .error:
            return .error
        }
    }
}
