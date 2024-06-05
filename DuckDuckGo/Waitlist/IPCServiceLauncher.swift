//
//  IPCServiceLauncher.swift
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

import AppLauncher
import Common
import Foundation
import NetworkProtectionIPC

final class IPCServiceLauncher{

    enum LaunchMethod {
        case direct
        case loginItem
    }

    private let bundleID: String
    private let appLauncher: AppLaunching
    private let ipcClient: VPNControllerIPCClient
    private let loginItemsManager: LoginItemsManaging
    private let log: OSLog

    init(bundleID: String,
         ipcClient: VPNControllerIPCClient,
         loginItemsManager: LoginItemsManager,
         log: OSLog) {

        self.bundleID = bundleID
        self.appLauncher = AppLauncher(appBundleURL: Bundle.main.vpnMenuAgentURL)
        self.ipcClient = ipcClient
        self.loginItemsManager = loginItemsManager
        self.log = log
    }

    /// Enable the IPC service
    ///
    /// When enabling the IPC service it's important to pick the right method, because during uninstallation we don't want the user to be
    /// told by mistake we're enabling a background agent.
    ///
    func enable(launchMethod: LaunchMethod) async throws {
        switch launchMethod {
        case .direct:
            guard NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty else {
                return
            }

            struct UDSLaunchAppCommand: AppLaunchCommand {
                var allowsRunningApplicationSubstitution = true
                var launchURL: URL?
                var hideApp = true
            }

            try await appLauncher.launchApp(withCommand: UDSLaunchAppCommand())
        case .loginItem:
            try loginItemsManager.throwingEnableLoginItems(LoginItemsManager.networkProtectionLoginItems, log: log)
        }
    }

    /// Disables the IPC service.
    ///
    /// While ``enable(launchMethod:)`` launches the service according to the selected method, here we need to disable the
    /// service regardless of what method it was launched with.
    ///
    func disable() async throws {
        if loginItemsManager.isAnyEnabled(LoginItemsManager.networkProtectionLoginItems) {
            loginItemsManager.disableLoginItems(LoginItemsManager.networkProtectionLoginItems)
        }

        try await ipcClient.quitAgent()
    }
}
