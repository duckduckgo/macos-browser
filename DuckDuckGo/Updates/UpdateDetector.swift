//
//  UpdateDetector.swift
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

import Foundation

enum AppUpdateStatus {
    case noChange
    case updated
    case downgraded
}

final class UpdateDetector {

    private static let previousVersionKey = "previousAppVersion"
    private static let previousBuildKey = "previousAppBuild"
    private static var hasCheckedForUpdate = false
    private static var updateStatus: AppUpdateStatus = .noChange

    static func isApplicationUpdated() -> AppUpdateStatus {
        // If the update check has already been performed, return the cached result
        if hasCheckedForUpdate {
            return updateStatus
        }

        let currentVersion = getCurrentAppVersion()
        let currentBuild = getCurrentAppBuild()
        let previousVersion = getPreviousAppVersion()
        let previousBuild = getPreviousAppBuild()

        // Save the current version and build to user defaults for future comparisons
        saveCurrentAppVersion(currentVersion)
        saveCurrentAppBuild(currentBuild)

        // Determine the update status
        if currentVersion == previousVersion {
            if let currentBuild = currentBuild, let previousBuild = previousBuild {
                if currentBuild == previousBuild {
                    updateStatus = .noChange
                } else if currentBuild > previousBuild {
                    updateStatus = .updated
                } else {
                    updateStatus = .downgraded
                }
            } else {
                updateStatus = .noChange
            }
        } else if let currentVersion = currentVersion, let previousVersion = previousVersion {
            if currentVersion > previousVersion {
                updateStatus = .updated
            } else {
                updateStatus = .downgraded
            }
        } else {
            updateStatus = .noChange
        }

        hasCheckedForUpdate = true
        return updateStatus
    }

    private static func getCurrentAppVersion() -> String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    private static func getCurrentAppBuild() -> String? {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    private static func getPreviousAppVersion() -> String? {
        return UserDefaults.standard.string(forKey: previousVersionKey)
    }

    private static func getPreviousAppBuild() -> String? {
        return UserDefaults.standard.string(forKey: previousBuildKey)
    }

    private static func saveCurrentAppVersion(_ version: String?) {
        UserDefaults.standard.set(version, forKey: previousVersionKey)
    }

    private static func saveCurrentAppBuild(_ build: String?) {
        UserDefaults.standard.set(build, forKey: previousBuildKey)
    }
}
