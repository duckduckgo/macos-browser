//
//  ThirdPartyBrowser.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

struct ThirdPartyBrowser {

    static var brave: ThirdPartyBrowser { ThirdPartyBrowser(type: .brave) }
    static var chrome: ThirdPartyBrowser { ThirdPartyBrowser(type: .chrome) }
    static var edge: ThirdPartyBrowser { ThirdPartyBrowser(type: .edge) }
    static var firefox: ThirdPartyBrowser { ThirdPartyBrowser(type: .firefox) }

    static func browser(for source: DataImport.Source) -> ThirdPartyBrowser? {
        switch source {
        case .brave:
            return Self.brave
        case .chrome:
            return Self.chrome
        case .edge:
            return Self.edge
        case .firefox:
            return Self.firefox
        case .csv:
            return nil
        }
    }

    var isInstalled: Bool {
        return NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: bundleID) != nil
    }

    var isRunning: Bool {
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    var applicationIcon: NSImage? {
        guard let applicationPath = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }

        return NSWorkspace.shared.icon(forFile: applicationPath)
    }

    private enum `Type` {
        case brave
        case chrome
        case edge
        case firefox
    }

    private var bundleID: String {
        switch type {
        case .brave: return "com.brave.Browser"
        case .chrome: return "com.google.Chrome"
        case .edge: return "com.microsoft.edgemac"
        case .firefox: return "org.mozilla.firefox"
        }
    }

    private let type: Type

    @discardableResult
    func forceTerminate() -> Bool {
        let application = findRunningApplication()
        return application?.forceTerminate() ?? false
    }

    private func findRunningApplication() -> NSRunningApplication? {
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
    }

}
