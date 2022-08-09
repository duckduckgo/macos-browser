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

import AppKit

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
    case lastPass
    case onePassword

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
        case .lastPass: return .lastPass
        case .onePassword: return .onePassword
        case .csv: return nil
        case .bookmarksHTML: return nil
        }
    }

    var isInstalled: Bool {
        let detectedApplicationPath = applicationPath != nil
        let detectedBrowserProfiles = !(browserProfiles()?.profiles.isEmpty ?? false)

        return detectedApplicationPath && detectedBrowserProfiles
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
        case .onePassword: return .onePassword
        case .lastPass: return .lastPass
        }
    }

    var applicationIcon: NSImage? {
        guard let applicationPath = applicationPath else {
            return fallbackApplicationIcon
        }

        return NSWorkspace.shared.icon(forFile: applicationPath)
    }
    
    /// Used when specific apps are not installed, but still need to be displayed in the list.
    /// Browsers are hidden when not installed, so this only applies to password managers.
    var fallbackApplicationIcon: NSImage? {
        switch self {
        case .lastPass: return NSImage(named: "LastPassIcon")
        case .onePassword: return NSImage(named: "1PasswordIcon")
        default: return nil
        }
    }

    // Returns the first available path to the application. This will test the production bundle ID, and any known pre-release versions, such as the
    // Firefox Nightly build.
    private var applicationPath: String? {
        for bundleID in bundleIdentifiers.all {
            if let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path {
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
        case .onePassword: return BundleIdentifiers(productionBundleID: "com.agilebits.onepassword7", relatedBundleIDs: [
            "com.agilebits.onepassword",
            "com.agilebits.onepassword4",
            "com.1password.1password"
        ])
        case .lastPass: return BundleIdentifiers(productionBundleID: "com.lastpass.lastpassmacdesktop", relatedBundleIDs: [
            "com.lastpass.lastpass"
        ])
        }
    }

    func forceTerminate() {
        let applications = findRunningApplications()

        applications.forEach {
            $0.forceTerminate()
        }
    }
    
    func browserProfiles(supportDirectoryURL: URL? = nil) -> DataImport.BrowserProfileList? {
        let applicationSupportURL = supportDirectoryURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        
        guard let profilePath = profilesDirectory(applicationSupportURL: applicationSupportURL),
              let potentialProfileURLs = try? FileManager.default.contentsOfDirectory(at: profilePath,
                                                                                      includingPropertiesForKeys: nil,
                                                                                      options: [.skipsHiddenFiles]).filter(\.hasDirectoryPath) else {
            // Safari is an exception, as it may need permissions granted before being able to read the contents of the profile path. To be safe,
            // return the profile anyway and check the file system permissions when preparing to import.
            if self == .safari,
               let profilePath = profilesDirectory(applicationSupportURL: applicationSupportURL) {
                return DataImport.BrowserProfileList(browser: self, profileURLs: [profilePath])
            } else {
                return nil
            }
        }

        return DataImport.BrowserProfileList(browser: self, profileURLs: potentialProfileURLs)
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
    private func profilesDirectory(applicationSupportURL: URL) -> URL? {
        switch self {
        case .brave: return applicationSupportURL.appendingPathComponent("BraveSoftware/Brave-Browser/")
        case .chrome: return applicationSupportURL.appendingPathComponent("Google/Chrome/")
        case .edge: return applicationSupportURL.appendingPathComponent("Microsoft Edge/")
        case .firefox: return applicationSupportURL.appendingPathComponent("Firefox/Profiles/")
        case .safari:
            let safariDataDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            return safariDataDirectory.appendingPathComponent("Safari")
        case .lastPass, .onePassword: return nil
        }
    }

}
