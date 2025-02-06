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

/// Protocol to provide a mechanism to query information about installed Applications.
///
public protocol AppInfoRetrieving {

    /// Provides a structure featuring commonly-used app info given the Application's bundleID.
    ///
    /// - Parameters:
    ///     - bundleID: the bundleID of the target Application.
    ///
    func getAppInfo(bundleID: String) -> AppInfo?

    /// Provides a structure featuring commonly-used app info, given the Application's URL.
    ///
    /// - Parameters:
    ///     - appURL: the URL where the target Application is installed.
    ///
    func getAppInfo(appURL: URL) -> AppInfo?

    /// Obtains the icon for a specified application.
    ///
    /// - Parameters:
    ///     - bundleID: the bundleID of the target Application.
    ///
    func getAppIcon(bundleID: String) -> NSImage?

    /// Obtains the URL for a specified application.
    ///
    /// - Parameters:
    ///     - bundleID: the bundleID of the target Application.
    ///
    func getAppURL(bundleID: String) -> URL?

    /// Obtains the visible name for a specified application.
    ///
    /// - Parameters:
    ///     - bundleID: the bundleID of the target Application.
    ///
    func getAppName(bundleID: String) -> String?

    /// Obtains the bundleID for a specified application.
    ///
    /// - Parameters:
    ///     - appURL: the URL where the target Application is installed.
    ///
    func getBundleID(appURL: URL) -> String?

    /// Obtains the bundleIDs for all Applications embedded within a speciried application.
    ///
    /// - Parameters:
    ///     - bundleURL: the URL where the parent Application is installed.
    ///
    func findEmbeddedBundleIDs(in bundleURL: URL) -> Set<String>
}

/// Provides a mechanism to query information about installed Applications.
///
public class AppInfoRetriever: AppInfoRetrieving {

    public init() {}

    /// Provides a structure featuring commonly-used app info given the Application's bundleID.
    ///
    /// - Parameters:
    ///     - bundleID: the bundleID of the target Application.
    ///
    public func getAppInfo(bundleID: String) -> AppInfo? {
        guard let appName = getAppName(bundleID: bundleID) else {
            return nil
        }

        let appIcon = getAppIcon(bundleID: bundleID)
        return AppInfo(bundleID: bundleID, name: appName, icon: appIcon)
    }

    /// Provides a structure featuring commonly-used app info, given the Application's URL.
    ///
    /// - Parameters:
    ///     - appURL: the URL where the target Application is installed.
    ///
    public func getAppInfo(appURL: URL) -> AppInfo? {
        guard let bundleID = getBundleID(appURL: appURL) else {
            return nil
        }

        return getAppInfo(bundleID: bundleID)
    }

    /// Obtains the icon for a specified application.
    ///
    /// - Parameters:
    ///     - bundleID: the bundleID of the target Application.
    ///
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

    /// Obtains the visible name for a specified application.
    ///
    /// - Parameters:
    ///     - bundleID: the bundleID of the target Application.
    ///
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

    /// Obtains the URL for a specified application.
    ///
    /// - Parameters:
    ///     - bundleID: the bundleID of the target Application.
    ///
    public func getAppURL(bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    /// Obtains the bundleID for a specified application.
    ///
    /// - Parameters:
    ///     - appURL: the URL where the target Application is installed.
    ///
    public func getBundleID(appURL: URL) -> String? {
        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        if let plist = NSDictionary(contentsOf: infoPlistURL),
           let bundleID = plist["CFBundleIdentifier"] as? String {
            return bundleID
        }
        return nil
    }

    // MARK: - Embedded Bundle IDs

    /// Obtains the bundleIDs for all Applications embedded within a speciried application.
    ///
    /// - Parameters:
    ///     - bundleURL: the URL where the parent Application is installed.
    ///
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
