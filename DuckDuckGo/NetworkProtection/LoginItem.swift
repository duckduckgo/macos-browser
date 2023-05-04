//
//  LoginItem.swift
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
import ServiceManagement

/// Extensible enum for login item identifiers
///
struct LoginItemIdentifier: RawRepresentable {
    /// Holds the key for the field from this target's Info.plist file that stores the string value
    /// of the Bundle ID of the login item that this identifier represents.
    ///
    var rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    init?(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// Takes care of enabling and disabling a login item.
///
final class LoginItem {
    private static let resetDelay = 200

    let agentBundleID: String

    convenience init(identifier: LoginItemIdentifier) {
        guard let agentBundleID = Bundle.main.object(forInfoDictionaryKey: identifier.rawValue) as? String else {
            fatalError("Please make sure that this target has key \(identifier.rawValue) in its Info.plist file.")
        }

        self.init(agentBundleID: agentBundleID)
    }

    init(agentBundleID: String) {
        self.agentBundleID = agentBundleID
    }

    func enable() throws {
        if #available(macOS 13.0, *) {
            try SMAppService.loginItem(identifier: agentBundleID).register()
        } else {
            SMLoginItemSetEnabled(agentBundleID as CFString, true)
        }
    }

    func disable() throws {
        if #available(macOS 13.0, *) {
            try SMAppService.loginItem(identifier: agentBundleID).unregister()
        } else {
            SMLoginItemSetEnabled(agentBundleID as CFString, false)
        }
    }

    func isRunning() -> Bool {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications

        for app in runningApps where app.bundleIdentifier == agentBundleID {
            return true
        }
        return false
    }

    /// Resets a login item.
    ///
    /// This call will only enable the login item if it was enabled to begin with.
    ///
    func reset() throws {
        try disable()
        try enable()
    }
}
