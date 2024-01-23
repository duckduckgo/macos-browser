//
//  LoginItemsManager.swift
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

/// Class to manage the login items for Network Protection and DBP
/// 
final class LoginItemsManager {
    // MARK: - Main Interactions

    func enableLoginItems(_ items: Set<LoginItem>, log: OSLog) {
        updateLoginItems(items, whatAreWeDoing: "enable", using: LoginItem.enable)
    }

    func restartLoginItems(_ items: Set<LoginItem>, log: OSLog) {
        updateLoginItems(items, whatAreWeDoing: "restart", using: LoginItem.restart)
    }

    func disableLoginItems(_ items: Set<LoginItem>) {
        for item in items {
            if item == .dbpBackgroundAgent {
                os_log("ELLETEST LoginItemsManager.disableLoginItems", log: .dbp, type: .info)
            }
            try? item.disable()
        }
    }

    // MARK: - Debug Interactions

    func resetLoginItems(_ items: Set<LoginItem>) async throws {
        for item in items {
            try? item.disable()
        }
    }

    // MARK: - Misc Utility

    private func updateLoginItems(_ items: Set<LoginItem>, whatAreWeDoing: String, using action: (LoginItem) -> () throws -> Void) {
        for item in items {
            do {
                if item == .dbpBackgroundAgent {
                    os_log("ELLETEST LoginItemsManager.updateLoginItem doing action", log: .dbp, type: .info)
                }
                try action(item)()
                if item == .dbpBackgroundAgent {
                    os_log("ELLETEST Updating login item did not throw an error", log: .dbp, type: .info)
                }
            } catch let error as NSError {
                let event = Pixel.Event.Debug.loginItemUpdateError(
                    loginItemBundleID: item.agentBundleID,
                    action: whatAreWeDoing,
                    buildType: AppVersion.shared.buildType,
                    osVersion: AppVersion.shared.osVersion
                )

                DailyPixel.fire(pixel: .debug(event: event, error: error), frequency: .dailyAndCount, includeAppVersionParameter: true)
                logOrAssertionFailure("🔴 Could not \(whatAreWeDoing) \(item): \(error.debugDescription)")
                if item == .dbpBackgroundAgent {
                    os_log("ELLETEST Updating login item threw an error: \(error.debugDescription)", log: .dbp, type: .info)
                }
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
}
