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
import OSLog // swiftlint:disable:this enforce_os_log_wrapper
import SystemConfiguration

open class TransparentProxyProvider: NETransparentProxyProvider {

    public enum StartError: Error {
        case missingVendorOptions
    }

    public typealias LoadOptionsCallback = (_ options: [String: Any]?) throws -> Void

    var tcpFlowManagers = Set<TCPFlowManager>()
    var udpFlowManagers = Set<UDPFlowManager>()

    private let monitor = nw_path_monitor_create()
    var directInterface: nw_interface_t?

    private let bMonitor = NWPathMonitor()
    var interface: NWInterface?

    public let configuration: Configuration
    public let settings: TransparentProxySettings

    // MARK: - Init

    public init(settings: TransparentProxySettings,
                configuration: Configuration) {

        self.configuration = configuration
        self.settings = settings
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

    private func makeNetworkSettings() -> NETransparentProxyNetworkSettings {
        let networkSettings = NETransparentProxyNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        networkSettings.excludedNetworkRules = [
            // We want to make sure DNS queries are still resolved through the VPN
            // This will need to be updated dynamically by the VPN.
            NENetworkRule(destinationNetwork: .init(hostname: "10.11.12.1", port: "0"), prefix: 32, protocol: .any)
        ]

        networkSettings.includedNetworkRules = [
            NENetworkRule(remoteNetwork: NWHostEndpoint(hostname: "127.0.0.1", port: ""), remotePrefix: 0, localNetwork: nil, localPrefix: 0, protocol: .TCP, direction: .outbound)
            //NENetworkRule(destinationNetwork: NWHostEndpoint(hostname: "0.0.0.0", port: "443"), prefix: 0, protocol: .TCP),
            //NENetworkRule(destinationNetwork: NWHostEndpoint(hostname: "0.0.0.0", port: "80"), prefix: 0, protocol: .TCP),
            //NENetworkRule(destinationHost: NWHostEndpoint(hostname: "google.com", port: "0"), protocol: .TCP)
            //NENetworkRule(destinationHost: .init(hostname: "google.com", port: "443"), protocol: .TCP)
        ]

        //let tunnelSettings = NETunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        return networkSettings
    }

    override public func startProxy(options: [String: Any]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("🤌 Starting tunnel\n> configuration: %{public}@\n> options: %{public}@",
               String(describing: configuration),
               String(describing: options))

        do {
            try loadProviderConfiguration()
        } catch {
            completionHandler(error)
            return
        }

        bMonitor.pathUpdateHandler = { [weak self] path in
            self?.interface = path.availableInterfaces.first { interface in
                interface.type != .other
            }
        }
        bMonitor.start(queue: .main)

        nw_path_monitor_set_queue(monitor, .main)
        nw_path_monitor_set_update_handler(monitor) { [weak self] path in
            guard let self else { return }

            let interfaces = SCNetworkInterfaceCopyAll()
            os_log("🤌 All available interfaces %{public}@", String(reflecting: interfaces))

            nw_path_enumerate_interfaces(path) { interface in
                guard nw_interface_get_type(interface) != nw_interface_type_other else {
                    return true
                }

                self.directInterface = interface
                return false
            }
        }

        nw_path_monitor_start(monitor)

        os_log("🤌 Starting up tunnel")
        setTunnelNetworkSettings(makeNetworkSettings()) { error in
            if let applyError = error {
                os_log("🤌 Failed to apply proxy settings: %{public}@", applyError.localizedDescription)
            }

            //os_log("🤌 Included network rules are %{public}@", String(describing: proxySettings.includedNetworkRules?.debugDescription))
            os_log("🤌 Setup Done!")

            completionHandler(error)
        }
    }

    override public func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        os_log("🤌 Stopped")
        completionHandler()
    }

    override public func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }

    override public func wake() {
        // Add code here to wake up.
    }

    override public func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {

        let printableRemote = flow.remoteHostname ?? ((flow as? NEAppProxyTCPFlow)?.remoteEndpoint as? NWHostEndpoint)?.hostname ?? "unknown"

        os_log("🤌 [TCP] remote: %{public}@ - flowID: %{public}@ - appID: %{public}@)",
               printableRemote,
               String(describing: flow.metaData.filterFlowIdentifier?.uuidString),
               String(describing: flow.metaData.sourceAppSigningIdentifier))

        guard !settings.dryMode else {
            return false
        }

        //os_log("🤌 New flow to %{public}@", String(describing: flow.remoteHostname))
        //os_log("🤌 Metadata %{public}@", String(describing: flow.metaData))

        guard isFromExcludedApp(flow) else {
            //os_log("🤌 Ignoring app!")
            return false
        }
        os_log("🤌 New flow to %{public}@", String(describing: flow.remoteHostname))

        flow.networkInterface = directInterface

        guard let interface else {
            os_log("🤌  I don't have an interface to work with!")
            return false
        }

        guard let tcpFlow = flow as? NEAppProxyTCPFlow else {
            return false
        }

        let flowManager = TCPFlowManager(flow: tcpFlow)
        tcpFlowManagers.insert(flowManager)

        Task {
            await flowManager.start(interface: interface)
            tcpFlowManagers.remove(flowManager)
        }

        return true
    }

    override public func handleNewUDPFlow(_ flow: NEAppProxyUDPFlow, initialRemoteEndpoint remoteEndpoint: NWEndpoint) -> Bool {

        let printableRemote = (remoteEndpoint as? NWHostEndpoint)?.hostname ?? "unknown"

        os_log("🤌 [UDP] remote: %{public}@ - flowID: %{public}@ - appID: %{public}@)",
               (remoteEndpoint as? NWHostEndpoint)?.hostname ?? "unknown",
               String(describing: flow.metaData.filterFlowIdentifier?.uuidString),
               String(describing: flow.metaData.sourceAppSigningIdentifier))

        guard !settings.dryMode else {
            return false
        }

        guard isFromExcludedApp(flow) else {
            os_log("🤌 Ignoring app!")
            return false
        }

        os_log("🤌🟢 New UDP flow %{public}@", String(describing: flow))

        flow.networkInterface = directInterface

        guard let interface else {
            os_log("🤌🟢  I don't have an interface to work with!")
            return false
        }

        let flowManager = UDPFlowManager(flow: flow)
        udpFlowManagers.insert(flowManager)

        Task {
            await flowManager.start(interface: interface, initialRemoteEndpoint: remoteEndpoint)
            udpFlowManagers.remove(flowManager)
            os_log("🤌🟢 Aaaaaaand out!")
        }

        return true
    }

    override public func handleAppMessage(_ messageData: Data) async -> Data? {
        os_log("🤌 Transparent proxy handling message: %{public}@", String(data: messageData, encoding: .utf8) ?? "null")

        return "🤌 Transparent proxy processed message".data(using: .utf8)
    }

    private func isFromExcludedApp(_ flow: NEAppProxyFlow) -> Bool {

        if flow.metaData.sourceAppSigningIdentifier.hasPrefix("com.duckduckgo.macos") {
            return true
        }

        if settings.excludeDBP
            && flow.metaData.sourceAppSigningIdentifier == configuration.dbpAgentBundleID {

            os_log("🤌 Excluding DBP app traffic")
            return true
        }

        for app in settings.excludedApps where flow.metaData.sourceAppSigningIdentifier == app.bundleID {
            os_log("🤌 Excluding app traffic")
            return true
        }

        return false
    }
}
