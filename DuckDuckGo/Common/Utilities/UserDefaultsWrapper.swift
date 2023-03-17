//
//  UserDefaultsWrapper.swift
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

@propertyWrapper
public struct UserDefaultsWrapper<T> {

    public enum Key: String, CaseIterable {

        case configLastUpdated = "config.last.updated"
        case configStorageTrackerRadarEtag = "config.storage.trackerradar.etag"
        case configStorageBloomFilterSpecEtag = "config.storage.bloomfilter.spec.etag"
        case configStorageBloomFilterBinaryEtag = "config.storage.bloomfilter.binary.etag"
        case configStorageBloomFilterExclusionsEtag = "config.storage.bloomfilter.exclusions.etag"
        case configStorageSurrogatesEtag = "config.storage.surrogates.etag"
        case configStoragePrivacyConfigurationEtag = "config.storage.privacyconfiguration.etag"
        case configFBConfigEtag = "config.storage.fbconfig.etag"

        case fireproofDomains = "com.duckduckgo.fireproofing.allowedDomains"
        case unprotectedDomains = "com.duckduckgo.contentblocker.unprotectedDomains"
        case contentBlockingRulesCache = "com.duckduckgo.contentblocker.rules.cache"

        case defaultBrowserDismissed = "browser.default.dismissed"

        case spellingCheckEnabledOnce = "spelling.check.enabled.once"
        case grammarCheckEnabledOnce = "grammar.check.enabled.once"

        case loginDetectionEnabled = "fireproofing.login-detection-enabled"
        case gpcEnabled = "preferences.gpc-enabled"
        case selectedDownloadLocationKey = "preferences.download-location"
        case lastUsedCustomDownloadLocation = "preferences.custom-last-used-download-location"
        case alwaysRequestDownloadLocationKey = "preferences.download-location.always-request"
        case autoconsentEnabled = "preferences.autoconsent-enabled"
        case privatePlayerMode = "preferences.duck-player"
        case youtubeOverlayInteracted = "preferences.youtube-overlay-interacted"

        case selectedPasswordManager = "preferences.autofill.selected-password-manager"

        case askToSaveUsernamesAndPasswords = "preferences.ask-to-save.usernames-passwords"
        case askToSaveAddresses = "preferences.ask-to-save.addresses"
        case askToSavePaymentMethods = "preferences.ask-to-save.payment-methods"

        case saveAsPreferredFileType = "saveAs.selected.filetype"

        case lastCrashReportCheckDate = "last.crash.report.check.date"

        case fireInfoPresentedOnce = "fire.info.presented.once"

        case restorePreviousSession = "preferences.startup.restore-previous-session"
        case currentThemeName = "com.duckduckgo.macos.currentThemeNameKey"
        case showFullURL = "preferences.appearance.show-full-url"
        case showAutocompleteSuggestions = "preferences.appearance.show-autocomplete-suggestions"

        // ATB
        case installDate = "statistics.installdate.key"
        case atb = "statistics.atb.key"
        case searchRetentionAtb = "statistics.retentionatb.key"
        case appRetentionAtb = "statistics.appretentionatb.key"
        case lastAppRetentionRequestDate = "statistics.appretentionatb.last.request.key"

        // Used to detect whether a user had old User Defaults ATB data at launch, in order to grant them implicitly
        // unlocked status with regards to the lock screen
        case legacyStatisticsStoreDataCleared = "statistics.appretentionatb.legacy-data-cleared"

        case onboardingFinished = "onboarding.finished"

        case homePageShowPagesOnHover = "home.page.show.pages.on.hover"
        case homePageShowAllFavorites = "home.page.show.all.favorites"
        case homePageShowPageTitles = "home.page.show.page.titles"
        case homePageShowRecentlyVisited = "home.page.show.recently.visited"

        case appIsRelaunchingAutomatically = "app-relaunching-automatically"

        case historyV5toV6Migration = "history.v5.to.v6.migration.2"

        case showBookmarksBar = "bookmarks.bar.show"
        case lastBookmarksBarUsagePixelSendDate = "bookmarks.bar.last-usage-pixel-send-date"

        case pinnedViews = "pinning.pinned-views"

        case lastDatabaseFactoryFailurePixelDate = "last.database.factory.failure.pixel.date"
    }

    enum RemovedKeys: String, CaseIterable {
        case passwordManagerDoNotPromptDomains = "com.duckduckgo.passwordmanager.do-not-prompt-domains"
    }

    private let key: Key
    private let defaultValue: T
    private let setIfEmpty: Bool

    private let customUserDefaults: UserDefaults?

    var defaults: UserDefaults {
        customUserDefaults ?? Self.sharedDefaults
    }

    static var sharedDefaults: UserDefaults {
#if DEBUG
        if case .normal = NSApp.runType {
            return .standard
        } else {
            return UserDefaults(suiteName: Bundle.main.bundleIdentifier! + "." + NSApp.runType.description)!
        }
#else
        return .standard
#endif
    }

    public init(key: Key, defaultValue: T, setIfEmpty: Bool = false, defaults: UserDefaults? = nil) {
        self.key = key
        self.defaultValue = defaultValue
        self.setIfEmpty = setIfEmpty
        self.customUserDefaults = defaults
    }

    public var wrappedValue: T {
        get {
            if let storedValue = defaults.object(forKey: key.rawValue),
               let typedValue = storedValue as? T {
                return typedValue
            }

            if setIfEmpty {
                defaults.set(defaultValue, forKey: key.rawValue)
            }

            return defaultValue
        }
        set {
            if (newValue as? AnyOptional)?.isNil == true {
                defaults.removeObject(forKey: key.rawValue)
            } else {
                defaults.set(newValue, forKey: key.rawValue)
            }
        }
    }

    static func clearAll() {
        let defaults = sharedDefaults
        Key.allCases.forEach { key in
            defaults.removeObject(forKey: key.rawValue)
        }
    }

    static func clearRemovedKeys() {
        let defaults = sharedDefaults
        RemovedKeys.allCases.forEach { key in
            defaults.removeObject(forKey: key.rawValue)
        }
    }

    static func clear(_ key: Key) {
        sharedDefaults.removeObject(forKey: key.rawValue)
    }

}
