//
//  NetworkProtectionLoginItemsManager.swift
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

/// Class to manage the login items for Network Protection
/// 
final class NetworkProtectionLoginItemsManager {
    private static var loginItems: [LoginItem] {
#if NETP_SYSTEM_EXTENSION
        [.notificationsAgent, .vpnMenu]
#else
        [.vpnMenu]
#endif
    }

    // MARK: - Main Interactions

    func enableLoginItems() {
        updateLoginItems("enable", using: LoginItem.enable)
        ensureLoginItemsAreRunning()
    }

    func restartLoginItems() {
        updateLoginItems("restart", using: LoginItem.restart)
        ensureLoginItemsAreRunning(.ifLoginItemsAreEnabled)
    }

    func disableLoginItems() {
        for item in Self.loginItems {
            try? item.disable()
        }
    }

    // MARK: - Debug Interactions

    func resetLoginItems() async throws {
        Self.loginItems.forEach { loginItem in
            try? loginItem.disable()
        }
    }

    // MARK: - Misc Utility

    private func updateLoginItems(_ whatAreWeDoing: String, using action: (LoginItem) -> () throws -> Void) {
        for item in Self.loginItems {
            do {
                try action(item)()
            } catch let error as NSError {
                logOrAssertionFailure("🔴 Could not \(whatAreWeDoing) \(item): \(error.debugDescription)")
            }
        }
    }

    // MARK: - Ensuring Execution

    enum LoginItemCheckCondition {
        case none
        case ifLoginItemsAreEnabled

        var shouldIgnoreItemStatus: Bool {
            self == .none
        }
    }

    /// Ensures that the login items are running.  If an item that's supposed to be running is not, this method launches it manually.
    ///
    func ensureLoginItemsAreRunning(_ condition: LoginItemCheckCondition = .none, after interval: TimeInterval = .seconds(5)) {

        Task {
            try? await Task.sleep(interval: interval)

            os_log(.info, log: .networkProtection, "Checking whether login agents are enabled and running")

            for item in Self.loginItems {
                guard !item.isRunning && (condition.shouldIgnoreItemStatus || item.status.isEnabled) else {
                    os_log(.info, log: .networkProtection, "Login item with ID '%{public}s': ok", item.debugDescription)
                    continue
                }

                os_log(.error, log: .networkProtection, "%{public}s is not running, launching manually", item.debugDescription)

                do {
                    try await item.launch()
                    os_log(.info, log: .networkProtection, "Launched login item with ID '%{public}s'", item.debugDescription)
                } catch {
                    os_log(.error, log: .networkProtection, "Login item with ID '%{public}s' could not be launched. Error: %{public}s", item.debugDescription, "\(error)")
                }
            }
        }
    }
}

#endif
