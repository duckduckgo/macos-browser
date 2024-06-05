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

protocol IPCServiceLauncher {
    func enable() async throws
    func disable() async throws
}

final class VPNXPCServiceLauncher: IPCServiceLauncher {

    private let loginItemsManager: LoginItemsManaging
    private let log: OSLog

    init(loginItemsManager: LoginItemsManaging,
         log: OSLog) {

        self.log = log
        self.loginItemsManager = loginItemsManager
    }

    func enable() async throws {
        try loginItemsManager.throwingEnableLoginItems(LoginItemsManager.networkProtectionLoginItems, log: log)
    }

    func disable() async throws {
        loginItemsManager.disableLoginItems(LoginItemsManager.networkProtectionLoginItems)
    }
}

final class VPNUDSServiceLauncher: IPCServiceLauncher {

    private let bundleID: String
    private let appLauncher: AppLaunching

    init(bundleID: String) {
        self.bundleID = bundleID
        self.appLauncher = AppLauncher(appBundleURL: Bundle.main.vpnMenuAgentURL)
    }

    func enable() async throws {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty else {
            return
        }

        struct UDSLaunchAppCommand: AppLaunchCommand {
            var allowsRunningApplicationSubstitution = true
            var launchURL: URL?
            var hideApp = true
        }

        try await appLauncher.launchApp(withCommand: UDSLaunchAppCommand())
    }

    func disable() async throws {
        //appLauncher.stopApp()
    }
}
