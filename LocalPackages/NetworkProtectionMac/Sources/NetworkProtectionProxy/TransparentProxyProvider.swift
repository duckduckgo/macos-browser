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

/// A private global actor to handle UDP flows management
///
@globalActor
struct UDPFlowActor {
    actor ActorType { }

    static let shared: ActorType = ActorType()
}

open class TransparentProxyProvider: NETransparentProxyProvider {

    public enum StartError: Error {
        case missingVendorOptions
    }

    public typealias LoadOptionsCallback = (_ options: [String: Any]?) throws -> Void

    var tcpFlowManagers = Set<TCPFlowManager>()

    @UDPFlowActor
    var udpFlowManagers = Set<UDPFlowManager>()

    private let monitor = nw_path_monitor_create()
    var directInterface: nw_interface_t?

    private let bMonitor = NWPathMonitor()
    var interface: NWInterface?

    public let configuration: Configuration
    public let settings: TransparentProxySettings
    public var tunnelConfiguration: TunnelConfiguration?

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

            throw StartError.missingVendorOptions
        }

        let snapshot = try JSONDecoder().decode(TransparentProxySettingsSnapshot.self, from: encodedSettings)
        settings.apply(snapshot)
    }

    @MainActor
    public func updateNetworkSettings() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in

            let networkSettings = makeNetworkSettings()
            logger.log("Updating network settings: \(String(describing: networkSettings), privacy: .public)")

            setTunnelNetworkSettings(networkSettings) { [logger] error in
                if let error {
                    logger.error("Failed to update network settings: \(String(describing: error), privacy: .public)")
                    continuation.resume(throwing: error)
                    return
                }

                logger.log("Successfully Updated network settings: \(String(describing: error), privacy: .public))")
                continuation.resume()
            }
        }
    }

    private func makeNetworkSettings() -> NETransparentProxyNetworkSettings {
        let networkSettings = NETransparentProxyNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        if let tunnelConfiguration {
            let networkRules = tunnelConfiguration.interface.dns.map { dnsServer in
                logger.log("Adding DNS server: \(dnsServer.stringRepresentation, privacy: .public))")
                return NENetworkRule(destinationNetwork: .init(hostname: dnsServer.stringRepresentation, port: "0"), prefix: 32, protocol: .any)
            }

            networkSettings.excludedNetworkRules = networkRules
        }

        networkSettings.includedNetworkRules = [
            NENetworkRule(remoteNetwork: NWHostEndpoint(hostname: "127.0.0.1", port: ""), remotePrefix: 0, localNetwork: nil, localPrefix: 0, protocol: .any, direction: .outbound)
        ]

        return networkSettings
    }

    override public func startProxy(options: [String: Any]?,
                                    completionHandler: @escaping (Error?) -> Void) {

        logger.log(
            """
            Starting proxy\n
            > configuration: \(String(describing: self.configuration), privacy: .public)\n
            > options: \(String(describing: options), privacy: .public)
            """)

        do {
            try loadProviderConfiguration()
        } catch {
            logger.error("Failed to load provider configuration, bailing out: \(String(reflecting: error), privacy: .public)")
            completionHandler(error)
            return
        }

        Task { @MainActor in
            do {
                startMonitoringNetworkInterfaces()

                try await updateNetworkSettings()
                logger.log("Proxy started successfully")
                completionHandler(nil)
            } catch {
                logger.error("Proxy failed to start \(String(reflecting: error), privacy: .public)")
                completionHandler(error)
            }
        }
    }

    override public func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.log("Stopping proxy with reason: \(String(reflecting: reason), privacy: .public)")

        Task { @MainActor in
            stopMonitoringNetworkInterfaces()
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

        let printableRemote = flow.remoteHostname ?? (flow.remoteEndpoint as? NWHostEndpoint)?.hostname ?? "unknown"

        logger.debug(
            """
            [TCP] New flow: \(String(describing: flow), privacy: .public)
            - remote: \(printableRemote, privacy: .public)
            - flowID: \(String(describing: flow.metaData.filterFlowIdentifier?.uuidString), privacy: .public)
            - appID: \(String(describing: flow.metaData.sourceAppSigningIdentifier), privacy: .public)
            """)

        guard !settings.dryMode else {
            logger.debug("[TCP: \(String(describing: flow), privacy: .public)] Ignoring flow as proxy is running in dry mode")
            return false
        }

        guard let interface else {
            logger.error("[TCP: \(String(describing: flow), privacy: .public)] Expected an interface to exclude traffic through")
            return false
        }

        switch path(for: flow) {
        case .throughVPN:
            return false
        case .excludedFromVPN(let reason):
            switch reason {
            case .appIsExcluded(let bundleID):
                logger.debug("[TCP: \(String(describing: flow), privacy: .public)] Proxying traffic due to app exclusion")
            case .domainIsExcluded(let domain):
                logger.debug("[TCP: \(String(describing: flow), privacy: .public)] Proxying traffic due to domain exclusion")
            }
        }

        flow.networkInterface = directInterface

        Task { @MainActor in
            let flowManager = TCPFlowManager(flow: flow)
            tcpFlowManagers.insert(flowManager)

            try? await flowManager.start(interface: interface)
            tcpFlowManagers.remove(flowManager)
        }

        return true
    }

    override public func handleNewUDPFlow(_ flow: NEAppProxyUDPFlow, initialRemoteEndpoint remoteEndpoint: NWEndpoint) -> Bool {

        let printableRemote = (remoteEndpoint as? NWHostEndpoint)?.hostname ?? "unknown"

        logger.log(
            """
            [UDP] New flow: \(String(describing: flow), privacy: .public)
            - remote: \(printableRemote, privacy: .public)
            - flowID: \(String(describing: flow.metaData.filterFlowIdentifier?.uuidString), privacy: .public)
            - appID: \(String(describing: flow.metaData.sourceAppSigningIdentifier), privacy: .public)
            """)

        guard !settings.dryMode else {
            logger.debug("[UDP: \(String(describing: flow), privacy: .public)] Ignoring flow as proxy is running in dry mode")
            return false
        }

        guard let interface else {
            logger.error("[UDP: \(String(describing: flow), privacy: .public)] Expected an interface to exclude traffic through")
            return false
        }

        switch path(for: flow) {
        case .throughVPN:
            return false
        case .excludedFromVPN(let reason):
            switch reason {
            case .appIsExcluded(let bundleID):
                logger.debug("[UDP: \(String(describing: flow), privacy: .public)] Proxying traffic due to app exclusion")
            case .domainIsExcluded(let domain):
                logger.debug("[UDP: \(String(describing: flow), privacy: .public)] Proxying traffic due to domain exclusion")
            }
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

    // MARK: - VPN exclusions logic

    private enum FlowPath {
        case throughVPN
        case excludedFromVPN(reason: ExclusionReason)

        enum ExclusionReason {
            case appIsExcluded(bundleID: String)
            case domainIsExcluded(_ domain: String)
        }
    }

    private func path(for flow: NEAppProxyFlow) -> FlowPath {
        guard !isFromExcludedApp(flow) else {
            return .excludedFromVPN(reason: .appIsExcluded(bundleID: flow.metaData.sourceAppSigningIdentifier))
        }

        if let hostname = flow.remoteHostname,
           isExcludedDomain(hostname) {
            return .excludedFromVPN(reason: .domainIsExcluded(hostname))
        }

        return .throughVPN
    }

    private func isFromExcludedApp(_ flow: NEAppProxyFlow) -> Bool {
        if settings.excludeDBP
            && flow.metaData.sourceAppSigningIdentifier == configuration.dbpAgentBundleID {
            return true
        }

        for app in settings.excludedApps where flow.metaData.sourceAppSigningIdentifier == app.bundleID {
            return true
        }

        return false
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
