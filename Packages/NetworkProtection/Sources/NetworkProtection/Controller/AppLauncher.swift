//
//  NetworkProtectionAppLauncher.swift
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
import os

/// Launches the main App
///
public final class AppLauncher {
    public enum Command: Codable {
        case showStatus
        case startVPN
        case stopVPN

        enum CommandURL: String {
            case showStatus = "networkprotection://show-status"
        }

        public static let userDefaultsKey = "network-protection.AppLauncher.Command.userDefaultsKey"

        public var launchURL: URL? {
            switch self {
            case .showStatus:
                return URL(string: CommandURL.showStatus.rawValue)!
            default:
                return nil
            }
        }

        public var asArgument: String {
            switch self {
            case .startVPN:
                return "--startvpn"
            case .stopVPN:
                return "--stopvpn"
            default:
                return ""
            }
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

    private let url: URL

    public init(appBundleURL: URL) {
        url = appBundleURL
    }

    public func launchApp(withCommand command: Command) async {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.allowsRunningApplicationSubstitution = false
        configuration.arguments = [command.asArgument]

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
                try await NSWorkspace.shared.open([launchURL], withApplicationAt: url, configuration: configuration)
            } else {
                guard let defaults = UserDefaults(suiteName: "HKE973VLUW.com.duckduckgo.macos.browser.network-protection") else {
                    return
                }

                switch command {
                case .startVPN:
                    defaults.set(command.asArgument, forKey: AppLauncher.Command.userDefaultsKey)
                case .stopVPN:
                    defaults.set(command.asArgument, forKey: AppLauncher.Command.userDefaultsKey)
                default:
                    break
                }

                try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            }
        } catch {
            os_log("🔵 Open Application failed: %{public}@", type: .error, error.localizedDescription)
        }
    }
}
