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
import AppKit
import Common
import LoginItems
import NetworkProtection
import NetworkExtension
import NetworkProtectionIPC
import NetworkProtectionUI

struct VPNMetadata: Encodable {

    struct AppInfo: Encodable {
        let appVersion: String
        let lastVersionRun: String
        let isInternalUser: Bool
        let isAdminUser: String
        let isInApplicationsDirectory: Bool
    }

    struct DeviceInfo: Encodable {
        let osVersion: String
        let buildFlavor: String
        let lowPowerModeEnabled: Bool
        let cpuArchitecture: String
    }

    struct NetworkInfo: Encodable {
        let currentPath: String
    }

    struct VPNState: Encodable {
        let onboardingState: String
        let connectionState: String
        let lastErrorMessage: String
        let connectedServer: String
        let connectedServerIP: String
    }

    struct VPNSettingsState: Encodable {
        let connectOnLoginEnabled: Bool
        let includeAllNetworksEnabled: Bool
        let enforceRoutesEnabled: Bool
        let excludeLocalNetworksEnabled: Bool
        let notifyStatusChangesEnabled: Bool
        let showInMenuBarEnabled: Bool
        let selectedServer: String
        let selectedEnvironment: String
    }

    struct LoginItemState: Encodable {
        let vpnMenuState: String
        let vpnMenuIsRunning: Bool

#if NETP_SYSTEM_EXTENSION
        let notificationsAgentState: String
        let notificationsAgentIsRunning: Bool
#endif
    }

    let appInfo: AppInfo
    let deviceInfo: DeviceInfo
    let networkInfo: NetworkInfo
    let vpnState: VPNState
    let vpnSettingsState: VPNSettingsState
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

    @MainActor
    func collectMetadata() async -> VPNMetadata {
        let appInfoMetadata = collectAppInfoMetadata()
        let deviceInfoMetadata = collectDeviceInfoMetadata()
        let networkInfoMetadata = await collectNetworkInformation()
        let vpnState = await collectVPNState()
        let vpnSettingsState = collectVPNSettingsState()
        let loginItemState = collectLoginItemState()

        return VPNMetadata(
            appInfo: appInfoMetadata,
            deviceInfo: deviceInfoMetadata,
            networkInfo: networkInfoMetadata,
            vpnState: vpnState,
            vpnSettingsState: vpnSettingsState,
            loginItemState: loginItemState
        )
    }

    // MARK: - Metadata Collection

    private func collectAppInfoMetadata() -> VPNMetadata.AppInfo {
        let appVersion = AppVersion.shared.versionAndBuildNumber
        let versionStore = NetworkProtectionLastVersionRunStore()
        let isInternalUser = NSApp.delegateTyped.internalUserDecider.isInternalUser
        let isAdminUser = isAdminUser()
        let isInApplicationsDirectory = Bundle.main.isInApplicationsDirectory

        return .init(
            appVersion: appVersion,
            lastVersionRun: versionStore.lastVersionRun ?? "Unknown",
            isInternalUser: isInternalUser,
            isAdminUser: isAdminUser,
            isInApplicationsDirectory: isInApplicationsDirectory
        )
    }

    private func collectDeviceInfoMetadata() -> VPNMetadata.DeviceInfo {
        let buildFlavor = AppVersion.shared.buildType
        let osVersion = AppVersion.shared.osVersion
        let lowPowerModeEnabled: Bool

        if #available(macOS 12.0, *) {
            lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        } else {
            lowPowerModeEnabled = false
        }

        let architecture = getMachineArchitecture()

