//
//  AppInfoRetriever.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

public protocol AppInfoRetrieveing {

    /// Provides a structure featuring commonly-used app info.
    ///
    /// It's also possible to retrieve the individual information directly by calling other methods in this class.
    ///
    func getAppInfo(bundleID: String) -> AppInfo?
    func getAppInfo(appURL: URL) -> AppInfo?
    func getAppIcon(bundleID: String) -> NSImage?
    func getAppName(bundleID: String) -> String?
    func getBundleID(appURL: URL) -> String?

}

public class AppInfoRetriever: AppInfoRetrieveing {

    public init() {}

    public func getAppInfo(bundleID: String) -> AppInfo? {
        guard let appName = getAppName(bundleID: bundleID) else {
            return nil
        }

        let appIcon = getAppIcon(bundleID: bundleID)
        return AppInfo(bundleID: bundleID, name: appName, icon: appIcon)
    }

    public func getAppInfo(appURL: URL) -> AppInfo? {
        guard let bundleID = getBundleID(appURL: appURL) else {
            return nil
        }

        return getAppInfo(bundleID: bundleID)
    }

    public func getAppIcon(bundleID: String) -> NSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }

        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let plist = NSDictionary(contentsOf: infoPlistURL),
              let iconFileName = plist["CFBundleIconFile"] as? String else {
            return nil
        }

        // Ensure the icon has the correct extension
        let iconFile = iconFileName.hasSuffix(".icns") ? iconFileName : "\(iconFileName).icns"
        let iconURL = appURL.appendingPathComponent("Contents/Resources/\(iconFile)")

        return NSImage(contentsOf: iconURL)
    }

    public func getAppName(bundleID: String) -> String? {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            // Try reading from Info.plist
            let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
            if let plist = NSDictionary(contentsOf: infoPlistURL),
               let appName = plist["CFBundleDisplayName"] as? String {
                return appName
            }
            // Fallback: Use the app bundle's filename
            return appURL.deletingPathExtension().lastPathComponent
        }
        return nil
    }

    public func getAppURL(bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    public func getBundleID(appURL: URL) -> String? {
        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        if let plist = NSDictionary(contentsOf: infoPlistURL),
           let bundleID = plist["CFBundleIdentifier"] as? String {
            return bundleID
        }
        return nil
    }

    // MARK: - Embedded Bundle IDs

    public func findEmbeddedBundleIDs(in bundleURL: URL) -> Set<String> {
        var bundleIDs: [String] = []
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(at: bundleURL,
                                                      includingPropertiesForKeys: nil,
                                                      options: [.skipsHiddenFiles],
                                                      errorHandler: nil) else {
            return []
        }

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "app" {
            let embeddedBundle = Bundle(url: fileURL)
            if let bundleID = embeddedBundle?.bundleIdentifier {
                bundleIDs.append(bundleID)
            }
        }

        return Set(bundleIDs)
    }
}
