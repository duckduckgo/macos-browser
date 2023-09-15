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
        if #available(macOS 11.4, *) {
            for argument in CommandLine.arguments {
                os_log("🔵 DEBUG: AppMain launching with command line argument %{public}@", type: .error, argument)
            }
            
            for argument in ProcessInfo.processInfo.arguments {
                os_log("🔵 DEBUG: AppMain launching with argument %{public}@", type: .error, argument)
            }
            
            if let variable = ProcessInfo.processInfo.environment["NetworkProtectionLaunchAction"] {
                os_log("🔵 DEBUG: AppMain launching with environment variable %{public}s", type: .error, variable)
            } else {
                os_log("🔵 DEBUG: AppMain launching without environment variable", type: .error)
            }
            
            if ProcessInfo.processInfo.arguments.contains("startVPN") {
                os_log("🔵 DEBUG: AppMain launching with startVPN", type: .error)
                
                swizzleMainBundle()

                Task {
                    await NetworkProtectionTunnelController().start(enableLoginItems: false)
                    exit(0)
                }

                dispatchMain()
            } else if ProcessInfo.processInfo.arguments.contains("stopVPN") {
                os_log("🔵 DEBUG: AppMain launching with stopVPN", type: .error)
                
                swizzleMainBundle()

                Task {
                    await NetworkProtectionTunnelController().stop()
                    exit(0)
                }

                dispatchMain()
            }
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
