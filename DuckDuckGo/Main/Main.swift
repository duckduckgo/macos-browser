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

extension Bundle {
    static var mainURL: URL!
    @objc dynamic static func nonMain() -> Bundle {
        Bundle(url: mainURL)!
    }
}

@main
final class AppMain {
    private enum LaunchError: Error {
        case unhandled(code: Int32)
        case startVPNFailed(_ error: Error)
        case stopVPNFailed(_ error: Error)
    }

    static func main() async throws {
        let arguments = ProcessInfo.processInfo.arguments

        switch (CommandLine.arguments.first! as NSString).lastPathComponent {
        case "startVPN":
            swizzleMainBundle()

            do {
                try await DefaultNetworkProtectionProvider().start(enableLoginItems: false)
                exit(0)
            } catch {
                throw LaunchError.startVPNFailed(error)
            }
        case "stopVPN":
            swizzleMainBundle()

            do {
                try await DefaultNetworkProtectionProvider().stop()
                exit(0)
            } catch {
                throw LaunchError.stopVPNFailed(error)
            }
        default:
            break
        }

        let result = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)

        if result != 0 {
            throw LaunchError.unhandled(code: result)
        }
    }

    private static func swizzleMainBundle() {
        Bundle.mainURL = URL(fileURLWithPath: CommandLine.arguments.first!).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

        let m1 = class_getClassMethod(Bundle.self, #selector(getter: Bundle.main))!
        let m2 = class_getClassMethod(Bundle.self, #selector(Bundle.nonMain))!

        method_exchangeImplementations(m1, m2)
    }
}
