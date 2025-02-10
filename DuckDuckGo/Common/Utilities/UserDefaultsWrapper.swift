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

import AppKit
import Foundation
import AppKitExtensions

extension UserDefaults {
    /// The app group's shared UserDefaults
    static let netP = UserDefaults(suiteName: Bundle.main.appGroup(bundle: .netP))!
    static let dbp = UserDefaults(suiteName: Bundle.main.appGroup(bundle: .dbp))!
    static let subs = UserDefaults(suiteName: Bundle.main.appGroup(bundle: .subs))!
    static let appConfiguration = UserDefaults(suiteName: Bundle.main.appGroup(bundle: .appConfiguration))!
}

public struct UserDefaultsWrapperKey: RawRepresentable {
    public let rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

@propertyWrapper
public struct UserDefaultsWrapper<T> {

    public typealias DefaultsKey = UserDefaultsWrapperKey

    public enum Key: String, CaseIterable {
        /// system setting defining window title double-click action
        case appleActionOnDoubleClick = "AppleActionOnDoubleClick"

        case fireproofDomains = "com.duckduckgo.fireproofing.allowedDomains"
        case areDomainsMigratedToETLDPlus1 = "com.duckduckgo.are-domains-migrated-to-etldplus1"
        case unprotectedDomains = "com.duckduckgo.contentblocker.unprotectedDomains"
        case contentBlockingRulesCache = "com.duckduckgo.contentblocker.rules.cache"

        case defaultBrowserDismissed = "browser.default.dismissed"

        case spellingCheckEnabledOnce = "spelling.check.enabled.once"
        case grammarCheckEnabledOnce = "grammar.check.enabled.once"

        case loginDetectionEnabled = "fireproofing.login-detection-enabled"
        case autoClearEnabled = "preferences.auto-clear-enabled"
        case warnBeforeClearingEnabled = "preferences.warn-before-clearing-enabled"
        case gpcEnabled = "preferences.gpc-enabled"
        case selectedDownloadLocationKey = "preferences.download-location"
        case lastUsedCustomDownloadLocation = "preferences.custom-last-used-download-location"
        case alwaysRequestDownloadLocationKey = "preferences.download-location.always-request"
        case openDownloadsPopupOnCompletionKey = "preferences.downloads.open.on.completion"
        case autoconsentEnabled = "preferences.autoconsent-enabled"
        case duckPlayerMode = "preferences.duck-player"
        case youtubeOverlayInteracted = "preferences.youtube-overlay-interacted"
        case youtubeOverlayButtonsUsed = "preferences.youtube-overlay-user-used-buttons"
        case duckPlayerAutoplay = "preferences.duckplayer.autoplay"
        case duckPlayerOpenInNewTab = "preferences.duckplayer.open-new-tab"

        case selectedPasswordManager = "preferences.autofill.selected-password-manager"

        case askToSaveUsernamesAndPasswords = "preferences.ask-to-save.usernames-passwords"
        case askToSaveAddresses = "preferences.ask-to-save.addresses"
        case askToSavePaymentMethods = "preferences.ask-to-save.payment-methods"
        case autolockLocksFormFilling = "preferences.lock-autofill-form-fill"
        case autofillDebugScriptEnabled = "preferences.enable-autofill-debug-script"

        case saveAsPreferredFileType = "saveAs.selected.filetype"

        case lastCrashReportCheckDate = "last.crash.report.check.date"
        case didCrashDuringCrashHandlersSetUp = "browser.didCrashDuringCrashHandlersSetUp"

        case fireInfoPresentedOnce = "fire.info.presented.once"
        case appTerminationHandledCorrectly = "app.termination.handled.correctly"
        case restoreTabsOnStartup = "restore.tabs.on.startup"

        case restorePreviousSession = "preferences.startup.restore-previous-session"
        case launchToCustomHomePage = "preferences.startup.launch-to-custom-home-page"
        case customHomePageURL = "preferences.startup.customHomePageURL"
        case currentThemeName = "com.duckduckgo.macos.currentThemeNameKey"
        case showFullURL = "preferences.appearance.show-full-url"
        case showAutocompleteSuggestions = "preferences.appearance.show-autocomplete-suggestions"
        case preferNewTabsToWindows = "preferences.tabs.prefer-new-tabs-to-windows"
        case switchToNewTabWhenOpened = "preferences.tabs.switch-to-new-tab-when-opened"
        case newTabPosition = "preferences.tabs.new-tab-position"
        case defaultPageZoom = "preferences.appearance.default-page-zoom"
        case websitePageZoom = "preferences.appearance.website-page-zoom"
        case bookmarksBarAppearance = "preferences.appearance.bookmarks-bar"

