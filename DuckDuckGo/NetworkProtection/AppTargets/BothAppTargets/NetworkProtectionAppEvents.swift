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

import Common
import Foundation
import LoginItems
import NetworkProtection
import NetworkProtectionUI
import NetworkProtectionIPC
import NetworkExtension
import Subscription

/// Implements the sequence of steps that the VPN needs to execute when the App starts up.
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

    // MARK: - Feature Gatekeeping

    private let featureGatekeeper: VPNFeatureGatekeeper
    private let uninstaller: VPNUninstalling
    private let defaults: UserDefaults

    init(featureGatekeeper: VPNFeatureGatekeeper,
         uninstaller: VPNUninstalling = VPNUninstaller(),
         defaults: UserDefaults = .netP) {

        self.defaults = defaults
        self.uninstaller = uninstaller
        self.featureGatekeeper = featureGatekeeper
    }

    /// Call this method when the app finishes launching, to run the startup logic for NetP.
    ///
    func applicationDidFinishLaunching() {
        let loginItemsManager = LoginItemsManager()

        Task { @MainActor in
            await featureGatekeeper.disableIfUserHasNoAccess()
            restartNetworkProtectionIfVersionChanged(using: loginItemsManager)
        }
    }

    /// Call this method when the app becomes active to run the associated NetP logic.
    ///
    func applicationDidBecomeActive() {
        Task { @MainActor in
            await featureGatekeeper.disableIfUserHasNoAccess()
        }
    }

    private func restartNetworkProtectionIfVersionChanged(using loginItemsManager: LoginItemsManager) {
        // We want to restart the VPN menu app to make sure it's always on the latest.
        restartNetworkProtectionMenu(using: loginItemsManager)
    }

    private func restartNetworkProtectionMenu(using loginItemsManager: LoginItemsManager) {
        guard loginItemsManager.isAnyEnabled(LoginItemsManager.networkProtectionLoginItems) else {
            return
        }

        loginItemsManager.restartLoginItems(LoginItemsManager.networkProtectionLoginItems)
    }

}
