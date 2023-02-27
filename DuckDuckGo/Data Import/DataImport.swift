//
//  DataImport.swift
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

enum DataImport {

    enum Source: CaseIterable, Equatable {

        case brave
        case chrome
        case edge
        case firefox
        case safari
        case onePassword7
        case lastPass
        case csv
        case bookmarksHTML

        static let preferredSources: [Self] = [.chrome, .safari]

        var importSourceName: String {
            switch self {
            case .brave:
                return "Brave"
            case .chrome:
                return "Chrome"
            case .edge:
                return "Edge"
            case .firefox:
                return "Firefox"
            case .safari:
                return "Safari"
            case .lastPass:
                return "LastPass"
            case .onePassword7:
                return "1Password 7"
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
            let isInstalled = (ThirdPartyBrowser.browser(for: self)?.isInstalled ?? false)
            return isInstalled || [.csv, .onePassword7, .lastPass, .bookmarksHTML].contains(self)
        }

        var pixelEventSource: Pixel.Event.DataImportSource {
            switch self {
            case .brave: return .brave
            case .chrome: return .chrome
            case .edge: return .edge
            case .firefox: return .firefox
            case .safari: return .safari
            case .onePassword7: return .onePassword
            case .lastPass: return .lastPass
            case .csv: return .csv
            case .bookmarksHTML: return .bookmarksHTML
            }
        }
    }

    enum DataType {
        case bookmarks
        case logins
    }

    struct CompletedLoginsResult: Equatable {
        let successfulImports: [String]
        let duplicateImports: [String]
        let failedImports: [String]
    }

    enum LoginsResult: Equatable {
        case awaited
        case completed(CompletedLoginsResult)
    }

    struct Summary: Equatable {
        var bookmarksResult: BookmarkImportResult?
        var loginsResult: LoginsResult?

        var isEmpty: Bool {
            bookmarksResult == nil && loginsResult == nil
        }
    }

    struct BrowserProfileList {
        let browser: ThirdPartyBrowser
        let profiles: [BrowserProfile]

        var validImportableProfiles: [BrowserProfile] {
            return profiles.filter(\.hasBrowserData)
        }

        init(browser: ThirdPartyBrowser, profileURLs: [URL]) {
            self.browser = browser

            switch browser {
            case .brave, .chrome, .edge:
                // Chromium profiles are either named "Default", or a series of incrementing profile names, i.e. "Profile 1", "Profile 2", etc.
                let potentialProfiles = profileURLs.map({
                    BrowserProfile.for(browser: browser, profileURL: $0)
                })

                let filteredProfiles =  potentialProfiles.filter {
                    $0.hasNonDefaultProfileName ||
                        $0.profileName == "Default" ||
                        $0.profileName.hasPrefix("Profile ")
                }

                let sortedProfiles = filteredProfiles.sorted()

                self.profiles = sortedProfiles
            case .firefox:
                self.profiles = profileURLs.map({
                    BrowserProfile.for(browser: .firefox, profileURL: $0)
                }).sorted()
            case .safari:
                self.profiles = profileURLs.map({
                    BrowserProfile.for(browser: .safari, profileURL: $0)
                }).sorted()
            case .lastPass, .onePassword7:
                self.profiles = []
            }
        }

        var showProfilePicker: Bool {
            return validImportableProfiles.count > 1
        }

        var defaultProfile: BrowserProfile? {
            switch browser {
            case .brave, .chrome, .edge:
                return profiles.first { $0.profileName == "Default" } ?? profiles.first
            case .firefox:
                return profiles.first { $0.profileName == "default-release" } ?? profiles.first
            case .safari, .lastPass, .onePassword7:
                return nil
            }
        }
    }

    struct BrowserProfile: Comparable {

        enum Constants {
            static let chromiumPreferencesFileName = "Preferences"
            static let chromiumSystemProfileName = "System Profile"
        }

        let profileURL: URL
        var profileName: String {
            return detectedChromePreferencesProfileName ?? fallbackProfileName
        }

        var hasNonDefaultProfileName: Bool {
            return detectedChromePreferencesProfileName != nil
        }

        private let browser: ThirdPartyBrowser
        private let fileStore: FileStore
        private let fallbackProfileName: String
        private let detectedChromePreferencesProfileName: String?

