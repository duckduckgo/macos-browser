//
//  TransparentProxyProvider.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import AppInfoRetriever
import Combine
import Foundation
import NetworkExtension
import NetworkProtection
import os.log
import PixelKit
import SystemConfiguration

open class TransparentProxyProvider: NETransparentProxyProvider {

    public enum LoadConfigurationError: CustomNSError {
        case missingConfiguration
        case decodingError(_ error: Error)

        public var errorCode: Int {
            switch self {
            case .missingConfiguration: return 0
            case .decodingError: return 1
            }
        }

        public var errorUserInfo: [String: Any] {
            switch self {
            case .missingConfiguration:
                return [:]
            case .decodingError(let error):
                return [NSUnderlyingErrorKey: error as NSError]
            }
        }
    }

    public enum StartProxyError: CustomNSError {
        case loadConfigurationError(_ error: Error)
        case failedToUpdateNetworkSettings(_ error: Error)

        public var errorCode: Int {
            switch self {
            case .loadConfigurationError: return 0
            case .failedToUpdateNetworkSettings: return 1
            }
        }

        public var errorUserInfo: [String: Any] {
            switch self {
            case .loadConfigurationError(let error),
                    .failedToUpdateNetworkSettings(let error):
                return [NSUnderlyingErrorKey: error as NSError]
            }
        }
    }

    public typealias LoadOptionsCallback = (_ options: [String: Any]?) throws -> Void

    static let dnsPort = 53

    @TCPFlowActor
    private var tcpFlowManagers = Set<TCPFlowManager>()

    @UDPFlowActor
    private var udpFlowManagers = Set<UDPFlowManager>()

    private let monitor = nw_path_monitor_create()
    var directInterface: nw_interface_t?

    private let bMonitor = NWPathMonitor()
    var interface: NWInterface?

    private var cancellables = Set<AnyCancellable>()

    public let configuration: Configuration
    public let settings: TransparentProxySettings

    @MainActor
    public var isRunning = false

    private let appRoutingRulesManager: AppRoutingRulesManager
    private let logger: Logger
    private let appMessageHandler: TransparentProxyAppMessageHandler
    private let eventHandler: TransparentProxyProviderEventHandler

    // MARK: - Init

    public init(settings: TransparentProxySettings,
                configuration: Configuration,
                logger: Logger,
                eventHandler: TransparentProxyProviderEventHandler) {

        appMessageHandler = TransparentProxyAppMessageHandler(settings: settings, logger: logger)
        self.configuration = configuration
        self.logger = logger
        self.settings = settings
        self.eventHandler = eventHandler

        appRoutingRulesManager = AppRoutingRulesManager(settings: settings)

        super.init()

        subscribeToSettings()

        logger.debug("[+] \(String(describing: Self.self), privacy: .public)")
    }

    deinit {
        logger.debug("[-] \(String(describing: Self.self), privacy: .public)")
    }

    private func subscribeToSettings() {
        settings.changePublisher.sink { change in
            switch change {
            case .appRoutingRules:
                Task {
                    try await self.updateNetworkSettings()
                }
            case .excludedDomains:
                Task {
                    try await self.updateNetworkSettings()
                }
            case .proxyAvailable:
                // no-op, handled by app
                break
            }
        }.store(in: &cancellables)
    }

    private func loadProviderConfiguration() throws {
        guard configuration.loadSettingsFromProviderConfiguration else {
            return
        }

        guard let providerConfiguration = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration,
              let encodedSettingsString = providerConfiguration[TransparentProxySettingsSnapshot.key] as? String,
              let encodedSettings = encodedSettingsString.data(using: .utf8) else {

            throw LoadConfigurationError.missingConfiguration
        }

        let snapshot: TransparentProxySettingsSnapshot

        do {
            snapshot = try JSONDecoder().decode(TransparentProxySettingsSnapshot.self, from: encodedSettings)
        } catch {
            throw LoadConfigurationError.decodingError(error)
        }

        settings.apply(snapshot)
    }

