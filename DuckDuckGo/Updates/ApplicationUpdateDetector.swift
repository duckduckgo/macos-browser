//
//  ApplicationUpdateDetector.swift
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

final class ApplicationUpdateDetector {

    private static var hasCheckedForUpdate = false
    private static var updateStatus: AppUpdateStatus = .noChange

    @UserDefaultsWrapper(key: .previousAppVersion, defaultValue: nil)
    private static var previousAppVersion: String?

    @UserDefaultsWrapper(key: .previousBuild, defaultValue: nil)
    private static var previousAppBuild: String?

    static func isApplicationUpdated(currentVersion: String? = nil,
                                     currentBuild: String? = nil,
                                     previousVersion: String? = nil,
                                     previousBuild: String? = nil) -> AppUpdateStatus {
        // If the update check has already been performed, return the cached result
        if hasCheckedForUpdate {
            return updateStatus
        }

        let currentVersion = currentVersion ?? getCurrentAppVersion()
        let currentBuild = currentBuild ?? getCurrentAppBuild()
        let previousVersion = previousVersion ?? self.previousAppVersion
        let previousBuild = previousBuild ?? self.previousAppBuild

        // Save the current version and build to user defaults for future comparisons
        Self.previousAppVersion = currentVersion
        Self.previousAppBuild = currentBuild

        // Determine the update status
        if currentVersion == previousVersion {
            if let currentBuild = currentBuild, let previousBuild = previousBuild {
                if currentBuild == previousBuild {
                    updateStatus = .noChange
                } else if compareSemanticVersion(currentBuild, isGreaterThan: previousBuild) {
                    updateStatus = .updated
                } else {
                    updateStatus = .downgraded
                }
            } else {
                updateStatus = .noChange
            }
        } else if let currentVersion = currentVersion, let previousVersion = previousVersion {
            if compareSemanticVersion(currentVersion, isGreaterThan: previousVersion) {
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

    private static func compareSemanticVersion(_ version1: String, isGreaterThan version2: String) -> Bool {
        let version1Components = version1.split(separator: ".").compactMap { Int($0) }
        let version2Components = version2.split(separator: ".").compactMap { Int($0) }

        for (v1, v2) in zip(version1Components, version2Components) where v1 != v2 {
            return v1 > v2
        }

        return version1Components.count > version2Components.count
    }

    private static func getCurrentAppVersion() -> String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    private static func getCurrentAppBuild() -> String? {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

#if DEBUG
    static func resetState() {
        hasCheckedForUpdate = false
    }
#endif
}