        case homeButtonPosition = "preferences.appeareance.home-button-position"

        case maliciousSiteDetectionEnabled = "preferences.security.phishing-detection-enabled"

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
        case contextualOnboardingState = "contextual.onboarding.state"

        // Home Page
        case homePageShowPagesOnHover = "home.page.show.pages.on.hover"
        case homePageShowAllFavorites = "home.page.show.all.favorites"
        case homePageShowAllFeatures = "home.page.show.all.features"
        case homePageShowMakeDefault = "home.page.show.make.default"
        case homePageShowAddToDock = "home.page.show.add.to.dock"
        case homePageShowImport = "home.page.show.import"
        case homePageShowDuckPlayer = "home.page.show.duck.player"
        case homePageShowEmailProtection = "home.page.show.email.protection"
        case homePageShowPageTitles = "home.page.show.page.titles"
        case homePageShowRecentlyVisited = "home.page.show.recently.visited"
        case homePageContinueSetUpImport = "home.page.continue.set.up.import"
        case homePageIsFavoriteVisible = "home.page.is.favorite.visible"
        case homePageIsContinueSetupVisible = "home.page.is.continue.setup.visible"
        case continueSetUpCardsLastDemonstrated = "home.page.contiune.setup.last.demonstrated"
        case continueSetUpCardsNumberOfDaysDemonstrated = "home.page.contiune.setup.demo.days"
        case continueSetUpCardsClosed = "home.page.contiune.setup.cards.closed"
        case homePageIsRecentActivityVisible = "home.page.is.recent.activity.visible"
        case homePageIsPrivacyStatsVisible = "home.page.is.privacy.stats.visible"
        case homePageIsSearchBarVisible = "home.page.is.search.bar.visible"
        case homePageIsFirstSession = "home.page.is.first.session"
        case homePageDidShowSettingsOnboarding = "home.page.did.show.settings.onboarding"
        case homePageUserBackgroundImages = "home.page.user.background.images"
        case homePageCustomBackground = "home.page.custom.background"
        case homePageLastPickedCustomColor = "home.page.last.picked.custom.color"

        case homePagePromotionVisible = "home.page.promotion.visible"
        case homePagePromotionDidDismiss = "home.page.promotion.did.dismiss"

        case appIsRelaunchingAutomatically = "app-relaunching-automatically"

        case historyV5toV6Migration = "history.v5.to.v6.migration.2"
        case emailKeychainMigration = "email.keychain.migration"

        case bookmarksBarPromptShown = "bookmarks.bar.prompt.shown"
        case showBookmarksBar = "bookmarks.bar.show"
        case centerAlignedBookmarksBar = "bookmarks.bar.center.aligned"
        case lastBookmarksBarUsagePixelSendDate = "bookmarks.bar.last-usage-pixel-send-date"

        case showTabsAndBookmarksBarOnFullScreen = "show.toolbars.on.fullscren"

        case pinnedViews = "pinning.pinned-views"
        case manuallyToggledPinnedViews = "pinning.manually-toggled-pinned-views"

        case lastDatabaseFactoryFailurePixelDate = "last.database.factory.failure.pixel.date"

        case loggingEnabledDate = "logging.enabled.date"
        case loggingCategories = "logging.categories"

        case firstLaunchDate = "first.app.launch.date"
        case customConfigurationUrl = "custom.configuration.url"

        case lastRemoteMessagingRefreshDate = "last.remote.messaging.refresh.date"

        // Data Broker Protection

        case dataBrokerProtectionTermsAndConditionsAccepted = "data-broker-protection.waitlist-terms-and-conditions.accepted"
        case shouldShowDBPWaitlistInvitedCardUI = "shouldShowDBPWaitlistInvitedCardUI"

        // VPN

        case networkProtectionExcludedRoutes = "netp.excluded-routes"

        // VPN: Shared Defaults
        // ---
        // Please note that shared defaults MUST have a name that matches exactly their value,
        // or else KVO will just not work as of 2023-08-07

        case networkProtectionOnboardingStatusRawValue = "networkProtectionOnboardingStatusRawValue"

        // Updates
        case automaticUpdates = "updates.automatic"
        case pendingUpdateShown = "pending.update.shown"

        // Experiments
        case pixelExperimentInstalled = "pixel.experiment.installed"
        case pixelExperimentCohort = "pixel.experiment.cohort"
        case pixelExperimentEnrollmentDate = "pixel.experiment.enrollment.date"
        case pixelExperimentFiredPixels = "pixel.experiment.pixels.fired"
        case campaignVariant = "campaign.variant"

        // Updates
        case previousAppVersion = "previous.app.version"
        case previousBuild = "previous.build"

