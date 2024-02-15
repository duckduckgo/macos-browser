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

import Foundation
import NetworkExtension
import NetworkProtection
import os.log // swiftlint:disable:this enforce_os_log_wrapper
import SystemConfiguration

open class TransparentProxyProvider: NETransparentProxyProvider {

    public enum StartError: Error {
        case missingProviderConfiguration
        case failedToUpdateNetworkSettings(underlyingError: Error)
    }

    public typealias EventCallback = (Event) -> Void
    public typealias LoadOptionsCallback = (_ options: [String: Any]?) throws -> Void

    static let dnsPort = 53

    @TCPFlowActor
    var tcpFlowManagers = Set<TCPFlowManager>()

    @UDPFlowActor
    var udpFlowManagers = Set<UDPFlowManager>()

    private let monitor = nw_path_monitor_create()
    var directInterface: nw_interface_t?

    private let bMonitor = NWPathMonitor()
    var interface: NWInterface?

    public let configuration: Configuration
    public let settings: TransparentProxySettings

    @MainActor
    public var isRunning = false

    public var eventHandler: EventCallback?
    private let logger: Logger

    private lazy var appMessageHandler = TransparentProxyAppMessageHandler(settings: settings)

    // MARK: - Init

    public init(settings: TransparentProxySettings,
                configuration: Configuration,
                logger: Logger) {

        self.configuration = configuration
        self.logger = logger
        self.settings = settings

        logger.debug("[+] \(String(describing: Self.self), privacy: .public)")
    }

    deinit {
        logger.debug("[-] \(String(describing: Self.self), privacy: .public)")
    }

    private func loadProviderConfiguration() throws {
        guard configuration.loadSettingsFromProviderConfiguration else {
            return
        }

        guard let providerConfiguration = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration,
              let encodedSettingsString = providerConfiguration[TransparentProxySettingsSnapshot.key] as? String,
              let encodedSettings = encodedSettingsString.data(using: .utf8) else {

            throw StartError.missingProviderConfiguration
        }

        let snapshot = try JSONDecoder().decode(TransparentProxySettingsSnapshot.self, from: encodedSettings)
        settings.apply(snapshot)
    }

    @MainActor
    public func updateNetworkSettings() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task { @MainActor in
                let networkSettings = makeNetworkSettings()
                logger.log("Updating network settings: \(String(describing: networkSettings), privacy: .public)")

                setTunnelNetworkSettings(networkSettings) { [eventHandler, logger] error in
                    if let error {
                        logger.error("Failed to update network settings: \(String(describing: error), privacy: .public)")
                        eventHandler?(.failedToUpdateNetworkSettings(error))
                        continuation.resume(throwing: error)
                        return
                    }

                    logger.log("Successfully Updated network settings: \(String(describing: error), privacy: .public))")
                    continuation.resume()
                }
            }
        }
    }

    private func makeNetworkSettings() -> NETransparentProxyNetworkSettings {
        let networkSettings = NETransparentProxyNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        networkSettings.includedNetworkRules = [
            NENetworkRule(remoteNetwork: NWHostEndpoint(hostname: "127.0.0.1", port: ""), remotePrefix: 0, localNetwork: nil, localPrefix: 0, protocol: .any, direction: .outbound)
        ]

        return networkSettings
    }

    override public func startProxy(options: [String: Any]?,
                                    completionHandler: @escaping (Error?) -> Void) {

        eventHandler?(.startInitiated)

        logger.log(
            """
            Starting proxy\n
            > configuration: \(String(describing: self.configuration), privacy: .public)\n
            > settings: \(String(describing: self.settings), privacy: .public)\n
            > options: \(String(describing: options), privacy: .public)
            """)

        do {
            try loadProviderConfiguration()
        } catch {
            logger.error("Failed to load provider configuration, bailing out")
            eventHandler?(.startFailure(error))
            completionHandler(error)
            return
        }

        Task { @MainActor in
            do {
                startMonitoringNetworkInterfaces()

                try await updateNetworkSettings()
                logger.log("Proxy started successfully")
                isRunning = true
                eventHandler?(.startSuccess)
                completionHandler(nil)
            } catch {
                let error = StartError.failedToUpdateNetworkSettings(underlyingError: error)
                logger.error("Proxy failed to start \(String(reflecting: error), privacy: .public)")
                eventHandler?(.startFailure(error))
                completionHandler(error)
            }
        }
    }

    override public func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.log("Stopping proxy with reason: \(String(reflecting: reason), privacy: .public)")

        Task { @MainActor in
            stopMonitoringNetworkInterfaces()
            isRunning = false
            completionHandler()
        }
    }

    override public func sleep(completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            stopMonitoringNetworkInterfaces()
            logger.log("The proxy is now sleeping")
            completionHandler()
        }
    }

    override public func wake() {
        Task { @MainActor in
            logger.log("The proxy is now awake")
            startMonitoringNetworkInterfaces()
        }
    }

    override public func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        guard let flow = flow as? NEAppProxyTCPFlow else {
            logger.info("Expected a TCP flow, but got something else.  We're ignoring it.")
            return false
        }

        guard let remoteEndpoint = flow.remoteEndpoint as? NWHostEndpoint,
              !isDnsServer(remoteEndpoint) else {
            return false
        }

        let printableRemote = flow.remoteHostname ?? (flow.remoteEndpoint as? NWHostEndpoint)?.hostname ?? "unknown"

        logger.debug(
            """
            [TCP] New flow: \(String(describing: flow), privacy: .public)
            - remote: \(printableRemote, privacy: .public)
            - flowID: \(String(describing: flow.metaData.filterFlowIdentifier?.uuidString), privacy: .public)
            - appID: \(String(describing: flow.metaData.sourceAppSigningIdentifier), privacy: .public)
            """)

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
            let flowManager = TCPFlowManager(flow: flow)
            tcpFlowManagers.insert(flowManager)

            try? await flowManager.start(interface: interface)
            tcpFlowManagers.remove(flowManager)
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

        switch settings.appRoutingRules[appIdentifier] {
        case .none:
            if let hostname = flow.remoteHostname,
               isExcludedDomain(hostname) {
                return .excludeFromVPN(dueTo: .domainRule)
            }

            return .routeThroughVPN
        case .block:
            return .block(dueTo: .appRule)
        case .exclude:
            return .excludeFromVPN(dueTo: .domainRule)
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
