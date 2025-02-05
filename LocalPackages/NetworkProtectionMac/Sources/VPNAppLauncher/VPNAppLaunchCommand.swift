//
//  VPNAppLaunchCommand.swift
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
import Foundation

public enum VPNAppLaunchCommand: Codable, AppLaunchCommand {
    case justOpen
    case manageExcludedApps
    case manageExcludedDomains
    case shareFeedback
    case showFAQ
    case showStatus
    case showSettings
    case showVPNLocations
    case moveAppToApplications
    case showPrivacyPro

    var commandURL: String? {
        switch self {
        case .justOpen:
            return "networkprotection://just-open"
        case .manageExcludedApps:
            return "networkprotection://excluded-apps"
        case .manageExcludedDomains:
            return "networkprotection://excluded-domains"
        case .shareFeedback:
            return "networkprotection://share-feedback"
        case .showFAQ:
            return "https://duckduckgo.com/duckduckgo-help-pages/privacy-pro/vpn/"
        case .showStatus:
            return "networkprotection://show-status"
        case .showSettings:
            return "networkprotection://show-settings"
        case .showVPNLocations:
            return "networkprotection://show-settings/locations"
        case .moveAppToApplications:
            return "networkprotection://move-app-to-applications"
        case .showPrivacyPro:
            return "networkprotection://show-privacy-pro"
        }
    }

    public var allowsRunningApplicationSubstitution: Bool {
        switch self {
        case .showSettings:
            return true
        default:
            return false
        }
    }

    public var launchURL: URL? {
        guard let commandURL else {
            return nil
        }

        return URL(string: commandURL)!
    }

    public var hideApp: Bool {
        switch self {
        default:
            return false
        }
    }
}
