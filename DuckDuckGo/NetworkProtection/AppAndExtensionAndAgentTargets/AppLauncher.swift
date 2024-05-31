//
//  AppLauncher.swift
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

import AppKit
import Foundation
import Common
import NetworkProtectionUI

extension VPNAppLaunchCommand {
    public var rawValue: String {
        switch self {
        case .startVPN: return "startVPN"
        case .stopVPN: return "stopVPN"
        case .justOpen: return "justOpen"
        case .shareFeedback: return "shareFeedback"
        case .showFAQ: return "showFAQ"
        case .showStatus: return "showStatus"
        case .showSettings: return "showSettings"
        case .showVPNLocations: return "showVPNLocations"
        case .enableOnDemand: return "enableOnDemand"
        case .moveAppToApplications: return "moveAppToApplications"
        case .showPrivacyPro: return "showPrivacyPro"
        }
    }
}

protocol AppLaunchCommand {
    var allowsRunningApplicationSubstitution: Bool { get }
    var hideApp: Bool { get }
    var launchURL: URL? { get }
    var rawValue: String { get }
}

/// Launches the main App
///
final class AppLauncher {

    private let mainBundleURL: URL

    init(appBundleURL: URL) {
        mainBundleURL = appBundleURL
    }

    func launchApp(withCommand command: AppLaunchCommand) async {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.allowsRunningApplicationSubstitution = command.allowsRunningApplicationSubstitution
        configuration.arguments = [command.rawValue]

        if command.hideApp {
            configuration.activates = false
            configuration.addsToRecentItems = false
            configuration.createsNewApplicationInstance = true
            configuration.hides = true
        } else {
            configuration.activates = true
            configuration.addsToRecentItems = true
            configuration.createsNewApplicationInstance = false
            configuration.hides = false
        }

        do {
            if let launchURL = command.launchURL {
                try await NSWorkspace.shared.open([launchURL], withApplicationAt: mainBundleURL, configuration: configuration)
            }
        } catch {
            os_log("🔵 Open Application failed: %{public}@", type: .error, error.localizedDescription)
        }
    }
}

extension AppLauncher: VPNAppLaunching {
    func launchApp(withCommand command: NetworkProtectionUI.VPNAppLaunchCommand) async {
        await launchApp(withCommand: command as AppLaunchCommand)
    }
}

extension VPNAppLaunchCommand: AppLaunchCommand {
    var commandURL: String? {
        switch self {
        case .justOpen:
            return "networkprotection://just-open"
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
        default:
            return nil
        }
    }

    var allowsRunningApplicationSubstitution: Bool {
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

    var hideApp: Bool {
        switch self {
        case .startVPN, .stopVPN:
            return true
        default:
            return false
        }
    }
}

extension URL {

    func appending(_ path: String) -> URL {
        if #available(macOS 13.0, *) {
            return appending(path: path)
        } else {
            return appendingPathComponent(path)
        }
    }

}
