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
import SecureStorage

enum DataImport {

    enum Source: CaseIterable, Equatable {

        case brave
        case chrome
        case edge
        case firefox
        case safari
        case safariTechnologyPreview
        case onePassword8
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
            case .safariTechnologyPreview:
                return "Safari Technology Preview"
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
            case .csv, .onePassword8, .onePassword7, .lastPass, .bookmarksHTML:
                // Users can always import from exported files
                return true
            case .brave, .chrome, .edge, .firefox, .safari, .safariTechnologyPreview:
                // Users can't import from browsers unless they're installed
                return false
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
            case .firefox, .safari, .safariTechnologyPreview:
                self.profiles = profileURLs.map {
                    BrowserProfile.for(browser: browser, profileURL: $0)
                }.sorted()
            case .lastPass, .onePassword7, .onePassword8:
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
            case .safari, .safariTechnologyPreview, .lastPass, .onePassword7, .onePassword8:
                return profiles.first
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
               let chromePreferences = try? ChromePreferences(from: chromePreferenceData) {
                return chromePreferences.profileName
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

enum DataImportAction {
    case bookmarks
    case logins
    case favicons
    case generic
}

protocol DataImportError: Error, CustomNSError, ErrorWithParameters {
    associatedtype OperationType: RawRepresentable where OperationType.RawValue == Int

    var source: DataImport.Source { get }
    var action: DataImportAction { get }
    var type: OperationType { get }
    var underlyingError: Error? { get }

}
extension DataImportError /* : CustomNSError */ {
    var errorCode: Int {
        type.rawValue
    }

    var errorUserInfo: [String: Any] {
        guard let underlyingError else { return [:] }
        return [
            NSUnderlyingErrorKey: underlyingError
        ]
    }
}
extension DataImportError /* : ErrorWithParameters */ {
    var errorParameters: [String: String] {
        underlyingError?.pixelParameters ?? [:]
    }
}

/// Represents an object able to import data from an outside source. The outside source may be capable of importing multiple types of data.
/// For instance, a browser data importer may be able to import logins and bookmarks.
protocol DataImporter {

    /// Performs a quick check to determine if the data is able to be imported. It does not guarantee that the import will succeed.
    /// For example, a CSV importer will return true if the URL it has been created with is a CSV file, but does not check whether the CSV data matches the expected format.
    func importableTypes() -> [DataImport.DataType]

    func importData(types: [DataImport.DataType],
                    from profile: DataImport.BrowserProfile?,
                    modalWindow: NSWindow?,
                    completion: @escaping (DataImportResult<DataImport.Summary>) -> Void)

}
extension DataImporter {
    func importData(types: [DataImport.DataType], from profile: DataImport.BrowserProfile?, completion: @escaping (DataImportResult<DataImport.Summary>) -> Void) {
        self.importData(types: types, from: profile, modalWindow: nil, completion: completion)
    }
}

enum DataImportResult<T> {
    case success(T)
    case failure(any DataImportError)

    func get() throws -> T {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}

struct LoginImporterError: DataImportError {

    private let error: Error?
    private let _type: OperationType?

    var action: DataImportAction { .logins }
    let source: DataImport.Source

    init(source: DataImport.Source, error: Error?, type: OperationType? = nil) {
        self.source = source
        self.error = error
        self._type = type
    }

    struct OperationType: RawRepresentable {
        let rawValue: Int

        static let defaultFirefoxProfilePathNotFound = OperationType(rawValue: -1)
    }

    var type: OperationType {
        _type ?? OperationType(rawValue: (error as NSError?)?.code ?? 0)
    }

    var underlyingError: Error? {
        switch error {
        case let secureStorageError as SecureStorageError:
            switch secureStorageError {
            case .initFailed(let error),
                 .authError(let error),
                 .failedToOpenDatabase(let error),
                 .databaseError(let error):
                return error

            case .keystoreError(let status):
                return NSError(domain: "KeyStoreError", code: Int(status))

            case .secError(let status):
                return NSError(domain: "secError", code: Int(status))

            case .authRequired,
                 .invalidPassword,
                 .noL1Key,
                 .noL2Key,
                 .duplicateRecord,
                 .generalCryptoError,
                 .encodingFailed:
                return secureStorageError
            }
        default:
            return error
        }
    }

}