        // Sync

        case syncEnvironment = "sync.environment"
        case favoritesDisplayMode = "sync.favorites-display-mode"
        case syncBookmarksPaused = "sync.bookmarks-paused"
        case syncCredentialsPaused = "sync.credentials-paused"
        case syncIsPaused = "sync.paused"
        case syncBookmarksPausedErrorDisplayed = "sync.bookmarks-paused-error-displayed"
        case syncCredentialsPausedErrorDisplayed = "sync.credentials-paused-error-displayed"
        case syncInvalidLoginPausedErrorDisplayed = "sync.invalid-login-paused-error-displayed"
        case syncIsFaviconsFetcherEnabled = "sync.is-favicons-fetcher-enabled"
        case syncIsEligibleForFaviconsFetcherOnboarding = "sync.is-eligible-for-favicons-fetcher-onboarding"
        case syncDidPresentFaviconsFetcherOnboarding = "sync.did-present-favicons-fetcher-onboarding"
        case syncDidMigrateToImprovedListsHandling = "sync.did-migrate-to-improved-lists-handling"
        case syncDidShowSyncPausedByFeatureFlagAlert = "sync.did-show-sync-paused-by-feature-flag-alert"
        case syncLastErrorNotificationTime = "sync.last-error-notification-time"
        case syncLastSuccesfullTime = "sync.last-time-success"
        case syncLastNonActionableErrorCount = "sync.non-actionable-error-count"
        case syncCurrentAllPausedError = "sync.current-all-paused-error"
        case syncCurrentBookmarksPausedError = "sync.current-bookmarks-paused-error"
        case syncCurrentCredentialsPausedError = "sync.current-credentials-paused-error"
        case syncPromoBookmarksDismissed = "sync.promotion-bookmarks-dismissed"
        case syncPromoPasswordsDismissed = "sync.promotion-passwords-dismissed"

        // Subscription

        case subscriptionEnvironment = "subscription.environment"

        // PageRefreshMonitor

        case refreshTimestamps = "pageRefreshMonitor.refresh-timestamps"

        // BrokenSitePrompt

        case lastBrokenSiteToastShownDate = "brokenSitePrompt.last-broken-site-toast-shown-date"
        case toastDismissStreakCounter = "brokenSitePrompt.toast-dismiss-streak-counter"

        // Web Extensions
        case webExtensionPathsCache = "com.duckduckgo.web.extension.paths.cache"
    }

    enum RemovedKeys: String, CaseIterable {
        case passwordManagerDoNotPromptDomains = "com.duckduckgo.passwordmanager.do-not-prompt-domains"
        case incrementalFeatureFlagTestHasSentPixel = "network-protection.incremental-feature-flag-test.has-sent-pixel"
        case homePageShowNetworkProtectionBetaEndedNotice = "home.page.network-protection.show-beta-ended-notice"

        // NetP removed keys
        case networkProtectionShouldEnforceRoutes = "netp.enforce-routes"
        case networkProtectionShouldIncludeAllNetworks = "netp.include-all-networks"
        case networkProtectionConnectionTesterEnabled = "netp.connection-tester-enabled"
        case networkProtectionShouldExcludeLocalNetworks = "netp.exclude-local-routes"
        case networkProtectionRegistrationKeyValidity = "com.duckduckgo.network-protection.NetworkProtectionTunnelController.registrationKeyValidityKey"
        case shouldShowNetworkProtectionSystemExtensionUpgradePrompt = "network-protection.show-system-extension-upgrade-prompt"
    }

    private let key: DefaultsKey
    private let getter: (Any?) -> T
    private let setter: (UserDefaultsWrapper, T) -> Void

    private let customUserDefaults: UserDefaults?

    var defaults: UserDefaults {
        customUserDefaults ?? Self.sharedDefaults
    }

    static var sharedDefaults: UserDefaults {
#if DEBUG && !(NETP_SYSTEM_EXTENSION && NETWORK_EXTENSION) // Avoid looking up special user defaults when running inside the system extension
        if case .normal = NSApplication.runType {
            return .standard
        } else {
            return UserDefaults(suiteName: "\(Bundle.main.bundleIdentifier!).\(NSApplication.runType)")!
        }
#else
        return .standard
#endif
    }

    public init(key: DefaultsKey, defaults: UserDefaults? = nil, getter: @escaping (Any?) -> T, setter: @escaping (UserDefaultsWrapper, T) -> Void) {
        self.key = key
        self.getter = getter
        self.setter = setter
        self.customUserDefaults = defaults
    }

