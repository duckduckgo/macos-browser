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

/// Utility code to help implement our debug menu options for Network Protection.
///
final class NetworkProtectionDebugUtilities {

    // MARK: - Registration Key Validity

    @UserDefaultsWrapper(key: .networkProtectionRegistrationKeyValidity, defaultValue: nil)
    var registrationKeyValidity: TimeInterval? {
        didSet {
            Task {
                await sendRegistrationKeyValidityToProvider()
            }
        }
    }

    private let networkProtectionFeatureDisabler = NetworkProtectionFeatureDisabler()

    // MARK: - Login Items Management

    private let loginItemsManager: LoginItemsManager

    // MARK: - Server Selection

    private let selectedServerStore = NetworkProtectionSelectedServerUserDefaultsStore()

    // MARK: - Initializers

    init(loginItemsManager: LoginItemsManager = .init()) {
        self.loginItemsManager = loginItemsManager
    }

    // MARK: - Debug commands for the extension

    func resetAllState(keepAuthToken: Bool) async throws {
        networkProtectionFeatureDisabler.disable(keepAuthToken: keepAuthToken, uninstallSystemExtension: true)

        NetworkProtectionWaitlist().waitlistStorage.deleteWaitlistState()
        UserDefaults().removeObject(forKey: UserDefaultsWrapper<Bool>.Key.networkProtectionTermsAndConditionsAccepted.rawValue)
        NotificationCenter.default.post(name: .networkProtectionWaitlistAccessChanged, object: nil)
    }

    func removeSystemExtensionAndAgents() async throws {
        networkProtectionFeatureDisabler.disableLoginItems()
        try await networkProtectionFeatureDisabler.disableSystemExtension()
    }

    func sendTestNotificationRequest() async throws {
        guard let activeSession = try? await ConnectionSessionUtilities.activeSession() else {
            return
        }

        try? activeSession.sendProviderMessage(.triggerTestNotification)
    }

    // MARK: - Registation Key

    private func sendRegistrationKeyValidityToProvider() async {
        guard let activeSession = try? await ConnectionSessionUtilities.activeSession() else {
            return
        }

        try? activeSession.sendProviderMessage(.setKeyValidity(registrationKeyValidity))
    }

    func expireRegistrationKeyNow() async {
        guard let activeSession = try? await ConnectionSessionUtilities.activeSession() else {
            return
        }

        try? activeSession.sendProviderMessage(.expireRegistrationKey)
    }

    // MARK: - Server Selection

    func selectedServerName() -> String? {
        selectedServerStore.selectedServer.stringValue
    }

    func setSelectedServer(selectedServer: SelectedNetworkProtectionServer) {
        selectedServerStore.selectedServer = selectedServer

        Task {
            guard let activeSession = try? await ConnectionSessionUtilities.activeSession() else {
                return
            }

            try? activeSession.sendProviderMessage(.setSelectedServer(selectedServer.stringValue))
        }
    }
}

#endif
