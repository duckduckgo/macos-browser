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

import ServiceManagement

/// Takes care of enabling and disabling a login item.
///
final class LoginItem {
    private static let resetDelay = 200

    let agentBundleID: String

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

    func reset() async throws {
        try? disable()

        if #available(macOS 13, *) {
            try await Task.sleep(for: .milliseconds(Self.resetDelay))
        } else {
            try await Task.sleep(nanoseconds: UInt64(Self.resetDelay) * NSEC_PER_MSEC)
        }

        try enable()
    }
}
