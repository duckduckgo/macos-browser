//
//  VPNMetadataCollector.swift
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
import Common
import LoginItems
import NetworkProtection
import NetworkProtectionIPC
import NetworkProtectionUI

struct VPNMetadata: Encodable {

    struct AppInfo: Encodable {
        let appVersion: String
        let lastVersionRun: String
        let isInternalUser: Bool
    }

    struct DeviceInfo: Encodable {
        let osVersion: String
        let buildFlavor: String
        let lowPowerModeEnabled: Bool
    }

    struct NetworkInfo: Encodable {
        let currentPath: String
    }

    struct VPNState: Encodable {
        let onboardingState: String
        let connectionState: String
        let serverLocation: String
    }

    struct LoginItemState: Encodable {
        let vpnMenuState: String

#if NETP_SYSTEM_EXTENSION
        let notificationsAgentState: String
#endif
    }

    let appInfo: AppInfo
    let deviceInfo: DeviceInfo
    let networkInfo: NetworkInfo
    let vpnState: VPNState
    let loginItemState: LoginItemState

    func toPrettyPrintedJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        guard let encodedMetadata = try? encoder.encode(self) else {
            assertionFailure("Failed to encode metadata")
            return nil
        }

        return String(data: encodedMetadata, encoding: .utf8)
    }

    func toBase64() -> String {
        let encoder = JSONEncoder()

        do {
            let encodedMetadata = try encoder.encode(self)
            return encodedMetadata.base64EncodedString()
        } catch {
            return "Failed to encode metadata to JSON, error message: \(error.localizedDescription)"
        }
    }

}

protocol VPNMetadataCollector {
    func collectMetadata() async -> VPNMetadata
}

final class DefaultVPNMetadataCollector: VPNMetadataCollector {

    private let statusReporter: NetworkProtectionStatusReporter

    init() {
        let machServiceName = Bundle.main.vpnMenuAgentBundleId
        let ipcClient = TunnelControllerIPCClient(machServiceName: machServiceName)
        ipcClient.register()

        self.statusReporter = DefaultNetworkProtectionStatusReporter(
            statusObserver: ipcClient.connectionStatusObserver,
            serverInfoObserver: ipcClient.serverInfoObserver,
            connectionErrorObserver: ipcClient.connectionErrorObserver,
            connectivityIssuesObserver: ConnectivityIssueObserverThroughDistributedNotifications(),
            controllerErrorMessageObserver: ControllerErrorMesssageObserverThroughDistributedNotifications()
        )

        // Force refresh just in case. A refresh is requested when the IPC client is created, but distributed notifications don't guarantee delivery
        // so we'll play it safe and add one more attempt.
        self.statusReporter.forceRefresh()
    }

    deinit {
        // print("DEINIT VPN METADATA COLLECTOR")
    }

    @MainActor
    func collectMetadata() async -> VPNMetadata {
        let appInfoMetadata = collectAppInfoMetadata()
        let deviceInfoMetadata = collectDeviceInfoMetadata()
        let networkInfoMetadata = await collectNetworkInformation()
        let vpnState = await collectVPNState()
        let loginItemState = collectLoginItemState()

        return VPNMetadata(
            appInfo: appInfoMetadata,
            deviceInfo: deviceInfoMetadata,
            networkInfo: networkInfoMetadata,
            vpnState: vpnState,
            loginItemState: loginItemState
        )
    }

    // MARK: - Metadata Collection

    private func collectAppInfoMetadata() -> VPNMetadata.AppInfo {
        let appVersion = AppVersion.shared.versionNumber
        let versionStore = NetworkProtectionLastVersionRunStore()
        let isInternalUser = NSApp.delegateTyped.internalUserDecider.isInternalUser

        return .init(appVersion: appVersion, lastVersionRun: versionStore.lastVersionRun ?? "Unknown", isInternalUser: isInternalUser)
    }

    private func collectDeviceInfoMetadata() -> VPNMetadata.DeviceInfo {
#if APPSTORE
        let buildFlavor: String = "appstore"
#else
        let buildFlavor: String = "dmg"
#endif

        let osVersion = AppVersion.shared.osVersion
        let lowPowerModeEnabled: Bool

        if #available(macOS 12.0, *) {
            lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        } else {
            lowPowerModeEnabled = false
        }

        return .init(osVersion: osVersion, buildFlavor: buildFlavor, lowPowerModeEnabled: lowPowerModeEnabled)
    }

    func collectNetworkInformation() async -> VPNMetadata.NetworkInfo {
        let monitor = NWPathMonitor()
        monitor.start(queue: DispatchQueue(label: "VPNMetadataCollector.NWPathMonitor.paths"))

        var path: NWPath?
        let startTime = CFAbsoluteTimeGetCurrent()

        while true {
            if !monitor.currentPath.availableInterfaces.isEmpty {
                path = monitor.currentPath
                monitor.cancel()
                return .init(currentPath: path.debugDescription)
            }

            // Wait up to 3 seconds to fetch the path.
            let currentExecutionTime = CFAbsoluteTimeGetCurrent() - startTime
            if currentExecutionTime >= 3.0 {
                return .init(currentPath: "Timed out fetching path")
            }
        }
    }

    @MainActor
    func collectVPNState() async -> VPNMetadata.VPNState {
        let onboardingState: String

        switch UserDefaults.netP.networkProtectionOnboardingStatus {
        case .completed:
            onboardingState = "complete"
        case .isOnboarding(let step):
            switch step {
            case .userNeedsToAllowExtension:
                onboardingState = "pending-extension-approval"
            case .userNeedsToAllowVPNConfiguration:
                onboardingState = "pending-vpn-approval"
            }
        }

        let connectionState = String(describing: statusReporter.statusObserver.recentValue)
        let serverLocation = statusReporter.serverInfoObserver.recentValue.serverLocation ?? "No Location"
        return .init(onboardingState: onboardingState, connectionState: connectionState, serverLocation: serverLocation)
    }

    func collectLoginItemState() -> VPNMetadata.LoginItemState {
        let vpnMenuState = String(describing: LoginItem.vpnMenu.status)

#if NETP_SYSTEM_EXTENSION
        let notificationsAgentState = String(describing: LoginItem.notificationsAgent.status)
        return .init(vpnMenuState: vpnMenuState, notificationsAgentState: notificationsAgentState)
#else
        return .init(vpnMenuState: vpnMenuState)
#endif
    }

}

#endif
