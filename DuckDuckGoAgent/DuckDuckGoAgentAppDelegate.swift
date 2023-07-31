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

    /// when enabled VPN connection will be automatically initiated on launch even if disconnected manually (Always On rule disabled)
    @UserDefaultsWrapper(key: .networkProtectionConnectOnLogIn, defaultValue: NetworkProtectionUserDefaultsConstants.shouldConnectOnLogIn, defaults: .shared)
    private var shouldAutoConnect: Bool

    /// Agent launch time saved by the main app to distinguish between log-in launch and main app launch
    @UserDefaultsWrapper(key: .agentLaunchTime, defaultValue: .distantPast, defaults: .shared)
    private var agentLaunchTime: Date
    private static let recentThreshold: TimeInterval = 5.0

    private lazy var appLauncher: AppLauncher = {
        let appBundleURL: URL
        let parentBundlePath = "../../../../"

        if #available(macOS 13, *) {
            appBundleURL = URL(filePath: parentBundlePath, relativeTo: Bundle.main.bundleURL)
        } else {
            appBundleURL = URL(fileURLWithPath: parentBundlePath, relativeTo: Bundle.main.bundleURL)
        }

        return AppLauncher(appBundleURL: appBundleURL)
    }()

    /// The status bar NetworkProtection menu
    ///
    /// For some reason the App will crash if this is initialized right away, which is why it was changed to be lazy.
    ///
    private lazy var networkProtectionMenu: StatusBarMenu = {
        #if DEBUG
        let iconProvider = DebugMenuIconProvider()
        #elseif REVIEW
        let iconProvider = ReviewMenuIconProvider()
        #else
        let iconProvider = MenuIconProvider()
        #endif

        return StatusBarMenu(appLauncher: appLauncher, iconProvider: iconProvider)
    }()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        os_log("DuckDuckGoAgent started", log: .networkProtectionLoginItemLog, type: .info)
        networkProtectionMenu.show()

        // Connect on Log In
        if shouldAutoConnect,
           // are we launched by the system?
           agentLaunchTime.addingTimeInterval(Self.recentThreshold) > Date() {
            Task {
                await appLauncher.launchApp(withCommand: .startVPN)
            }
        }
    }
}

extension NSApplication {

    enum RunType: Int, CustomStringConvertible {
        case normal
        var description: String {
            switch self {
            case .normal: return "normal"
            }
        }
    }
    static var runType: RunType { .normal }

}
