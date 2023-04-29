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
import os
import NetworkProtection

@main
final class AppMain {
    private enum LaunchError: Error {
        case unhandled(code: Int32)
        case startVPNFailed(_ error: Error)
        case stopVPNFailed(_ error: Error)
    }

    static func main() async throws {
        let arguments = ProcessInfo.processInfo.arguments
        var command: String?

        if let defaults = AppGroupHelper.shared.userDefaults {
            defaults.synchronize()
            if let argumentTimestamp = defaults.object(forKey: AppLauncher.Command.userDefaultsArgumentTimestampKey) as? Date,
               argumentTimestamp.timeIntervalSinceNow < AppLauncher.Command.argumentTimestampExpirationThreshold {
                command = defaults.string(forKey: AppLauncher.Command.userDefaultsArgumentKey)
            } else {
                command = ""
            }
            defaults.removeObject(forKey: AppLauncher.Command.userDefaultsArgumentKey)
        }

        if command == AppLauncher.Command.startVPN.asArgument || arguments.contains(AppLauncher.Command.startVPN.asArgument) {
            do {
                try await DefaultNetworkProtectionProvider().start()
                exit(0)
            } catch {
                throw LaunchError.startVPNFailed(error)
            }
        } else if command == AppLauncher.Command.stopVPN.asArgument || arguments.contains(AppLauncher.Command.stopVPN.asArgument) {
            do {
                try await DefaultNetworkProtectionProvider().stop()
                exit(0)
            } catch {
                throw LaunchError.stopVPNFailed(error)
            }
        }

        let result = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)

        if result != 0 {
            throw LaunchError.unhandled(code: result)
        }
    }

    private func startupArguments() -> String {
        return ""
    }
}
