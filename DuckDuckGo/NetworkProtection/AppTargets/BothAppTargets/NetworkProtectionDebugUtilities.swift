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
import NetworkProtection
import NetworkProtectionUI
import NetworkExtension
import SystemExtensions
import LoginItems
import NetworkProtectionIPC

/// Utility code to help implement our debug menu options for the VPN.
///
final class NetworkProtectionDebugUtilities {

    private let ipcClient: VPNControllerXPCClient
    private let vpnUninstaller: VPNUninstaller

    // MARK: - Login Items Management

    private let loginItemsManager: LoginItemsManager

    // MARK: - Settings

    private let settings: VPNSettings

    // MARK: - Initializers

    init(loginItemsManager: LoginItemsManager = .init(), settings: VPNSettings = .init(defaults: .netP)) {
        self.loginItemsManager = loginItemsManager
        self.settings = settings

        let ipcClient = VPNControllerXPCClient.shared

        self.ipcClient = ipcClient
        self.vpnUninstaller = VPNUninstaller(ipcClient: ipcClient)
    }

    // MARK: - Debug commands for the extension

    func restartAdapter() async throws {
        try await ipcClient.command(.restartAdapter)
    }

    func resetAllState(keepAuthToken: Bool) async throws {
        try await vpnUninstaller.uninstall(removeSystemExtension: true)

        settings.resetToDefaults()

        UserDefaults.netP.networkProtectionEntitlementsExpired = false
        resetSiteIssuesAlert()
    }

    func resetSiteIssuesAlert() {
        UserDefaults.netP.resetVPNReportSiteIssuesDontAskAgain()
    }

    func removeSystemExtensionAndAgents() async throws {
        try await vpnUninstaller.removeSystemExtension()
        vpnUninstaller.removeAgents()
    }

    func removeVPNConfiguration() async throws {
        try await vpnUninstaller.removeVPNConfiguration()
    }

    func sendTestNotificationRequest() async throws {
        try await ipcClient.command(.sendTestNotification)
    }

    func expireRegistrationKeyNow() async throws {
        try await ipcClient.command(.expireRegistrationKey)
    }
}
