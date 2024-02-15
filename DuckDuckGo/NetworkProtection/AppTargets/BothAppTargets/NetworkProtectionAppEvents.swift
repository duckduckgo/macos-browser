//
//  NetworkProtectionAppEvents.swift
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
import Common
import Foundation
import LoginItems
import NetworkProtection
import NetworkProtectionUI
import NetworkProtectionIPC
import NetworkExtension

/// Implements the sequence of steps that Network Protection needs to execute when the App starts up.
///
final class NetworkProtectionAppEvents {

    // MARK: - Legacy VPN Item and Extension

#if NETP_SYSTEM_EXTENSION
#if DEBUG
    private let legacyAgentBundleID = "HKE973VLUW.com.duckduckgo.macos.browser.network-protection.system-extension.agent.debug"
    private let legacySystemExtensionBundleID = "com.duckduckgo.macos.browser.debug.network-protection-extension"
#elseif REVIEW
    private let legacyAgentBundleID = "HKE973VLUW.com.duckduckgo.macos.browser.network-protection.system-extension.agent.review"
    private let legacySystemExtensionBundleID = "com.duckduckgo.macos.browser.review.network-protection-extension"
#else
    private let legacyAgentBundleID = "HKE973VLUW.com.duckduckgo.macos.browser.network-protection.system-extension.agent"
    private let legacySystemExtensionBundleID = "com.duckduckgo.macos.browser.network-protection-extension"
#endif // DEBUG || REVIEW || RELEASE
#endif // NETP_SYSTEM_EXTENSION

    // MARK: - Feature Visibility

    private let featureVisibility: NetworkProtectionFeatureVisibility

    init(featureVisibility: NetworkProtectionFeatureVisibility = DefaultNetworkProtectionVisibility()) {
        self.featureVisibility = featureVisibility
    }

    /// Call this method when the app finishes launching, to run the startup logic for NetP.
    ///
    func applicationDidFinishLaunching() {
        let loginItemsManager = LoginItemsManager()

        Task { @MainActor in
            guard featureVisibility.isNetworkProtectionVisible() else {
                featureVisibility.disableForAllUsers()
                return
            }

            restartNetworkProtectionIfVersionChanged(using: loginItemsManager)
            refreshNetworkProtectionServers()
        }
    }

    /// Call this method when the app becomes active to run the associated NetP logic.
    ///
    func applicationDidBecomeActive() {
        guard featureVisibility.isNetworkProtectionVisible() else {
            featureVisibility.disableForAllUsers()
            return
        }
    }

    private func restartNetworkProtectionIfVersionChanged(using loginItemsManager: LoginItemsManager) {
        let versionStore = NetworkProtectionLastVersionRunStore()

        // should‘ve been run at least once with NetP enabled
        guard versionStore.lastVersionRun != nil else {
            os_log(.info, log: .networkProtection, "No last version found for the NetP login items, skipping update")
            return
        }

        // We want to restart the VPN menu app to make sure it's always on the latest.
        restartNetworkProtectionMenu(using: loginItemsManager)
    }

    private func restartNetworkProtectionMenu(using loginItemsManager: LoginItemsManager) {
        loginItemsManager.restartLoginItems(LoginItemsManager.networkProtectionLoginItems, log: .networkProtection)
    }

    /// Fetches a new list of Network Protection servers, and updates the existing set.
    ///
    private func refreshNetworkProtectionServers() {
        Task {
            let serverCount: Int
            do {
                serverCount = try await NetworkProtectionDeviceManager.create().refreshServerList().count
            } catch {
                os_log("Failed to update Network Protection servers", log: .networkProtection, type: .error)
                return
            }

            os_log("Successfully updated Network Protection servers; total server count = %{public}d", log: .networkProtection, serverCount)
        }
    }
}

#endif
