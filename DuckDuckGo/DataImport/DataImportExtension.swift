//
//  DataImportExtension.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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
import BrowserServicesKit

extension DataImport {

    struct BrowserProfileList {

        enum Constants {
            static let chromiumDefaultProfileName = "Default"
            static let chromiumProfilePrefix = "Profile "
            static let firefoxDefaultProfileName = "default-release"
        }

        let browser: ThirdPartyBrowser
        let profiles: [BrowserProfile]

        typealias ProfileDataValidator = (BrowserProfile) -> () -> BrowserProfile.ProfileDataValidationResult?
        private let validateProfileData: ProfileDataValidator

        var validImportableProfiles: [BrowserProfile] {
            return profiles.filter { validateProfileData($0)()?.containsValidData == true }
        }

        init(browser: ThirdPartyBrowser, profiles: [BrowserProfile], validateProfileData: @escaping ProfileDataValidator = BrowserProfile.validateProfileData) {
            self.browser = browser
            self.profiles = profiles
            self.validateProfileData = validateProfileData
        }

        var defaultProfile: BrowserProfile? {
            let preferredProfileName: String?
            switch browser {
            case .brave, .chrome, .chromium, .coccoc, .edge, .opera, .operaGX, .vivaldi, .yandex:
                preferredProfileName = Constants.chromiumDefaultProfileName
                return validImportableProfiles.first { $0.profileName == Constants.chromiumDefaultProfileName } ?? validImportableProfiles.first ?? profiles.first
            case .firefox, .tor:
                preferredProfileName = Constants.firefoxDefaultProfileName
            case .safari, .safariTechnologyPreview, .bitwarden, .lastPass, .onePassword7, .onePassword8:
                preferredProfileName = nil
            }
            lazy var validImportableProfiles = self.validImportableProfiles
            if let preferredProfileName,
               let preferredProfile = validImportableProfiles.first(where: { $0.profileName == preferredProfileName }) {

                return preferredProfile
            }
            return validImportableProfiles.first ?? profiles.first
        }

    }

    struct BrowserProfile: Comparable {

        enum Constants {
            static let chromiumSystemProfileName = "System Profile"
        }

        let profileURL: URL
        var profileName: String {
            if profileURL.lastPathComponent == Constants.chromiumSystemProfileName {
                return Constants.chromiumSystemProfileName
            }

            return profilePreferences?.profileName ?? fallbackProfileName
        }

        let browser: ThirdPartyBrowser
        private let fileStore: FileStore
        private let fallbackProfileName: String

        enum ProfilePreferences {
            case chromium(ChromiumPreferences)
            case firefox(FirefoxCompatibilityPreferences)

            var appVersion: String? {
                switch self {
                case .chromium(let preferences): preferences.appVersion
                case .firefox(let preferences): preferences.lastVersion
                }
            }

            var profileName: String? {
                switch self {
                case .chromium(let preferences): preferences.profileName
                case .firefox: nil
                }
            }

            var isChromium: Bool {
                if case .chromium = self { true } else { false }
            }
        }
        let profilePreferences: ProfilePreferences?

        var appVersion: String? {
            profilePreferences?.appVersion
        }

        init(browser: ThirdPartyBrowser, profileURL: URL, fileStore: FileStore = FileManager.default) {
            self.browser = browser
            self.fileStore = fileStore
            self.profileURL = profileURL

            self.fallbackProfileName = Self.getDefaultProfileName(at: profileURL)

            switch browser {
            case .brave, .chrome, .chromium, .coccoc, .edge, .opera, .operaGX, .vivaldi, .yandex:
                self.profilePreferences = (try? ChromiumPreferences(profileURL: profileURL, fileStore: fileStore))
                    .map(ProfilePreferences.chromium)
            case .firefox, .tor:
                self.profilePreferences = (try? FirefoxCompatibilityPreferences(profileURL: profileURL, fileStore: fileStore))
                    .map(ProfilePreferences.firefox)
            case .bitwarden, .safari, .safariTechnologyPreview, .lastPass, .onePassword7, .onePassword8:
                self.profilePreferences = nil
            }
        }

