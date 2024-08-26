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

import Foundation
import AppKit
import Common
import LoginItems
import NetworkProtection
import NetworkExtension
import NetworkProtectionIPC
import NetworkProtectionUI
import Subscription

struct VPNMetadata: Encodable {

    struct AppInfo: Encodable {
        let appVersion: String
        let lastAgentVersionRun: String
        let lastExtensionVersionRun: String
        let isInternalUser: Bool
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
        let lastStartErrorDescription: String
        let lastTunnelErrorDescription: String
        let lastKnownFailureDescription: String
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
        let customDNS: Bool
    }

    struct LoginItemState: Encodable {
        let vpnMenuState: String
        let vpnMenuIsRunning: Bool
        let notificationsAgentState: String
        let notificationsAgentIsRunning: Bool
    }

    struct PrivacyProInfo: Encodable {
        let hasPrivacyProAccount: Bool
        let hasVPNEntitlement: Bool
    }

    let appInfo: AppInfo
    let deviceInfo: DeviceInfo
    let networkInfo: NetworkInfo
    let vpnState: VPNState
    let vpnSettingsState: VPNSettingsState
    let loginItemState: LoginItemState
    let privacyProInfo: PrivacyProInfo

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
    func collectVPNMetadata() async -> VPNMetadata
}

final class DefaultVPNMetadataCollector: VPNMetadataCollector {

    private let statusReporter: NetworkProtectionStatusReporter
    private let ipcClient: VPNControllerXPCClient
    private let defaults: UserDefaults
    private let accountManager: AccountManager
    private let settings: VPNSettings

    init(defaults: UserDefaults = .netP,
         accountManager: AccountManager) {

        let ipcClient = VPNControllerXPCClient.shared
        ipcClient.register { _ in }

        self.accountManager = accountManager
        self.ipcClient = ipcClient
        self.defaults = defaults

        self.statusReporter = DefaultNetworkProtectionStatusReporter(
            statusObserver: ipcClient.connectionStatusObserver,
            serverInfoObserver: ipcClient.serverInfoObserver,
            connectionErrorObserver: ipcClient.connectionErrorObserver,
            connectivityIssuesObserver: ConnectivityIssueObserverThroughDistributedNotifications(),
            controllerErrorMessageObserver: ControllerErrorMesssageObserverThroughDistributedNotifications(),
            dataVolumeObserver: ipcClient.dataVolumeObserver,
            knownFailureObserver: KnownFailureObserverThroughDistributedNotifications()
        )

        // Force refresh just in case. A refresh is requested when the IPC client is created, but distributed notifications don't guarantee delivery
        // so we'll play it safe and add one more attempt.
        self.statusReporter.forceRefresh()

        self.settings = VPNSettings(defaults: defaults)
        updateSettings()
    }

    func updateSettings() {
        let subscriptionAppGroup = Bundle.main.appGroup(bundle: .subs)
        let subscriptionUserDefaults = UserDefaults(suiteName: subscriptionAppGroup)!
        let subscriptionEnvironment = DefaultSubscriptionManager.getSavedOrDefaultEnvironment(userDefaults: subscriptionUserDefaults)
        settings.alignTo(subscriptionEnvironment: subscriptionEnvironment)
    }

    @MainActor
    func collectVPNMetadata() async -> VPNMetadata {
        let appInfoMetadata = collectAppInfoMetadata()
        let deviceInfoMetadata = collectDeviceInfoMetadata()
        let networkInfoMetadata = await collectNetworkInformation()
        let vpnState = await collectVPNState()
        let vpnSettingsState = collectVPNSettingsState()
        let loginItemState = collectLoginItemState()
        let privacyProInfo = await collectPrivacyProInfo()

        return VPNMetadata(
            appInfo: appInfoMetadata,
            deviceInfo: deviceInfoMetadata,
            networkInfo: networkInfoMetadata,
            vpnState: vpnState,
            vpnSettingsState: vpnSettingsState,
            loginItemState: loginItemState,
            privacyProInfo: privacyProInfo
        )
    }

    // MARK: - Metadata Collection

    private func collectAppInfoMetadata() -> VPNMetadata.AppInfo {
        let appVersion = AppVersion.shared.versionAndBuildNumber
        let versionStore = NetworkProtectionLastVersionRunStore(userDefaults: defaults)
        let isInternalUser = NSApp.delegateTyped.internalUserDecider.isInternalUser
        let isInApplicationsDirectory = Bundle.main.isInApplicationsDirectory

        return .init(
            appVersion: appVersion,
            lastAgentVersionRun: versionStore.lastAgentVersionRun ?? "none",
            lastExtensionVersionRun: versionStore.lastExtensionVersionRun ?? "none",
            isInternalUser: isInternalUser,
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

        let startTime = CFAbsoluteTimeGetCurrent()

        while true {
            if !monitor.currentPath.availableInterfaces.isEmpty {
                let path = monitor.currentPath
                monitor.cancel()

                return .init(currentPath: path.anonymousDescription)
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

        switch defaults.networkProtectionOnboardingStatus {
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

        let errorHistory = VPNOperationErrorHistory(ipcClient: ipcClient, defaults: defaults)

        let connectionState = String(describing: statusReporter.statusObserver.recentValue)
        let lastTunnelErrorDescription = await errorHistory.lastTunnelErrorDescription
        let lastKnownFailureDescription = NetworkProtectionKnownFailureStore().lastKnownFailure?.description ?? "none"
        let connectedServer = statusReporter.serverInfoObserver.recentValue.serverLocation?.serverLocation ?? "none"
        let connectedServerIP = statusReporter.serverInfoObserver.recentValue.serverAddress ?? "none"
        return .init(onboardingState: onboardingState,
                     connectionState: connectionState,
                     lastStartErrorDescription: errorHistory.lastStartErrorDescription,
                     lastTunnelErrorDescription: lastTunnelErrorDescription,
                     lastKnownFailureDescription: lastKnownFailureDescription,
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
            vpnMenuIsRunning: vpnMenuIsRunning,
            notificationsAgentState: "not-required",
            notificationsAgentIsRunning: false
        )
#endif
    }

    func collectVPNSettingsState() -> VPNMetadata.VPNSettingsState {
        return .init(
            connectOnLoginEnabled: settings.connectOnLogin,
            includeAllNetworksEnabled: settings.includeAllNetworks,
            enforceRoutesEnabled: settings.enforceRoutes,
            excludeLocalNetworksEnabled: settings.excludeLocalNetworks,
            notifyStatusChangesEnabled: settings.notifyStatusChanges,
            showInMenuBarEnabled: settings.showInMenuBar,
            selectedServer: settings.selectedServer.stringValue ?? "automatic",
            selectedEnvironment: settings.selectedEnvironment.rawValue,
            customDNS: settings.dnsSettings.usesCustomDNS
        )
    }

    func collectPrivacyProInfo() async -> VPNMetadata.PrivacyProInfo {
        let hasVPNEntitlement = (try? await accountManager.hasEntitlement(forProductName: .networkProtection).get()) ?? false
        return .init(
            hasPrivacyProAccount: accountManager.isUserAuthenticated,
            hasVPNEntitlement: hasVPNEntitlement
        )
    }

}

// MARK: - Unified feedback form support

extension VPNMetadata: UnifiedFeedbackMetadata {}

extension DefaultVPNMetadataCollector: UnifiedMetadataCollector {
    func collectMetadata() async -> VPNMetadata {
        await collectVPNMetadata()
    }
}
