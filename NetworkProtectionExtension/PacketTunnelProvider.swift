// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import Foundation
import NetworkExtension
import os
import NetworkProtection

final class PacketTunnelProvider: NEPacketTunnelProvider {

    private lazy var adapter: WireGuardAdapter = {
        return WireGuardAdapter(with: self) { logLevel, message in
            let logType: OSLogType = logLevel == .error ? .error : .info

            os_log("🔵 Received message from adapter: %{public}@", log: networkExtensionLog, type: logType, message)
        }
    }()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let activationAttemptId = options?["activationAttemptId"] as? String

        os_log("🔵 Starting tunnel from the %{public}@", log: networkExtensionLog, type: .info, activationAttemptId == nil ? "OS directly, rather than the app" : "app")

        guard let tunnelProviderProtocol = self.protocolConfiguration as? NETunnelProviderProtocol,
              let tunnelConfiguration = tunnelProviderProtocol.asTunnelConfiguration() else {

            completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            return
        }

        // Start the tunnel
        adapter.start(tunnelConfiguration: tunnelConfiguration) { adapterError in
            guard let adapterError = adapterError else {
                let interfaceName = self.adapter.interfaceName ?? "unknown"

                os_log("🔵 Tunnel interface is %{public}@", log: networkExtensionLog, type: .info, interfaceName)

                completionHandler(nil)
                return
            }

            switch adapterError {
            case .cannotLocateTunnelFileDescriptor:
                os_log("🔵 Starting tunnel failed: could not determine file descriptor", log: networkExtensionLog, type: .error)

                completionHandler(PacketTunnelProviderError.couldNotDetermineFileDescriptor)

            case .dnsResolution(let dnsErrors):
                let hostnamesWithDnsResolutionFailure = dnsErrors.map { $0.address }
                    .joined(separator: ", ")
                os_log("🔵 DNS resolution failed for the following hostnames: %{public}@", log: networkExtensionLog, type: .error, hostnamesWithDnsResolutionFailure)

                completionHandler(PacketTunnelProviderError.dnsResolutionFailure)

            case .setNetworkSettings(let error):
                os_log("🔵 Starting tunnel failed with setTunnelNetworkSettings returning: %{public}@", log: networkExtensionLog, type: .error, error.localizedDescription)

                completionHandler(PacketTunnelProviderError.couldNotSetNetworkSettings)

            case .startWireGuardBackend(let errorCode):
                os_log("Starting tunnel failed with wgTurnOn returning: %{public}@", log: networkExtensionLog, type: .error, errorCode)

                completionHandler(PacketTunnelProviderError.couldNotStartBackend)

            case .invalidState:
                // Must never happen
                fatalError()
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("🔵 Stopping tunnel", log: networkExtensionLog, type: .info)

        adapter.stop { error in
            if let error = error {
                os_log("🔵 Failed to stop WireGuard adapter: %{public}@", log: networkExtensionLog, type: .info, error.localizedDescription)
            }
            completionHandler()

            #if os(macOS)
            // HACK: This is a filthy hack to work around Apple bug 32073323 (dup'd by us as 47526107).
            // Remove it when they finally fix this upstream and the fix has been rolled out to
            // sufficient quantities of users.
            exit(0)
            #endif
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        guard let completionHandler = completionHandler else { return }

        if messageData.count == 1 && messageData[0] == 0 {
            adapter.getRuntimeConfiguration { settings in
                var data: Data?
                if let settings = settings {
                    data = settings.data(using: .utf8)!
                }
                completionHandler(data)
            }
        } else {
            completionHandler(nil)
        }
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