        static func `for`(browser: ThirdPartyBrowser, profileURL: URL) -> BrowserProfile {
            return BrowserProfile(browser: browser, profileURL: profileURL)
        }

        init(browser: ThirdPartyBrowser, profileURL: URL, fileStore: FileStore = FileManager.default) {
            self.browser = browser
            self.fileStore = fileStore
            self.profileURL = profileURL

            self.fallbackProfileName = Self.getDefaultProfileName(at: profileURL)
            self.detectedChromePreferencesProfileName = Self.getChromeProfileName(at: profileURL, fileStore: fileStore)
        }

        var hasBrowserData: Bool {
            guard let profileDirectoryContents = try? fileStore.directoryContents(at: profileURL.path) else {
                return false
            }

            let profileDirectoryContentsSet = Set(profileDirectoryContents)

            switch browser {
            case .brave, .chrome, .edge:
                let hasChromiumLogins = ChromiumLoginReader.LoginDataFileName.allCases.contains { loginFileName in
                    return profileDirectoryContentsSet.contains(loginFileName.rawValue)
                }

                let hasChromiumBookmarks = profileDirectoryContentsSet.contains(ChromiumBookmarksReader.Constants.defaultBookmarksFileName)

                return hasChromiumLogins || hasChromiumBookmarks
            case .firefox:
                let hasFirefoxLogins = FirefoxLoginReader.DataFormat.allCases.contains { dataFormat in
                    let (databaseName, loginFileName) = dataFormat.formatFileNames

                    return profileDirectoryContentsSet.contains(databaseName) && profileDirectoryContentsSet.contains(loginFileName)
                }

                let hasFirefoxBookmarks = profileDirectoryContentsSet.contains(FirefoxBookmarksReader.Constants.placesDatabaseName)

                return hasFirefoxLogins || hasFirefoxBookmarks
            default:
                return false
            }
        }

        private static func getDefaultProfileName(at profileURL: URL) -> String {
            return profileURL.lastPathComponent.components(separatedBy: ".").last ?? profileURL.lastPathComponent
        }

        private static func getChromeProfileName(at profileURL: URL, fileStore: FileStore) -> String? {
            guard let profileDirectoryContents = try? fileStore.directoryContents(at: profileURL.path) else {
                return nil
            }

            guard profileURL.lastPathComponent != Constants.chromiumSystemProfileName else {
                return nil
            }

            if profileDirectoryContents.contains(Constants.chromiumPreferencesFileName),
               let chromePreferenceData = fileStore.loadData(at: profileURL.appendingPathComponent(Constants.chromiumPreferencesFileName)),
               let chromePreferences = try? JSONDecoder().decode(ChromePreferences.self, from: chromePreferenceData) {
                return chromePreferences.profile.name
            }

            return nil
        }

        static func < (lhs: DataImport.BrowserProfile, rhs: DataImport.BrowserProfile) -> Bool {
            return lhs.profileName.localizedCompare(rhs.profileName) == .orderedAscending
        }

        static func == (lhs: DataImport.BrowserProfile, rhs: DataImport.BrowserProfile) -> Bool {
            return lhs.profileURL == rhs.profileURL
        }
    }

}

struct DataImportError: Error, Equatable {

    enum ImportErrorAction {
        case bookmarks
        case logins
        case generic

        var pixelEventAction: Pixel.Event.DataImportAction {
            switch self {
            case .bookmarks: return .importBookmarks
            case .logins: return .importLogins
            case .generic: return .generic
            }
        }
    }

    enum ImportErrorType: Equatable {
        case noFileFound
        case cannotFindFile
        case cannotReadFile
        case userDeniedKeychainPrompt
        case couldNotFindProfile
        case needsLoginPrimaryPassword
        case cannotAccessSecureVault
        case cannotAccessCoreData
        case couldNotGetDecryptionKey
        case couldNotAccessKeychain(OSStatus)
        case cannotDecryptFile
        case failedToTemporarilyCopyFile
        case databaseAccessFailed

