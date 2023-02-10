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

/// Contains logic for launching the App that contains this module.  We're using this to launch the App when a notification is clicked.
///
final class NetworkProtectionAppLauncher {
    func showNetPStatusInApp() {
        // - TODO: this could be best handled through logic in the initializer of this class to make it more generic
#if NETP_SYSTEM_EXTENSION
        let parentBundlePath = "../../../../"
#else
        let parentBundlePath = "../../../"
#endif
        let url: URL
        
        if #available(macOS 13, *) {
            url = URL(filePath: parentBundlePath, relativeTo: Bundle.main.bundleURL)
        } else {
            url = URL(fileURLWithPath: parentBundlePath, relativeTo: Bundle.main.bundleURL)
        }
        
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.allowsRunningApplicationSubstitution = false
        
        Task {
            do {
                try await NSWorkspace.shared.open([networkProtectionShowStatusURL], withApplicationAt: url, configuration: configuration)
            } catch {
                os_log("🔵 Open Application failed: %{public}@", type: .error, error.localizedDescription)
            }
        }
    }
}
