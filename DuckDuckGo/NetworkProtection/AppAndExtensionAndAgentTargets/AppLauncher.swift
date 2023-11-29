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

#if (NETWORK_PROTECTION || NETP_SYSTEM_EXTENSION)

import AppKit
import Foundation
import Common
import NetworkProtection

extension AppLaunchCommand {
    var rawValue: String {
        switch self {
        case .startVPN: return "startVPN"
        case .stopVPN: return "stopVPN"
        case .justOpen: return "justOpen"
        case .shareFeedback: return "shareFeedback"
        case .showStatus: return "showStatus"
        case .showSettings: return "showSettings"
        case .enableOnDemand: return "enableOnDemand"
        }
    }
}

/// Launches the main App
///
public final class AppLauncher: AppLaunching {

    private let mainBundleURL: URL

    public init(appBundleURL: URL) {
        mainBundleURL = appBundleURL
    }

    public func launchApp(withCommand command: AppLaunchCommand) async {
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
            } else if let helperAppPath = command.helperAppPath {
                let launchURL = mainBundleURL.appending(helperAppPath)
                try await NSWorkspace.shared.openApplication(at: launchURL, configuration: configuration)
            }
        } catch {
            os_log("🔵 Open Application failed: %{public}@", type: .error, error.localizedDescription)
        }
    }
}

extension AppLaunchCommand {
    var commandURL: String? {
        switch self {
        case .justOpen:
            return "networkprotection://just-open"
        case .shareFeedback:
            return "https://form.asana.com/?k=_wNLt6YcT5ILpQjDuW0Mxw&d=137249556945"
        case .showStatus:
            return "networkprotection://show-status"
        case .showSettings:
            return "networkprotection://show-settings"
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

    var helperAppPath: String? {
        switch self {
        case .startVPN:
            return "Contents/Resources/startVPN.app"
        case .stopVPN:
            return "Contents/Resources/stopVPN.app"
        case .enableOnDemand:
            return "Contents/Resources/enableOnDemand.app"
        default:
            return nil
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

#endif
