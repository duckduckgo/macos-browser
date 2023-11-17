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

    static var installedBrowsers: [ThirdPartyBrowser] {
        return allCases.filter(\.isInstalled)
    }

    // swiftlint:disable:next cyclomatic_complexity
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
        if applicationPath != nil,
           browserProfiles()?.profiles.isEmpty == false {
            return true
        }
        return false
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
        case .lastPass: return NSImage(named: "LastPassIcon")
        case .onePassword8: return NSImage(named: "1PasswordIcon")
        case .onePassword7: return NSImage(named: "1PasswordIcon")
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

    func browserProfiles(supportDirectoryURL: URL? = nil) -> DataImport.BrowserProfileList? {
        let applicationSupportURL = supportDirectoryURL ?? URL.nonSandboxApplicationSupportDirectoryURL

        // Safari is an exception, as it may need permissions granted before being able to read the contents of the profile path. To be safe,
        // return the profile anyway and check the file system permissions when preparing to import.
        if [.safari, .safariTechnologyPreview].contains(self),
           let profilePath = profilesDirectory(applicationSupportURL: applicationSupportURL) {
            return DataImport.BrowserProfileList(browser: self, profileURLs: [profilePath])
        }

        guard let profilePath = profilesDirectory(applicationSupportURL: applicationSupportURL),
              var potentialProfileURLs = try? FileManager.default.contentsOfDirectory(at: profilePath,
                                                                                      includingPropertiesForKeys: nil,
                                                                                      options: [.skipsHiddenFiles]).filter(\.hasDirectoryPath) else {
            return nil
        }
        potentialProfileURLs.append(profilePath)

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
    // swiftlint:disable:next cyclomatic_complexity
    private func profilesDirectory(applicationSupportURL: URL) -> URL? {
        switch self {
        case .brave: return applicationSupportURL.appendingPathComponent("BraveSoftware/Brave-Browser/")
        case .chrome: return applicationSupportURL.appendingPathComponent("Google/Chrome/")
        case .chromium: return applicationSupportURL.appendingPathComponent("Chromium/")
        case .coccoc: return  applicationSupportURL.appendingPathComponent("Coccoc/")
        case .edge: return applicationSupportURL.appendingPathComponent("Microsoft Edge/")
        case .firefox: return applicationSupportURL.appendingPathComponent("Firefox/Profiles/")
        case .opera: return applicationSupportURL.appendingPathComponent("com.operasoftware.Opera/")
        case .operaGX: return applicationSupportURL.appendingPathComponent("com.operasoftware.OperaGX/")
        case .safari: return URL.nonSandboxLibraryDirectoryURL.appendingPathComponent("Safari/")
        case .safariTechnologyPreview: return URL.nonSandboxLibraryDirectoryURL.appendingPathComponent("SafariTechnologyPreview/")
        case .tor: return applicationSupportURL.appendingPathComponent("TorBrowser-Data/Browser/")
        case .vivaldi: return applicationSupportURL.appendingPathComponent("Vivaldi/")
        case .yandex: return applicationSupportURL.appendingPathComponent("Yandex/YandexBrowser/")
        case .bitwarden, .lastPass, .onePassword7, .onePassword8: return nil
        }
    }

}
