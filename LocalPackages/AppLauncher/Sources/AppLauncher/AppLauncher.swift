//
//  AppLauncher.swift
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

public protocol AppLaunching {
    func launchApp(withCommand command: AppLaunchCommand) async throws
    func runApp(withCommand command: AppLaunchCommand) async throws -> NSRunningApplication
}

/// Launches the main App
///
public final class AppLauncher: AppLaunching {

    public enum AppLaunchError: CustomNSError {
        case workspaceOpenError(_ error: Error)

        public var errorCode: Int {
            switch self {
            case .workspaceOpenError: return 0
            }
        }

        public var errorUserInfo: [String: Any] {
            switch self {
            case .workspaceOpenError(let error):
                return [NSUnderlyingErrorKey: error as NSError]
            }
        }
    }

    private let mainBundleURL: URL
    private var workspace: NSWorkspace
    private var fileManager: FileManager

    public init(appBundleURL: URL,
                workspace: NSWorkspace = .shared,
                fileManager: FileManager = .default) {
        mainBundleURL = appBundleURL
        self.workspace = workspace
        self.fileManager = fileManager
    }

    public func launchApp(withCommand command: AppLaunchCommand) async throws {
        _ = try await runApp(withCommand: command)
    }

    /// The only difference with launchApp is this method returns the `NSRunningApplication`
    ///
    public func runApp(withCommand command: AppLaunchCommand) async throws -> NSRunningApplication {

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.allowsRunningApplicationSubstitution = command.allowsRunningApplicationSubstitution

        if command.hideApp {
            configuration.activates = false
            configuration.addsToRecentItems = false
            configuration.createsNewApplicationInstance = true
            configuration.hides = true
        } else {
            configuration.activates = true
            configuration.addsToRecentItems = true
            configuration.createsNewApplicationInstance = false
            configuration.hides = false
        }

        do {
            if let launchURL = command.launchURL {
                return try await workspace.open([launchURL], withApplicationAt: mainBundleURL, configuration: configuration)
            } else {
                return try await workspace.openApplication(at: mainBundleURL, configuration: configuration)
            }
        } catch {
            throw AppLaunchError.workspaceOpenError(error)
        }
    }

    public func targetAppExists() -> Bool {
        fileManager.fileExists(atPath: mainBundleURL.path)
    }
}
