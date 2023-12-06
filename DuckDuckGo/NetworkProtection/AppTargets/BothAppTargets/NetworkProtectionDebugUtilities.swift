//
//  NetworkProtectionDebugUtilities.swift
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

#if NETWORK_PROTECTION
import NetworkProtection
import NetworkProtectionUI
import NetworkExtension
import SystemExtensions
import LoginItems
import NetworkProtectionIPC

/// Utility code to help implement our debug menu options for Network Protection.
///
final class NetworkProtectionDebugUtilities {

    private let ipcClient: TunnelControllerIPCClient
    private let networkProtectionFeatureDisabler: NetworkProtectionFeatureDisabler

    // MARK: - Login Items Management

    private let loginItemsManager: LoginItemsManager

    // MARK: - Settings

    private let settings: VPNSettings

    // MARK: - Initializers

    init(loginItemsManager: LoginItemsManager = .init(), settings: VPNSettings = .init(defaults: .netP)) {
        self.loginItemsManager = loginItemsManager
        self.settings = settings

        let ipcClient = TunnelControllerIPCClient(machServiceName: Bundle.main.vpnMenuAgentBundleId)

        self.ipcClient = ipcClient
        self.networkProtectionFeatureDisabler = NetworkProtectionFeatureDisabler(ipcClient: ipcClient)
    }

    // MARK: - Debug commands for the extension

    func resetAllState(keepAuthToken: Bool) async {
        let uninstalledSuccessfully = await networkProtectionFeatureDisabler.disable(keepAuthToken: keepAuthToken, uninstallSystemExtension: true)

        guard uninstalledSuccessfully else {
            return
        }

        settings.resetToDefaults()

        NetworkProtectionWaitlist().waitlistStorage.deleteWaitlistState()
        DefaultWaitlistActivationDateStore().removeDates()
        DefaultNetworkProtectionRemoteMessagingStorage().removeStoredAndDismissedMessages()

        UserDefaults().removeObject(forKey: UserDefaultsWrapper<Bool>.Key.networkProtectionTermsAndConditionsAccepted.rawValue)
        NotificationCenter.default.post(name: .networkProtectionWaitlistAccessChanged, object: nil)
    }

    func removeSystemExtensionAndAgents() async throws {
        try await networkProtectionFeatureDisabler.removeSystemExtension()
        networkProtectionFeatureDisabler.disableLoginItems()
    }

    func sendTestNotificationRequest() async throws {
        try await ipcClient.debugCommand(.sendTestNotification)
    }

    func expireRegistrationKeyNow() async throws {
        try await ipcClient.debugCommand(.expireRegistrationKey)
    }
}

#endif