        return .init(osVersion: osVersion, buildFlavor: buildFlavor, lowPowerModeEnabled: lowPowerModeEnabled, cpuArchitecture: architecture)
    }

    private func getMachineArchitecture() -> String {
        #if arch(arm)
            return "arm"
        #elseif arch(arm64)
            return "arm64"
        #elseif arch(i386)
            return "i386"
        #elseif arch(x86_64)
            return "x86_64"
        #else
            return "unknown"
        #endif
    }

    func collectNetworkInformation() async -> VPNMetadata.NetworkInfo {
        let monitor = NWPathMonitor()
        monitor.start(queue: DispatchQueue(label: "VPNMetadataCollector.NWPathMonitor.paths"))

        var path: Network.NWPath?
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
        let lastErrorMessage = statusReporter.connectionErrorObserver.recentValue ?? "none"
        let connectedServer = statusReporter.serverInfoObserver.recentValue.serverLocation ?? "none"
        let connectedServerIP = statusReporter.serverInfoObserver.recentValue.serverAddress ?? "none"
        return .init(onboardingState: onboardingState,
                     connectionState: connectionState,
                     lastErrorMessage: lastErrorMessage,
                     connectedServer: connectedServer,
                     connectedServerIP: connectedServerIP)
    }

    func collectLoginItemState() -> VPNMetadata.LoginItemState {
        let vpnMenuState = String(describing: LoginItem.vpnMenu.status)
        let vpnMenuIsRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: LoginItem.vpnMenu.agentBundleID).isEmpty

#if NETP_SYSTEM_EXTENSION
        let notificationsAgentState = String(describing: LoginItem.notificationsAgent.status)
        let notificationsAgentIsRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: LoginItem.notificationsAgent.agentBundleID).isEmpty

        return .init(
            vpnMenuState: vpnMenuState,
            vpnMenuIsRunning: vpnMenuIsRunning,
            notificationsAgentState: notificationsAgentState,
            notificationsAgentIsRunning: notificationsAgentIsRunning)
#else
        return .init(
            vpnMenuState: vpnMenuState,
            vpnMenuIsRunning: vpnMenuIsRunning)
#endif
    }

    func collectVPNSettingsState() -> VPNMetadata.VPNSettingsState {
        let settings = VPNSettings(defaults: .netP)

        return .init(
            connectOnLoginEnabled: settings.connectOnLogin,
            includeAllNetworksEnabled: settings.includeAllNetworks,
            enforceRoutesEnabled: settings.enforceRoutes,
            excludeLocalNetworksEnabled: settings.excludeLocalNetworks,
            notifyStatusChangesEnabled: settings.notifyStatusChanges,
            showInMenuBarEnabled: settings.showInMenuBar,
            selectedServer: settings.selectedServer.stringValue ?? "automatic",
            selectedEnvironment: settings.selectedEnvironment.rawValue
        )
    }

}

// MARK: - Admin User

private enum AdminQueryError: Error {
    case queryExecutionFailed
    case queriedWithoutResult
}

extension VPNMetadataCollector {

    private func getUser() throws -> CSIdentity? {
        let query = CSIdentityQueryCreateForCurrentUser(kCFAllocatorDefault).takeRetainedValue()
        let flags = CSIdentityQueryFlags()

        guard CSIdentityQueryExecute(query, flags, nil) else {
            throw AdminQueryError.queryExecutionFailed
        }

        let users = CSIdentityQueryCopyResults(query).takeRetainedValue() as? [CSIdentity]
        return users?.first
    }

    private func getAdminGroup() throws -> CSIdentity {
        let privilegeGroup = "admin" as CFString
        let authority = CSGetDefaultIdentityAuthority().takeRetainedValue()
        let query = CSIdentityQueryCreateForName(kCFAllocatorDefault,
                                                 privilegeGroup,
                                                 kCSIdentityQueryStringEquals,
                                                 kCSIdentityClassGroup,
                                                 authority).takeRetainedValue()
        let flags = CSIdentityQueryFlags()

        guard CSIdentityQueryExecute(query, flags, nil) else { throw AdminQueryError.queryExecutionFailed }
        let groups = CSIdentityQueryCopyResults(query).takeRetainedValue() as? [CSIdentity]

        guard let adminGroup = groups?.first else {
            throw AdminQueryError.queriedWithoutResult
        }

        return adminGroup
    }

    fileprivate func isAdminUser() -> String {
        do {
            let user = try self.getUser()
            let group = try self.getAdminGroup()

            let isAdmin = CSIdentityIsMemberOfGroup(user, group)
            return String(describing: isAdmin)
        } catch {
            return "error checking status: \(error.localizedDescription)"
        }
    }

}

#endif