    @MainActor
    public func updateNetworkSettings() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task { @MainActor in
                let networkSettings = makeNetworkSettings()
                logger.log("Updating network settings: \(String(describing: networkSettings), privacy: .public)")

                setTunnelNetworkSettings(networkSettings) { [logger] error in
                    if let error {
                        logger.error("Failed to update network settings: \(String(describing: error), privacy: .public)")
                        continuation.resume(throwing: error)
                        return
                    }

                    logger.log("Successfully Updated network settings: \(networkSettings.description, privacy: .public)")
                    continuation.resume()
                }
            }
        }
    }

    private func makeNetworkSettings() -> NETransparentProxyNetworkSettings {
        let networkSettings = NETransparentProxyNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        networkSettings.includedNetworkRules = [
            NENetworkRule(remoteNetwork: nil, remotePrefix: 0, localNetwork: nil, localPrefix: 0, protocol: .TCP, direction: .outbound),
            NENetworkRule(remoteNetwork: nil, remotePrefix: 0, localNetwork: nil, localPrefix: 0, protocol: .UDP, direction: .outbound)
        ]

        if isExcludedDomain("duckduckgo.com") {
            networkSettings.includedNetworkRules?.append(
                NENetworkRule(destinationHost: NWHostEndpoint(hostname: "duckduckgo.com", port: "443"), protocol: .any))
        }

        return networkSettings
    }

    @MainActor
    override open func startProxy(options: [String: Any]? = nil) async throws {

        eventHandler.handle(event: .startAttempt(.begin))

        do {
            do {
                try loadProviderConfiguration()
            } catch {
                throw StartProxyError.loadConfigurationError(error)
            }

            startMonitoringNetworkInterfaces()

            do {
                try await updateNetworkSettings()
            } catch {
                throw StartProxyError.failedToUpdateNetworkSettings(error)
            }

            isRunning = true
            eventHandler.handle(event: .startAttempt(.success))
        } catch {
            eventHandler.handle(event: .startAttempt(.failure(error)))
            throw error
        }
    }

    @MainActor
    open override func stopProxy(with reason: NEProviderStopReason) async {
        stopMonitoringNetworkInterfaces()
        isRunning = false

        eventHandler.handle(event: .stopped(reason))
    }

    @MainActor
    override public func sleep(completionHandler: @escaping () -> Void) {
        eventHandler.handle(event: .sleep)
        stopMonitoringNetworkInterfaces()
        completionHandler()
    }

    @MainActor
    override public func wake() {
        eventHandler.handle(event: .wake)
        startMonitoringNetworkInterfaces()
    }

    private func logFlowMessage(_ flow: NEAppProxyFlow, level: OSLogType, message: String) {
        logger.log(
            level: level,
            """
            \(message, privacy: .public)
            - remote: \(String(reflecting: flow.remoteHostname), privacy: .public)
            - flowID: \(String(reflecting: flow.metaData.filterFlowIdentifier?.uuidString), privacy: .public)
            - appID: \(String(reflecting: flow.metaData.sourceAppSigningIdentifier), privacy: .public)
            """
        )
    }

    private func logNewTCPFlow(_ flow: NEAppProxyFlow) {
        logFlowMessage(
            flow,
            level: .debug,
            message: "[TCP] New flow: \(String(reflecting: flow))")
    }

    private func logFlowHandlingFailure(_ flow: NEAppProxyFlow, message: String) {
        logFlowMessage(
            flow,
            level: .error,
            message: "[TCP] Failure handling flow: \(message)")
    }

    override public func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        logNewTCPFlow(flow)

        guard let flow = flow as? NEAppProxyTCPFlow else {
            logFlowHandlingFailure(flow, message: "Expected a TCP flow, but got something else.  We're ignoring the flow.")
            return false
        }

        guard let remoteEndpoint = flow.remoteEndpoint as? NWHostEndpoint else {
            logFlowHandlingFailure(flow, message: "No remote endpoint.  We're ignoring the flow.")
            return false
        }

        guard !isDnsServer(remoteEndpoint) else {
            logFlowHandlingFailure(flow, message: "DNS resolver endpoint.  We're ignoring the flow.")
            return false
        }

        guard let interface else {
            logger.error("[TCP: \(String(describing: flow), privacy: .public)] Expected an interface to exclude traffic through")
            return false
        }

        switch path(for: flow) {
        case .block(let reason):
            switch reason {
            case .appRule:
                logger.debug("[TCP: \(String(describing: flow), privacy: .public)] Blocking traffic due to app rule")
            case .domainRule:
                logger.debug("[TCP: \(String(describing: flow), privacy: .public)] Blocking traffic due to domain rule")
            }
        case .excludeFromVPN(let reason):
            switch reason {
            case .appRule:
                logger.debug("[TCP: \(String(describing: flow), privacy: .public)] Excluding traffic due to app rule")
            case .domainRule:
                logger.debug("[TCP: \(String(describing: flow), privacy: .public)] Excluding traffic due to domain rule")
            }
        case .routeThroughVPN:
            return false
        }

        flow.networkInterface = directInterface

        Task { @TCPFlowActor in
            let flowManager = TCPFlowManager(flow: flow, logger: logger)
            tcpFlowManagers.insert(flowManager)

            try? await flowManager.start(interface: interface)
            tcpFlowManagers.remove(flowManager)

            logFlowMessage(flow, level: .default, message: "[TCP] Flow completed")
        }

        return true
    }

    override public func handleNewUDPFlow(_ flow: NEAppProxyUDPFlow, initialRemoteEndpoint remoteEndpoint: NWEndpoint) -> Bool {

        guard let remoteEndpoint = remoteEndpoint as? NWHostEndpoint,
              !isDnsServer(remoteEndpoint) else {
            return false
        }

        let printableRemote = remoteEndpoint.hostname

        logger.log(
            level: .debug,
            """
            [UDP] New flow: \(String(describing: flow), privacy: .public)
            - remote: \(printableRemote, privacy: .public)
            - flowID: \(String(describing: flow.metaData.filterFlowIdentifier?.uuidString), privacy: .public)
            - appID: \(String(describing: flow.metaData.sourceAppSigningIdentifier), privacy: .public)
            """)

        guard let interface else {
            logger.error("[UDP: \(String(describing: flow), privacy: .public)] Expected an interface to exclude traffic through")
            return false
        }

        switch path(for: flow) {
        case .block(let reason):
            switch reason {
            case .appRule:
                logger.debug("[UDP: \(String(describing: flow), privacy: .public)] Blocking traffic due to app rule")
            case .domainRule:
                logger.debug("[UDP: \(String(describing: flow), privacy: .public)] Blocking traffic due to domain rule")
            }
        case .excludeFromVPN(let reason):
            switch reason {
            case .appRule:
                logger.debug("[UDP: \(String(describing: flow), privacy: .public)] Excluding traffic due to app rule")
            case .domainRule:
                logger.debug("[UDP: \(String(describing: flow), privacy: .public)] Excluding traffic due to domain rule")
            }
        case .routeThroughVPN:
            return false
        }

        flow.networkInterface = directInterface

        Task { @UDPFlowActor in
            let flowManager = UDPFlowManager(flow: flow)
            udpFlowManagers.insert(flowManager)

            try? await flowManager.start(interface: interface)
            udpFlowManagers.remove(flowManager)
        }

        return true
    }

    // MARK: - Path Monitors

    @MainActor
    private func startMonitoringNetworkInterfaces() {
        bMonitor.pathUpdateHandler = { [weak self, logger] path in
            logger.log("Available interfaces updated: \(String(reflecting: path.availableInterfaces), privacy: .public)")

            self?.interface = path.availableInterfaces.first { interface in
                interface.type != .other
            }
        }
        bMonitor.start(queue: .main)

        nw_path_monitor_set_queue(monitor, .main)
        nw_path_monitor_set_update_handler(monitor) { [weak self, logger] path in
            guard let self else { return }

            let interfaces = SCNetworkInterfaceCopyAll()
            logger.log("Available interfaces updated: \(String(reflecting: interfaces), privacy: .public)")

            nw_path_enumerate_interfaces(path) { interface in
                guard nw_interface_get_type(interface) != nw_interface_type_other else {
                    return true
                }

                self.directInterface = interface
                return false
            }
        }

        nw_path_monitor_start(monitor)
    }

    @MainActor
    private func stopMonitoringNetworkInterfaces() {
        bMonitor.cancel()
        nw_path_monitor_cancel(monitor)
    }

    // MARK: - Ignoring DNS flows

    private func isDnsServer(_ endpoint: NWHostEndpoint) -> Bool {
        Int(endpoint.port) == Self.dnsPort
    }

    // MARK: - VPN exclusions logic

    private enum FlowPath {
        case block(dueTo: Reason)
        case excludeFromVPN(dueTo: Reason)
        case routeThroughVPN

        enum Reason {
            case appRule
            case domainRule
        }
    }

    private func path(for flow: NEAppProxyFlow) -> FlowPath {
        let appIdentifier = flow.metaData.sourceAppSigningIdentifier

        switch appRoutingRulesManager.rules[appIdentifier] {
        case .none:
            if let hostname = flow.remoteHostname,
               isExcludedDomain(hostname) {
                return .excludeFromVPN(dueTo: .domainRule)
            }

            return .routeThroughVPN
        case .block:
            return .block(dueTo: .appRule)
        case .exclude:
            return .excludeFromVPN(dueTo: .appRule)
        }
    }

    private func isExcludedDomain(_ hostname: String) -> Bool {
        settings.excludedDomains.contains { excludedDomain in
            hostname.hasSuffix(excludedDomain)
        }
    }

    // MARK: - Communication with App

    override public func handleAppMessage(_ messageData: Data) async -> Data? {
        await appMessageHandler.handle(messageData)
    }
}

// MARK: - Events & Pixels

extension TransparentProxyProvider {
    public enum Event {
        case startAttempt(_ step: StartAttemptStep)
        case stopped(_ reason: NEProviderStopReason)
        case sleep
        case wake
    }

    public enum StartAttemptStep: PixelKitEventV2 {
        /// Attempt to start the proxy begins
        case begin

        /// Attempt to start the proxy succeeds
        case success

        /// Attempt to start the proxy fails
        case failure(_ error: Error)

        public var name: String {
            switch self {
            case .begin:
                return "vpn_proxy_provider_start_attempt"

            case .success:
                return "vpn_proxy_provider_start_success"

            case .failure:
                return "vpn_proxy_provider_start_failure"
            }
        }

        public var parameters: [String: String]? {
            return nil
        }

        public var error: Error? {
            switch self {
            case .begin,
                    .success:
                return nil
            case .failure(let error):
                return error
            }
        }
    }
}
