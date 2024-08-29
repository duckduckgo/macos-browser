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
import LoginItems
import NetworkProtectionIPC

final class IPCServiceLauncher {

    enum DisableError: Error {
        case failedToStopService
        case serviceNotRunning
    }

    enum LaunchMethod {
        case direct(bundleID: String, appLauncher: AppLauncher)
        case loginItem(loginItem: LoginItem, loginItemsManager: LoginItemsManager)
    }

    private let launchMethod: LaunchMethod
    private var runningApplication: NSRunningApplication?

    init(launchMethod: LaunchMethod) {
        self.launchMethod = launchMethod
    }

    func checkPrerequisites() -> Bool {
        switch launchMethod {
        case .direct(_, let appLauncher):
            return appLauncher.targetAppExists()
        case .loginItem:
            return true
        }
    }

    /// Enables the IPC service
    ///
    func enable() async throws {
        switch launchMethod {
        case .direct(let bundleID, let appLauncher):
            runningApplication = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first

            guard runningApplication == nil else {
                return
            }

            struct UDSLaunchAppCommand: AppLaunchCommand {
                var allowsRunningApplicationSubstitution = true
                var launchURL: URL?
                var hideApp = true
            }

            runningApplication = try await appLauncher.runApp(withCommand: UDSLaunchAppCommand())
        case .loginItem(let loginItem, let loginItemsManager):
            try loginItemsManager.throwingEnableLoginItems([loginItem])
        }
    }

    /// Disables the IPC service.
    ///
    /// - Throws: ``DisableError``
    ///
    func disable() async throws {
        switch launchMethod {
        case .direct:
            guard let runningApplication else {
                throw DisableError.serviceNotRunning
            }

            runningApplication.terminate()

            try await Task.sleep(nanoseconds: 500 * NSEC_PER_MSEC)

            if !runningApplication.isTerminated {
                runningApplication.forceTerminate()
            }

            if !runningApplication.isTerminated {
                throw DisableError.failedToStopService
            }

        case .loginItem(let loginItem, let loginItemsManager):
            loginItemsManager.disableLoginItems([loginItem])
        }
    }
}
