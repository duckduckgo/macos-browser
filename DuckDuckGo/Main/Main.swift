//
//  Main.swift
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

#if NETWORK_PROTECTION
import NetworkProtection
#endif

extension Bundle {
    static var mainURL: URL!
    @objc dynamic static func nonMain() -> Bundle {
        Bundle(url: mainURL)!
    }
}

@main
final class AppMain {
    private enum LaunchError: Error {
        case startVPNFailed(_ error: Error)
    }

    static func main() {
#if NETWORK_PROTECTION

        // If the app is sandboxed, attempt to use the symlink approach for determining launch command:
        if let launchPath = (CommandLine.arguments.first as NSString?)?.lastPathComponent {
            switch launchPath {
            case AppLaunchCommand.startVPN.rawValue:
                swizzleMainBundle()

                Task {
                    await NetworkProtectionTunnelController().start(enableLoginItems: false)
                    exit(0)
                }

                dispatchMain()

            case AppLaunchCommand.stopVPN.rawValue:
                swizzleMainBundle()

                Task {
                    await NetworkProtectionTunnelController().stop()
                    exit(0)
                }

                dispatchMain()
            default: break
            }
        }

        // If the app is not sandboxed, read the process arguments to determine launch command:
        if ProcessInfo.processInfo.arguments.contains(AppLaunchCommand.startVPN.rawValue) {
            swizzleMainBundle()

            Task {
                await NetworkProtectionTunnelController().start(enableLoginItems: false)
                exit(0)
            }

            dispatchMain()
        } else if ProcessInfo.processInfo.arguments.contains(AppLaunchCommand.stopVPN.rawValue) {
            swizzleMainBundle()

            Task {
                await NetworkProtectionTunnelController().stop()
                exit(0)
            }

            dispatchMain()
        }

#endif

#if !APPSTORE && !DEBUG && !DBP
        PFMoveToApplicationsFolderIfNecessary()
#endif

        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }

    private static func swizzleMainBundle() {
        Bundle.mainURL = Bundle(for: Self.self).bundleURL

        let m1 = class_getClassMethod(Bundle.self, #selector(getter: Bundle.main))!
        let m2 = class_getClassMethod(Bundle.self, #selector(Bundle.nonMain))!
        method_exchangeImplementations(m1, m2)

        // since initially our bundle id doesn‘t match the main app, UserDefaults won‘t be loaded by default
        UserDefaults.standard.addSuite(named: Bundle.main.bundleIdentifier!)
    }
}
