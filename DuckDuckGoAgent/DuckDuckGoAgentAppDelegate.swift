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
import NetworkExtension
import NetworkProtection
import NetworkProtectionUI

@objc(Application)
final class DuckDuckGoAgentApplication: NSApplication {
    private let _delegate = DuckDuckGoAgentAppDelegate()

    override init() {
        os_log(.error, log: .networkProtection, "🟢 Status Bar Agent starting: %{public}d", NSRunningApplication.current.processIdentifier)

        // prevent agent from running twice
        if let anotherInstance = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!).first(where: { $0 != .current }) {
            os_log(.error, log: .networkProtection, "🔴 Stopping: another instance is running: %{public}d.", anotherInstance.processIdentifier)
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
final class DuckDuckGoAgentAppDelegate: NSObject, NSApplicationDelegate {

    /// The status bar NetworkProtection menu
    ///
    /// For some reason the App will crash if this is initialized right away, which is why it was changed to be lazy.
    ///
    private lazy var networkProtectionMenu = NetworkProtectionUI.StatusBarMenu()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        os_log("DuckDuckGoAgent started", log: .networkProtectionLoginItemLog, type: .info)
        networkProtectionMenu.show()

        let mainAppURL: URL
        let parentBundlePath = "../../../../"
        if #available(macOS 13, *) {
            mainAppURL = URL(filePath: parentBundlePath, relativeTo: Bundle.main.bundleURL)
        } else {
            mainAppURL = URL(fileURLWithPath: parentBundlePath, relativeTo: Bundle.main.bundleURL)
        }

        // fallback for system extension failing to launch helper tools directly
        DistributedNotificationCenter.default().publisher(for: .stopVPN).sink { _ in
            Task {
                try await AppLauncher(appBundleURL: mainAppURL).launchApp(withCommand: .stopVPN)
            }
        }.store(in: &cancellables)
        DistributedNotificationCenter.default().publisher(for: .startVPN).sink { _ in
            Task {
                try await AppLauncher(appBundleURL: mainAppURL).launchApp(withCommand: .startVPN)
            }
        }.store(in: &cancellables)
        DistributedNotificationCenter.default().publisher(for: .enableOnDemand).sink { _ in
            Task {
                try await AppLauncher(appBundleURL: mainAppURL).launchApp(withCommand: .enableOnDemand)
            }
        }.store(in: &cancellables)
    }
}
