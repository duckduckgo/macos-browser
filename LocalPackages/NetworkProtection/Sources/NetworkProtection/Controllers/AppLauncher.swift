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

/// Launches the main App
///
open class AppLauncher {

    public enum Command: Codable {
        case justOpen
        case shareFeedback
        case showStatus
        case startVPN
        case stopVPN

        var commandURL: String? {
            switch self {
            case .justOpen:
                return "networkprotection://just-open"
            case .shareFeedback:
                return "https://form.asana.com/?k=_wNLt6YcT5ILpQjDuW0Mxw&d=137249556945"
            case .showStatus:
                return "networkprotection://show-status"
            default:
                return nil
            }
        }

        var helperAppPath: String? {
            switch self {
            case .startVPN:
                return "./Contents/Resources/startVPN.app"
            case .stopVPN:
                return "./Contents/Resources/stopVPN.app"
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

    private let mainBundleURL: URL

    public init(appBundleURL: URL) {
        mainBundleURL = appBundleURL
    }

    public func launchApp(withCommand command: Command) async {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.allowsRunningApplicationSubstitution = false

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
