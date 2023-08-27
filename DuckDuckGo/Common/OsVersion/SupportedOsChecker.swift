//
//  SupportedOsChecker.swift
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

import Foundation

final class SupportedOSChecker {

    struct SupportedVersion {
        static let major = 11
        static let minor = 4
        static let patch = 0
    }

    private static let currentOSVersion = ProcessInfo.processInfo.operatingSystemVersion

    // Check if the current macOS version is at least the supported version
    static var isCurrentOSReceivingUpdates: Bool {
        if currentOSVersion.majorVersion > SupportedVersion.major {
            return true
        }
        if currentOSVersion.majorVersion == SupportedVersion.major {
            if currentOSVersion.minorVersion > SupportedVersion.minor {
                return true
            }
            if currentOSVersion.minorVersion == SupportedVersion.minor && currentOSVersion.patchVersion >= SupportedVersion.patch {
                return true
            }
        }
        return false
    }
}
