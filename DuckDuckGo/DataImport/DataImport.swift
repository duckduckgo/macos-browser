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
import PixelKit

enum DataImport {

    enum Source: String, RawRepresentable, CaseIterable, Equatable {
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
        case onePassword8
        case onePassword7
        case bitwarden
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

        var supportedDataTypes: Set<DataType> {
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

        func installedAppsMajorVersionDescription(selectedProfile: BrowserProfile?) -> String? {
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

    enum DataType: String, Hashable, CaseIterable, CustomStringConvertible {

        case bookmarks
        case passwords

        var displayName: String {
            switch self {
            case .bookmarks: UserText.bookmarkImportBookmarks
            case .passwords: UserText.importLoginsPasswords
            }
        }

        var description: String { rawValue }

        var importAction: DataImportAction {
            switch self {
            case .bookmarks: .bookmarks
            case .passwords: .passwords
            }
        }

    }

    struct DataTypeSummary: Equatable {
        let successful: Int
        let duplicate: Int
        let failed: Int

        var isEmpty: Bool {
            self == .empty
        }

        static var empty: Self {
            DataTypeSummary(successful: 0, duplicate: 0, failed: 0)
        }

        init(successful: Int, duplicate: Int, failed: Int) {
            self.successful = successful
            self.duplicate = duplicate
            self.failed = failed
        }
        init(_ bookmarksImportSummary: BookmarksImportSummary) {
            self.init(successful: bookmarksImportSummary.successful, duplicate: bookmarksImportSummary.duplicates, failed: bookmarksImportSummary.failed)
        }
    }

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

    enum ErrorType: String, CustomStringConvertible, CaseIterable {
        case noData
        case decryptionError
        case dataCorrupted
        case keychainError
        case other

        var description: String { rawValue }
    }

}

enum DataImportAction: String, RawRepresentable {
    case bookmarks
    case passwords
    case favicons
    case generic

    init(_ type: DataImport.DataType) {
        switch type {
        case .bookmarks: self = .bookmarks
        case .passwords: self = .passwords
        }
    }
}

protocol DataImportError: Error, CustomNSError, ErrorWithPixelParameters, LocalizedError {
    associatedtype OperationType: RawRepresentable where OperationType.RawValue == Int

    var action: DataImportAction { get }
    var type: OperationType { get }
    var underlyingError: Error? { get }

    var errorType: DataImport.ErrorType { get }

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
extension DataImportError /* : LocalizedError */ {

    var errorDescription: String? {
        let error = (self as NSError)
        return "\(error.domain) \(error.code)" + {
            guard let underlyingError = underlyingError as NSError? else { return "" }
            return " (\(underlyingError.domain) \(underlyingError.code))"
        }()
    }

}

struct FetchableRecordError<T>: Error, CustomNSError {
    let column: Int

    static var errorDomain: String { "FetchableRecordError.\(T.self)" }
    var errorCode: Int { column }
}

enum DataImportProgressEvent {
    case initial
    case importingPasswords(numberOfPasswords: Int?, fraction: Double)
    case importingBookmarks(numberOfBookmarks: Int?, fraction: Double)
    case done
}

typealias DataImportSummary = [DataImport.DataType: DataImportResult<DataImport.DataTypeSummary>]
typealias DataImportTask = TaskWithProgress<DataImportSummary, Never, DataImportProgressEvent>
typealias DataImportProgressCallback = DataImportTask.ProgressUpdateCallback

/// Represents an object able to import data from an outside source. The outside source may be capable of importing multiple types of data.
/// For instance, a browser data importer may be able to import passwords and bookmarks.
protocol DataImporter {

    /// Performs a quick check to determine if the data is able to be imported. It does not guarantee that the import will succeed.
    /// For example, a CSV importer will return true if the URL it has been created with is a CSV file, but does not check whether the CSV data matches the expected format.
    var importableTypes: [DataImport.DataType] { get }

    /// validate file access/encryption password requirement before starting import. Returns non-empty dictionary with failures if access validation fails.
    func validateAccess(for types: Set<DataImport.DataType>) -> [DataImport.DataType: any DataImportError]?
    /// Start import process. Returns cancellable TaskWithProgress
    func importData(types: Set<DataImport.DataType>) -> DataImportTask

    func requiresKeychainPassword(for selectedDataTypes: Set<DataImport.DataType>) -> Bool

}

extension DataImporter {

    var importableTypes: [DataImport.DataType] {
        [.bookmarks, .passwords]
    }

    func validateAccess(for types: Set<DataImport.DataType>) -> [DataImport.DataType: any DataImportError]? {
        nil
    }

    func requiresKeychainPassword(for selectedDataTypes: Set<DataImport.DataType>) -> Bool {
        false
    }

}

enum DataImportResult<T>: CustomStringConvertible {
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

    var isSuccess: Bool {
        if case .success = self {
            true
        } else {
            false
        }
    }

    var error: (any DataImportError)? {
        if case .failure(let error) = self {
            error
        } else {
            nil
        }
    }

    /// Returns a new result, mapping any success value using the given transformation.
    /// - Parameter transform: A closure that takes the success value of this instance.
    /// - Returns: A `Result` instance with the result of evaluating `transform`
    ///   as the new success value if this instance represents a success.
    @inlinable public func map<NewT>(_ transform: (T) -> NewT) -> DataImportResult<NewT> {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Returns a new result, mapping any success value using the given transformation and unwrapping the produced result.
    ///
    /// - Parameter transform: A closure that takes the success value of the instance.
    /// - Returns: A `Result` instance, either from the closure or the previous
    ///   `.failure`.
    @inlinable public func flatMap<NewT>(_ transform: (T) throws -> DataImportResult<NewT>) rethrows -> DataImportResult<NewT> {
        switch self {
        case .success(let value):
            switch try transform(value) {
            case .success(let transformedValue):
                return .success(transformedValue)
            case .failure(let error):
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    var description: String {
        switch self {
        case .success(let value):
            ".success(\(value))"
        case .failure(let error):
            ".failure(\(error))"
        }
    }

}

extension DataImportResult: Equatable where T: Equatable {
    static func == (lhs: DataImportResult<T>, rhs: DataImportResult<T>) -> Bool {
        switch lhs {
        case .success(let value):
            if case .success(value) = rhs {
                true
            } else {
                false
            }
        case .failure(let error1):
            if case .failure(let error2) = rhs {
                error1.errorParameters == error2.errorParameters
            } else {
                false
            }
        }
    }

}

struct LoginImporterError: DataImportError {

    private let error: Error?
    private let _type: OperationType?

    var action: DataImportAction { .passwords }

    init(error: Error?, type: OperationType? = nil) {
        self.error = error
        self._type = type
    }

    struct OperationType: RawRepresentable, Equatable {
        let rawValue: Int

        static let malformedCSV = OperationType(rawValue: -2)
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

            case .keystoreError(let status), .keystoreReadError(let status), .keystoreUpdateError(let status):
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

    var errorType: DataImport.ErrorType {
        if case .malformedCSV = type {
            return .dataCorrupted
        }
        if let secureStorageError = error as? SecureStorageError {
            switch secureStorageError {
            case .initFailed,
                 .authError,
                 .failedToOpenDatabase,
                 .databaseError:
                return .keychainError

            case .keystoreError, .secError, .keystoreReadError, .keystoreUpdateError:
                return .keychainError

            case .authRequired,
                 .invalidPassword,
                 .noL1Key,
                 .noL2Key,
                 .duplicateRecord,
                 .generalCryptoError,
                 .encodingFailed:
                return .decryptionError
            }
        }
        return .other
    }

}