    @_disfavoredOverload
    public init(key: DefaultsKey, defaultValue: T, defaults: UserDefaults? = nil) {
        @inline(__always) func isNil(_ value: T) -> Bool {
            @inline(__always) func cast<V, R>(_ value: V, to _: R.Type) -> R? {
                value as? R // perform `value as? Any?` suppressing `casting to Any? always succeeds` warning
            }
            return if case .some(.none) = cast(value, to: Any?.self) { true } else { false }
        }

        self.init(key: key, defaults: defaults) {
            guard let value = $0 as? T, !isNil(value) else { return defaultValue }
            return value
        } setter: { this, newValue in
            guard PropertyListSerialization.propertyList(newValue, isValidFor: .binary) else {
                if isNil(newValue) {
                    this.defaults.removeObject(forKey: key.rawValue)
                    return
                }
                assertionFailure("\(newValue) cannot be stored in UserDefaults")
                return
            }
            this.defaults.set(newValue, forKey: key.rawValue)
        }
    }

    public init<Wrapped>(key: DefaultsKey, defaults: UserDefaults? = nil) where T == Wrapped? {
        self.init(key: key, defaults: defaults) {
            $0 as? Wrapped
        } setter: { this, newValue in
            guard let newValue else {
                this.defaults.removeObject(forKey: key.rawValue) // newValue is nil
                return
            }
            guard PropertyListSerialization.propertyList(newValue, isValidFor: .binary) else {
                assertionFailure("\(newValue) cannot be stored in UserDefaults")
                return
            }
            this.defaults.set(newValue, forKey: key.rawValue)
        }
    }

    @available(*, unavailable, message: "Cannot use overload with `defaultValue` for an Optional Value")
    public init<Wrapped>(key: DefaultsKey, defaultValue: Wrapped, defaults: UserDefaults? = nil) where T == Wrapped? {
        fatalError()
    }

    public init<RawValue>(key: DefaultsKey, defaultValue: T, defaults: UserDefaults? = nil) where T: RawRepresentable<RawValue> {
        self.init(key: key, defaults: defaults) {
            ($0 as? RawValue).flatMap(T.init(rawValue:)) ?? defaultValue
        } setter: { this, newValue in
            guard PropertyListSerialization.propertyList(newValue.rawValue, isValidFor: .binary) else {
                assertionFailure("\(newValue.rawValue) cannot be stored in UserDefaults")
                return
            }
            this.defaults.set(newValue.rawValue, forKey: key.rawValue)
        }
    }

    public init<Wrapped, RawValue>(key: DefaultsKey, defaults: UserDefaults? = nil) where T == Wrapped?, Wrapped: RawRepresentable<RawValue> {
        self.init(key: key, defaults: defaults) {
            ($0 as? RawValue).flatMap(Wrapped.init(rawValue:))
        } setter: { this, newValue in
            guard let newValue else {
                this.defaults.removeObject(forKey: key.rawValue) // newValue is nil
                return
            }
            guard PropertyListSerialization.propertyList(newValue.rawValue, isValidFor: .binary) else {
                assertionFailure("\(newValue.rawValue) cannot be stored in UserDefaults")
                return
            }
            this.defaults.set(newValue.rawValue, forKey: key.rawValue)
        }
    }

    @_disfavoredOverload
    public init(key: Key, defaultValue: T, defaults: UserDefaults? = nil) {
        self.init(key: .init(rawValue: key.rawValue), defaultValue: defaultValue, defaults: defaults)
    }

    public init<Wrapped>(key: Key, defaults: UserDefaults? = nil) where T == Wrapped? {
        self.init(key: .init(rawValue: key.rawValue), defaults: defaults)
    }

    public init<RawValue>(key: Key, defaultValue: T, defaults: UserDefaults? = nil) where T: RawRepresentable<RawValue> {
        self.init(key: .init(rawValue: key.rawValue), defaultValue: defaultValue, defaults: defaults)
    }

    public init<Wrapped, RawValue>(key: Key, defaults: UserDefaults? = nil) where T == Wrapped?, Wrapped: RawRepresentable<RawValue> {
        self.init(key: .init(rawValue: key.rawValue), defaults: defaults)
    }

    public var wrappedValue: T {
        get {
            let storedValue = defaults.object(forKey: key.rawValue)
            return getter(storedValue)
        }
        nonmutating set {
            setter(self, newValue)
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

    func clear() {
        defaults.removeObject(forKey: key.rawValue)
    }

}

extension UserDefaultsWrapper where T == Any {
    static func clear(_ key: Key) {
        sharedDefaults.removeObject(forKey: key.rawValue)
    }
    static func clear(_ key: DefaultsKey) {
        sharedDefaults.removeObject(forKey: key.rawValue)
    }
}