        enum ProfileDataItemValidationResult {
            case available
            case unavailable(path: String)
            case unsupported
        }
        struct ProfileDataValidationResult {
            let logins: ProfileDataItemValidationResult
            let bookmarks: ProfileDataItemValidationResult

            var containsValidData: Bool {
                if case .available = logins { return true }
                if case .available = bookmarks { return true }
                return false
            }
        }

        func validateProfileData() -> ProfileDataValidationResult? {
            guard let profileDirectoryContents = try? fileStore.directoryContents(at: profileURL.path) else { return nil }

            let profileDirectoryContentsSet = Set(profileDirectoryContents)

            return .init(logins: validateLoginsData(profileDirectoryContents: profileDirectoryContentsSet),
                         bookmarks: validateBookmarksData(profileDirectoryContents: profileDirectoryContentsSet))
        }

        private func validateLoginsData(profileDirectoryContents: Set<String>) -> ProfileDataItemValidationResult {
            switch browser {
            case .brave, .chrome, .chromium, .coccoc, .edge, .opera, .operaGX, .vivaldi:
                let hasChromiumLogins = ChromiumLoginReader.LoginDataFileName.allCases.contains { loginFileName in
                    return profileDirectoryContents.contains(loginFileName.rawValue)
                }

                return hasChromiumLogins ? .available
                    : .unavailable(path: profileURL.appendingPathComponent(ChromiumLoginReader.LoginDataFileName.allCases.first!.rawValue).path)

            case .firefox:
                guard let firefoxLoginsFormat = FirefoxLoginReader.DataFormat.allCases.first(where: { dataFormat in
                    profileDirectoryContents.contains(dataFormat.formatFileNames.databaseName)
                }) else {
                    return .unavailable(path: profileURL .appendingPathComponent(FirefoxLoginReader.DataFormat.allCases.last!.formatFileNames.databaseName).path)
                }
                let hasFirefoxLogins = profileDirectoryContents.contains(firefoxLoginsFormat.formatFileNames.loginsFileName)

                return hasFirefoxLogins ? .available
                    : .unavailable(path: profileURL.appendingPathComponent(firefoxLoginsFormat.formatFileNames.loginsFileName).path)

            case .tor:
                return .unsupported

            case .safari, .safariTechnologyPreview, .yandex, .bitwarden, .lastPass, .onePassword7, .onePassword8:
                return .available
            }
        }

        private func validateBookmarksData(profileDirectoryContents: Set<String>) -> ProfileDataItemValidationResult {
            switch browser {
            case .brave, .chrome, .chromium, .coccoc, .edge, .opera, .operaGX, .vivaldi, .yandex:
                let hasChromiumBookmarks = profileDirectoryContents.contains(ChromiumBookmarksReader.Constants.defaultBookmarksFileName)

                return hasChromiumBookmarks ? .available
                : .unavailable(path: profileURL.appendingPathComponent(ChromiumBookmarksReader.Constants.defaultBookmarksFileName).path)

            case .firefox, .tor:
                let hasFirefoxBookmarks = profileDirectoryContents.contains(FirefoxBookmarksReader.Constants.placesDatabaseName)

                return hasFirefoxBookmarks ? .available
                : .unavailable(path: profileURL.appendingPathComponent(FirefoxBookmarksReader.Constants.placesDatabaseName).path)

            case .safari, .safariTechnologyPreview:
                return .available

            case .bitwarden, .lastPass, .onePassword7, .onePassword8:
                return .unsupported
            }
        }

        private static func getDefaultProfileName(at profileURL: URL) -> String {
            return profileURL.lastPathComponent.components(separatedBy: ".").last ?? profileURL.lastPathComponent
        }

        static func < (lhs: DataImport.BrowserProfile, rhs: DataImport.BrowserProfile) -> Bool {
            // first sort by profiles folder name if multiple profiles folders are present (Chrome, Chrome Canary…)
            let profilesDirName1 = lhs.profileURL.deletingLastPathComponent().lastPathComponent
            let profilesDirName2 = rhs.profileURL.deletingLastPathComponent().lastPathComponent
            if profilesDirName1 == profilesDirName2 {
                return lhs.profileName.localizedCompare(rhs.profileName) == .orderedAscending
            } else {
                return profilesDirName1.localizedCompare(profilesDirName2) == .orderedAscending
            }
        }