        var stringValue: String {
            switch self {
            case .couldNotAccessKeychain: return "couldNotAccessKeychain"
            case .noFileFound,
                    .cannotFindFile,
                    .cannotReadFile,
                    .userDeniedKeychainPrompt,
                    .couldNotFindProfile,
                    .needsLoginPrimaryPassword,
                    .cannotAccessSecureVault,
                    .cannotAccessCoreData,
                    .couldNotGetDecryptionKey,
                    .cannotDecryptFile,
                    .failedToTemporarilyCopyFile,
                    .databaseAccessFailed: return String(describing: self)
            }
        }

        var errorParameters: [String: String] {
            var parameters = ["error": stringValue]

            switch self {
            case .couldNotAccessKeychain(let status): parameters["keychainErrorCode"] = String(status)
            case .noFileFound,
                    .cannotFindFile,
                    .cannotReadFile,
                    .userDeniedKeychainPrompt,
                    .couldNotFindProfile,
                    .needsLoginPrimaryPassword,
                    .cannotAccessSecureVault,
                    .cannotAccessCoreData,
                    .couldNotGetDecryptionKey,
                    .cannotDecryptFile,
                    .failedToTemporarilyCopyFile,
                    .databaseAccessFailed: break
            }

            return parameters
        }
    }

    static func generic(_ errorType: ImportErrorType) -> DataImportError {
        return DataImportError(actionType: .generic, errorType: errorType)
    }

    // MARK: Bookmark Error Types

    static func bookmarks(_ errorType: ImportErrorType) -> DataImportError {
        return DataImportError(actionType: .bookmarks, errorType: errorType)
    }

    static func bookmarks(_ errorType: FirefoxBookmarksReader.ImportError) -> DataImportError {
        switch errorType {
        case .noBookmarksFileFound: return DataImportError(actionType: .bookmarks, errorType: .noFileFound)
        case .unexpectedBookmarksDatabaseFormat: return DataImportError(actionType: .bookmarks, errorType: .cannotReadFile)
        case .failedToTemporarilyCopyFile: return DataImportError(actionType: .bookmarks, errorType: .failedToTemporarilyCopyFile)
        }
    }

    static func bookmarks(_ errorType: SafariBookmarksReader.ImportError) -> DataImportError {
        switch errorType {
        case .unexpectedBookmarksFileFormat: return DataImportError(actionType: .bookmarks, errorType: .cannotReadFile)
        }
    }

    static func bookmarks(_ errorType: BookmarkHTMLReader.ImportError) -> DataImportError {
        switch errorType {
        case .unexpectedBookmarksFileFormat: return DataImportError(actionType: .bookmarks, errorType: .cannotReadFile)
        }
    }

    // MARK: Login Error Types

    static func logins(_ errorType: ImportErrorType) -> DataImportError {
        return DataImportError(actionType: .logins, errorType: errorType)
    }

    static func logins(_ errorType: ChromiumLoginReader.ImportError) -> DataImportError {
        switch errorType {
        case .decryptionKeyAccessFailed(let status): return DataImportError(actionType: .logins, errorType: .couldNotAccessKeychain(status))
        case .databaseAccessFailed: return DataImportError(actionType: .logins, errorType: .databaseAccessFailed)
        case .couldNotFindLoginData: return DataImportError(actionType: .logins, errorType: .noFileFound)
        case .failedToTemporarilyCopyDatabase: return DataImportError(actionType: .logins, errorType: .failedToTemporarilyCopyFile)
        case .decryptionFailed: return DataImportError(actionType: .logins, errorType: .cannotReadFile)
        case .failedToDecodePasswordData: return DataImportError(actionType: .logins, errorType: .cannotReadFile)
        case .userDeniedKeychainPrompt: return DataImportError(actionType: .logins, errorType: .userDeniedKeychainPrompt)
        }
    }

    let actionType: ImportErrorAction
    let errorType: ImportErrorType

}

/// Represents an object able to import data from an outside source. The outside source may be capable of importing multiple types of data.
/// For instance, a browser data importer may be able to import logins and bookmarks.
protocol DataImporter {

    /// Performs a quick check to determine if the data is able to be imported. It does not guarantee that the import will succeed.
    /// For example, a CSV importer will return true if the URL it has been created with is a CSV file, but does not check whether the CSV data matches the expected format.
    func importableTypes() -> [DataImport.DataType]

    func importData(types: [DataImport.DataType],
                    from profile: DataImport.BrowserProfile?,
                    completion: @escaping (Result<DataImport.Summary, DataImportError>) -> Void)

}
