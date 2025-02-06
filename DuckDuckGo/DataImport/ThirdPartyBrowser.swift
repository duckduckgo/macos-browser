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
import BrowserServicesKit

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
    case chromium
    case coccoc
    case edge
    case firefox
    case opera
    case operaGX
    case safari
    case safariTechnologyPreview
    case tor
    case vivaldi
    case yandex

    case bitwarden
    case lastPass
    case onePassword7
    case onePassword8

    static func browser(for source: DataImport.Source) -> ThirdPartyBrowser? {
        switch source {
        case .brave: return .brave
        case .chrome: return .chrome
        case .chromium: return .chromium
        case .coccoc: return .coccoc
        case .edge: return .edge
        case .firefox: return .firefox
        case .opera: return .opera
        case .operaGX: return .operaGX
        case .safari: return .safari
        case .safariTechnologyPreview: return .safariTechnologyPreview
        case .tor: return .tor
        case .vivaldi: return .vivaldi
        case .yandex: return .yandex
        case .bitwarden: return .bitwarden
        case .lastPass: return .lastPass
        case .onePassword7: return .onePassword7
        case .onePassword8: return .onePassword8
        case .csv: return nil
        case .bookmarksHTML: return nil
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
        case .chromium: return .chromium
        case .coccoc: return .coccoc
        case .edge: return .edge
        case .firefox: return .firefox
        case .opera: return .opera
        case .operaGX: return .operaGX
        case .safari: return .safari
        case .safariTechnologyPreview: return .safariTechnologyPreview
        case .tor: return .tor
        case .vivaldi: return .vivaldi
        case .yandex: return .yandex
        case .bitwarden: return .bitwarden
        case .onePassword7: return .onePassword7
        case .onePassword8: return .onePassword8
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
        case .lastPass: return .lastPassIcon
        case .onePassword8: return ._1PasswordIcon
        case .onePassword7: return ._1PasswordIcon
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

    var installedAppsVersions: Set<String>? {
        let versions = bundleIdentifiers.all
            .reduce(into: Set<String>()) { result, bundleId in
                for url in NSWorkspace.shared.urls(forApplicationsWithBundleId: bundleId) {
                    guard let version = ApplicationVersionReader.getVersion(of: url.path),
                          !version.isEmpty else { continue }
                    result.insert(version)
                }
            }
        guard !versions.isEmpty else { return nil }
        return versions
    }

    private var bundleIdentifiers: BundleIdentifiers {
        switch self {
        case .brave: return BundleIdentifiers(productionBundleID: "com.brave.Browser", relatedBundleIDs: ["com.brave.Browser.nightly"])
        case .chrome: return BundleIdentifiers(productionBundleID: "com.google.Chrome", relatedBundleIDs: [
            "com.google.Chrome.canary",
            "com.google.Chrome.beta",
            "com.google.Chrome.dev"
        ])
        case .chromium: return BundleIdentifiers(productionBundleID: "org.chromium.Chromium", relatedBundleIDs: [])
        case .coccoc: return  BundleIdentifiers(productionBundleID: "com.coccoc.Coccoc", relatedBundleIDs: [])
        case .edge: return BundleIdentifiers(productionBundleID: "com.microsoft.edgemac", relatedBundleIDs: [])
        case .firefox: return BundleIdentifiers(productionBundleID: "org.mozilla.firefox", relatedBundleIDs: [
            "org.mozilla.nightly",
            "org.mozilla.firefoxdeveloperedition"
        ])
        case .opera: return BundleIdentifiers(productionBundleID: "com.operasoftware.Opera", relatedBundleIDs: [])
        case .operaGX: return BundleIdentifiers(productionBundleID: "com.operasoftware.OperaGX", relatedBundleIDs: [])
        case .safari: return BundleIdentifiers(productionBundleID: "com.apple.safari", relatedBundleIDs: [])
        case .safariTechnologyPreview: return BundleIdentifiers(productionBundleID: "com.apple.SafariTechnologyPreview", relatedBundleIDs: [])
        case .tor: return BundleIdentifiers(productionBundleID: "org.torproject.torbrowser", relatedBundleIDs: [])
        case .vivaldi: return BundleIdentifiers(productionBundleID: "com.vivaldi.Vivaldi", relatedBundleIDs: [])
        case .yandex: return BundleIdentifiers(productionBundleID: "ru.yandex.desktop.yandex-browser", relatedBundleIDs: [])
        case .bitwarden: return BundleIdentifiers(productionBundleID: "com.bitwarden.desktop", relatedBundleIDs: [])
        case .onePassword7: return BundleIdentifiers(productionBundleID: "com.agilebits.onepassword7", relatedBundleIDs: [
            "com.agilebits.onepassword",
            "com.agilebits.onepassword4"
        ])
        case .onePassword8: return BundleIdentifiers(productionBundleID: "com.1password.1password", relatedBundleIDs: [])
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

    func browserProfiles(applicationSupportURL: URL? = nil) -> DataImport.BrowserProfileList {
        var potentialProfileURLs: [URL] {
            let fm = FileManager()
            let profilesDirectories = self.profilesDirectories(applicationSupportURL: applicationSupportURL)
            return profilesDirectories.reduce(into: []) { result, profilesDir in
                result.append(contentsOf: (try? fm.contentsOfDirectory(at: profilesDir,
                                                                       includingPropertiesForKeys: nil,
                                                                       options: [.skipsHiddenFiles])
                    .filter(\.hasDirectoryPath)) ?? [])
            } + profilesDirectories
        }

        let profiles: [DataImport.BrowserProfile]
        switch self {
        case .safari, .safariTechnologyPreview:
            // Safari is an exception, as it may need permissions granted before being able to read the contents of the profile path. To be safe,
            // return the profile anyway and check the file system permissions when preparing to import.
            guard let profileURL = profilesDirectories(applicationSupportURL: applicationSupportURL).first else {
                assertionFailure("Unexpected nil profileURL for Safari")
                profiles = []
                break
            }
            profiles = [DataImport.BrowserProfile(browser: self, profileURL: profileURL)]

        case .brave, .chrome, .chromium, .coccoc, .edge, .opera, .operaGX, .vivaldi, .yandex:
            // Chromium profiles are either named "Default", or a series of incrementing profile names, i.e. "Profile 1", "Profile 2", etc.
            let potentialProfiles = potentialProfileURLs.map {
                DataImport.BrowserProfile(browser: self, profileURL: $0)
            }

            let filteredProfiles =  potentialProfiles.filter {
                $0.profilePreferences?.isChromium == true
                || $0.profileName == DataImport.BrowserProfileList.Constants.chromiumDefaultProfileName
                || $0.profileName.hasPrefix(DataImport.BrowserProfileList.Constants.chromiumProfilePrefix)
            }

            let sortedProfiles = filteredProfiles.sorted()

            profiles = sortedProfiles

        case .firefox, .tor:
            profiles = potentialProfileURLs.map {
                DataImport.BrowserProfile(browser: self, profileURL: $0)
            }.sorted()

        case .bitwarden, .lastPass, .onePassword7, .onePassword8:
            profiles = []
        }

        return DataImport.BrowserProfileList(browser: self, profiles: profiles)
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
    func profilesDirectories(applicationSupportURL: URL? = nil) -> [URL] {
        let applicationSupportURL = applicationSupportURL ?? URL.nonSandboxApplicationSupportDirectoryURL
        return switch self {
        case .brave: [applicationSupportURL.appendingPathComponent("BraveSoftware/Brave-Browser/")]
        case .chrome: [
            applicationSupportURL.appendingPathComponent("Google/Chrome/"),
            applicationSupportURL.appendingPathComponent("Google/Chrome Beta/"),
            applicationSupportURL.appendingPathComponent("Google/Chrome Dev/"),
            applicationSupportURL.appendingPathComponent("Google/Chrome Canary/"),
        ]
        case .chromium: [applicationSupportURL.appendingPathComponent("Chromium/")]
        case .coccoc:  [applicationSupportURL.appendingPathComponent("Coccoc/")]
        case .edge: [applicationSupportURL.appendingPathComponent("Microsoft Edge/")]
        case .firefox: [applicationSupportURL.appendingPathComponent("Firefox/Profiles/")]
        case .opera: [applicationSupportURL.appendingPathComponent("com.operasoftware.Opera/")]
        case .operaGX: [applicationSupportURL.appendingPathComponent("com.operasoftware.OperaGX/")]
        case .safari: [URL.nonSandboxLibraryDirectoryURL.appendingPathComponent("Safari/")]
        case .safariTechnologyPreview: [URL.nonSandboxLibraryDirectoryURL.appendingPathComponent("SafariTechnologyPreview/")]
        case .tor: [applicationSupportURL.appendingPathComponent("TorBrowser-Data/Browser/")]
        case .vivaldi: [applicationSupportURL.appendingPathComponent("Vivaldi/")]
        case .yandex: [applicationSupportURL.appendingPathComponent("Yandex/YandexBrowser/")]
        case .bitwarden, .lastPass, .onePassword7, .onePassword8: []
        }
    }

    var keychainProcessName: String {
        switch self {
        case .brave: "Brave"
        case .chrome: "Chrome"
        case .chromium: "Chromium"
        case .coccoc: "CocCoc"
        case .edge: "Microsoft Edge"
        case .opera, .operaGX: "Opera"
        case .vivaldi: "Vivaldi"
        case .yandex: "Yandex"
        // do not require Keychain access
        case .firefox, .safari, .safariTechnologyPreview, .tor,
             .bitwarden, .lastPass, .onePassword7, .onePassword8: ""
        }
    }

}