        static func == (lhs: DataImport.BrowserProfile, rhs: DataImport.BrowserProfile) -> Bool {
            return lhs.profileURL == rhs.profileURL
        }

        func installedAppsMajorVersionDescription() -> String? {
            self.browser.importSource.installedAppsMajorVersionDescription(selectedProfile: self)
        }
    }
}

extension DataImport.Source {

    var importSourceName: String {
        switch self {
        case .brave:
            return "Brave"
        case .chrome:
            return "Chrome"
        case .chromium:
            return "Chromium"
        case .coccoc:
            return "Cốc Cốc"
        case .edge:
            return "Edge"
        case .firefox:
            return "Firefox"
        case .opera:
            return "Opera"
        case .operaGX:
            return "OperaGX"
        case .safari:
            return "Safari"
        case .safariTechnologyPreview:
            return "Safari Technology Preview"
        case .tor:
            return "Tor Browser"
        case .vivaldi:
            return "Vivaldi"
        case .yandex:
            return "Yandex"
        case .bitwarden:
            return "Bitwarden"
        case .lastPass:
            return "LastPass"
        case .onePassword7:
            return "1Password 7"
        case .onePassword8:
            return "1Password"
        case .csv:
            return UserText.importLoginsCSV
        case .bookmarksHTML:
            return UserText.importBookmarksHTML
        }
    }

    var importSourceImage: NSImage? {
        return ThirdPartyBrowser.browser(for: self)?.applicationIcon
    }

    var canImportData: Bool {
        if ThirdPartyBrowser.browser(for: self)?.isInstalled ?? false {
            return true
        }

        switch self {
        case .csv, .bitwarden, .onePassword8, .onePassword7, .lastPass, .bookmarksHTML:
            // Users can always import from exported files
            return true
        case .brave, .chrome, .chromium, .coccoc, .edge, .firefox, .opera, .operaGX, .safari, .safariTechnologyPreview, .tor, .vivaldi, .yandex:
            // Users can't import from browsers unless they're installed
            return false
        }
    }

    var isBrowser: Bool {
        switch self {
        case .brave, .chrome, .chromium, .coccoc, .edge, .firefox, .opera, .operaGX, .safari, .safariTechnologyPreview, .vivaldi, .yandex, .tor:
            return true
        case .onePassword8, .onePassword7, .bitwarden, .lastPass, .csv, .bookmarksHTML:
            return false
        }
    }

    var supportedDataTypes: Set<DataImport.DataType> {
        switch self {
        case .brave, .chrome, .chromium, .coccoc, .edge, .firefox, .opera, .operaGX, .safari, .safariTechnologyPreview, .vivaldi, .yandex:
            return [.bookmarks, .passwords]
        case .tor:
            return [.bookmarks]
        case .onePassword8, .onePassword7, .bitwarden, .lastPass, .csv:
            return [.passwords]
        case .bookmarksHTML:
            return [.bookmarks]
        }
    }

    func installedAppsMajorVersionDescription(selectedProfile: DataImport.BrowserProfile?) -> String? {
        let installedVersions: Set<String>
        if let appVersion = selectedProfile?.appVersion, !appVersion.isEmpty {
            installedVersions = [appVersion]
        } else if let versions = ThirdPartyBrowser.browser(for: self)?.installedAppsVersions {
            installedVersions = versions
        } else {
            return nil
        }
        return Set(installedVersions.map {
            // get major version
            $0.components(separatedBy: ".")[0] // [0] component is always there even if no "."
        }.sorted())
        // list installed browsers major versions separated
        .joined(separator: "; ")
    }

}

extension DataImport.DataType {

    var displayName: String {
        switch self {
        case .bookmarks: UserText.bookmarkImportBookmarks
        case .passwords: UserText.importLoginsPasswords
        }
    }

}
