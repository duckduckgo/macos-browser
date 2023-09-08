//
//  DuckDuckGoAgentAppDelegate.swift
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

import Cocoa
import Combine
import Common
import ServiceManagement
import DataBrokerProtection

@objc(Application)
final class DuckDuckGoDBPBackgroundAgentApplication: NSApplication {
    private let _delegate = DuckDuckGoDBPBackgroundAgentAppDelegate()

    override init() {
        // TODO logging
        os_log("yaaaaaaaaaaaaay")
        //os_log(.error, log: .networkProtection, "🟢 Status Bar Agent starting: %{public}d", NSRunningApplication.current.processIdentifier)

        // prevent agent from running twice
        if let anotherInstance = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!).first(where: { $0 != .current }) {
            //os_log(.error, log: .networkProtection, "🔴 Stopping: another instance is running: %{public}d.", anotherInstance.processIdentifier)
            exit(0)
        }

        super.init()
        self.delegate = _delegate
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@main
final class DuckDuckGoDBPBackgroundAgentAppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // TODO logging
        //os_log("DuckDuckGoAgent started", log: .networkProtectionLoginItemLog, type: .info)

        let manager = DataBrokerProtectionBackgroundManager.shared
        manager.runOperationsAndStartSchedulerIfPossible()
    }
}
