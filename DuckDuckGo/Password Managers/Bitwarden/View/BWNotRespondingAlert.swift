//
//  BWNotRespondingAlert.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

final class BWNotRespondingAlert: NSAlert {

    static func show() {
        alert = BWNotRespondingAlert()
        if alert?.runModal() == .alertFirstButtonReturn {
            alert?.restartBitwarden()
        }
    }

    private static var alert: BWNotRespondingAlert?

    override init() {
        super.init()

        messageText = UserText.restartBitwardenInfo
        alertStyle = .warning
        addButton(withTitle: UserText.restartBitwarden)
        addButton(withTitle: UserText.cancel)
    }

    private func restartBitwarden() {
#if !APPSTORE
        let runningApplications = NSWorkspace.shared.runningApplications
        let bitwarden = runningApplications.first { runningApplication in
            runningApplication.bundleIdentifier == BWManager.bundleId
        }

        bitwarden?.terminate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: BWManager.bundleId) {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            }
        }
#endif
    }

}
