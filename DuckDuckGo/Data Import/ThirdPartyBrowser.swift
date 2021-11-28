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

private struct BundleIdentifiers {
    let production: String
    let all: [String]

    init(productionBundleID: String, relatedBundleIDs: [String]) {
        self.production = productionBundleID
        self.all = [productionBundleID] + relatedBundleIDs
    }
}

enum ThirdPartyBrowser: CaseIterable {

    case brave
    case chrome
    case edge
    case firefox
    case safari
    
    static var installedBrowsers: [ThirdPartyBrowser] {
        return allCases.filter(\.isInstalled)
    }

    static func browser(for source: DataImport.Source) -> ThirdPartyBrowser? {
        switch source {
        case .brave: return .brave
        case .chrome: return .chrome
        case .edge: return .edge
        case .firefox: return .firefox
        case .safari: return .safari
        case .csv: return nil
        }
    }

    var isInstalled: Bool {
        return applicationPath != nil
    }

    var isRunning: Bool {
        return !findRunningApplications().isEmpty
    }
    
    var importSource: DataImport.Source {
        switch self {
        case .brave: return .brave
        case .chrome: return .chrome
        case .edge: return .edge
        case .firefox: return .firefox
        case .safari: return .safari
        }
    }

    var applicationIcon: NSImage? {
        guard let applicationPath = applicationPath else {
            return nil
        }

        return NSWorkspace.shared.icon(forFile: applicationPath)
    }

    var browserProfiles: DataImport.BrowserProfileList? {
        let profilePath = profilesDirectory()

        guard let potentialProfileURLs = try? FileManager.default.contentsOfDirectory(at: profilePath,
                                                                                      includingPropertiesForKeys: nil,
                                                                                      options: [.skipsHiddenFiles]).filter(\.hasDirectoryPath) else {
            // Safari is an exception, as it may need permissions granted before being able to read the contents of the profile path. To be safe,
            // return the profile anyway and check the file system permissions when preparing to import.
            if self == .safari {
                return DataImport.BrowserProfileList(browser: self, profileURLs: [profilePath])
            } else {
                return nil
            }
        }

        return DataImport.BrowserProfileList(browser: self, profileURLs: potentialProfileURLs)
    }

    // Returns the first available path to the application. This will test the production bundle ID, and any known pre-release versions, such as the
    // Firefox Nightly build.
    private var applicationPath: String? {
        for bundleID in bundleIdentifiers.all {
            if let path = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: bundleID) {
                return path
            }
        }

        return nil
    }

    private var bundleIdentifiers: BundleIdentifiers {
        switch self {
        case .brave: return BundleIdentifiers(productionBundleID: "com.brave.Browser", relatedBundleIDs: ["com.brave.Browser.nightly"])
        case .chrome: return BundleIdentifiers(productionBundleID: "com.google.Chrome", relatedBundleIDs: ["com.google.Chrome.canary"])
        case .edge: return BundleIdentifiers(productionBundleID: "com.microsoft.edgemac", relatedBundleIDs: [])
        case .firefox: return BundleIdentifiers(productionBundleID: "org.mozilla.firefox", relatedBundleIDs: [
            "org.mozilla.nightly",
            "org.mozilla.firefoxdeveloperedition"
        ])
        case .safari: return BundleIdentifiers(productionBundleID: "com.apple.safari", relatedBundleIDs: [])
        }
    }

    func forceTerminate() {
        let applications = findRunningApplications()

        applications.forEach {
            $0.forceTerminate()
        }
    }

    private func findRunningApplications() -> [NSRunningApplication] {
        var applications = [NSRunningApplication]()

        for bundleID in bundleIdentifiers.all {
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            applications.append(contentsOf: running)
        }

        return applications
    }

    // Returns the URL to the profiles for a given browser. This directory will contain a list of directories, each representing a profile.
    private func profilesDirectory() -> URL {
        let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

        switch self {
        case .brave: return applicationSupportURL.appendingPathComponent("BraveSoftware/Brave-Browser/")
        case .chrome: return applicationSupportURL.appendingPathComponent("Google/Chrome/")
        case .edge: return applicationSupportURL.appendingPathComponent("Microsoft Edge/")
        case .firefox: return applicationSupportURL.appendingPathComponent("Firefox/Profiles/")
        case .safari:
            let safariDataDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            return safariDataDirectory.appendingPathComponent("Safari")
        }
    }

}
