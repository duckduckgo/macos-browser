//
//  PixelEvent.swift
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

// swiftlint:disable identifier_name
extension Pixel {

    enum Event {
        case appLaunch(isDefault: IsDefaultBrowser = .init(), launch: AppLaunch)
        case launchTiming

        case appUsage
        case appActiveUsage(isDefault: IsDefaultBrowser = .init(), avgTabs: AverageTabsCount)

        case browserMadeDefault

        case burn(repetition: Repetition = .init(key: "fire"),
                  burnedTabs: BurnedTabs = .init(),
                  burnedWindows: BurnedWindows = .init())

        case crash

        case brokenSiteReport

        enum OnboardingShown: String, CustomStringConvertible {
            var description: String { rawValue }

            init(_ value: Bool) {
                if value {
                    self = .onboardingShown
                } else {
                    self = .regularNavigation
                }
            }
            case onboardingShown = "onboarding-shown"
            case regularNavigation = "regular-nav"
        }

        enum WaitResult: String, CustomStringConvertible {
            var description: String { rawValue }

            case closed
            case quit
            case success
        }

        enum CompileRulesWaitTime: String, CustomStringConvertible {
            var description: String { rawValue }

            case noWait = "0"
            case lessThan1s = "1"
            case lessThan5s = "5"
            case lessThan10s = "10"
            case lessThan20s = "20"
            case lessThan40s = "40"
            case more = "more"
        }
        case compileRulesWait(onboardingShown: OnboardingShown, waitTime: CompileRulesWaitTime, result: WaitResult)
        static func compileRulesWait(onboardingShown: Bool, waitTime interval: TimeInterval, result: WaitResult) -> Event {
            let waitTime: CompileRulesWaitTime
            switch interval {
            case 0:
                waitTime = .noWait
            case ...1:
                waitTime = .lessThan1s
            case ...5:
                waitTime = .lessThan5s
            case ...10:
                waitTime = .lessThan10s
            case ...20:
                waitTime = .lessThan20s
            case ...40:
                waitTime = .lessThan40s
            default:
                waitTime = .more
            }
            return .compileRulesWait(onboardingShown: OnboardingShown(onboardingShown),
                                     waitTime: waitTime,
                                     result: result)
        }

        case fireproof(kind: FireproofKind, repetition: Repetition = .init(key: "fireproof"), suggested: FireproofingSuggested)
        case fireproofSuggested(repetition: Repetition = .init(key: "fireproof-suggested"))

        case manageBookmarks(repetition: Repetition = .init(key: "manage-bookmarks"), source: AccessPoint)
        case bookmarksList(repetition: Repetition = .init(key: "bookmarks-list"), source: AccessPoint)
        case manageLogins(repetition: Repetition = .init(key: "manage-logins"), source: AccessPoint)
        case manageDownloads(repetition: Repetition = .init(key: "manage-downloads"), source: AccessPoint)

        case bookmark(fireproofed: IsBookmarkFireproofed, repetition: Repetition = .init(key: "bookmark"), source: AccessPoint)
        case favorite(fireproofed: IsBookmarkFireproofed, repetition: Repetition = .init(key: "favorite"), source: AccessPoint)

        static func bookmark(isFavorite: Bool, fireproofed: IsBookmarkFireproofed, source: AccessPoint) -> Event {
            if isFavorite {
                return .favorite(fireproofed: fireproofed, source: source)
            }
            return .bookmark(fireproofed: fireproofed, source: source)
        }

        case navigation(kind: NavigationKind, source: NavigationAccessPoint)

        case serp

        case suggestionsDisplayed(hasBookmark: HasBookmark, hasFavorite: HasFavorite, hasHistoryEntry: HasHistoryEntry)

        static func suggestionsDisplayed(_ characteristics: SuggestionListChacteristics) -> Event {
            return .suggestionsDisplayed(hasBookmark: characteristics.hasBookmark ? .hasBookmark : .noBookmarks,
                                         hasFavorite: characteristics.hasFavorite ? .hasFavorite : .noFavorites,
                                         hasHistoryEntry: characteristics.hasHistoryEntry ? .hasHistoryEntry : .noHistoryEntry)
        }

        case sharingMenu(repetition: Repetition = .init(key: "sharing"), result: SharingResult)

        case moreMenu(repetition: Repetition = .init(key: "more"), result: MoreResult)

        case refresh(source: RefreshAccessPoint)

        case importedLogins(repetition: Repetition = .init(key: "imported-logins"), source: DataImportSource)
        case exportedLogins(repetition: Repetition = .init(key: "exported-logins"))
        case importedBookmarks(repetition: Repetition = .init(key: "imported-bookmarks"), source: DataImportSource)
        case exportedBookmarks(repetition: Repetition = .init(key: "exported-bookmarks"))

        case formAutofilled(kind: FormAutofillKind)
        case autofillItemSaved(kind: FormAutofillKind)
        
        case waitlistFirstLaunch
        case waitlistPresentedLockScreen
        case waitlistDismissedLockScreen

        case onboardingStartPressed
        case onboardingImportPressed
        case onboardingImportSkipped
        case onboardingSetDefaultPressed
        case onboardingSetDefaultSkipped
        case onboardingTypingSkipped
        
        case autoconsentOptOutFailed
        case autoconsentSelfTestFailed
        
        case passwordManagerLockScreenPreferencesButtonPressed
        case passwordManagerLockScreenDisabled
        case passwordManagerLockScreenTimeoutSelected1Minute
        case passwordManagerLockScreenTimeoutSelected5Minutes
        case passwordManagerLockScreenTimeoutSelected15Minutes
        case passwordManagerLockScreenTimeoutSelected30Minutes
        case passwordManagerLockScreenTimeoutSelected1Hour
        
        case ampBlockingRulesCompilationFailed

        case debug(event: Debug, error: Error? = nil)

        enum Debug: String, CustomStringConvertible {
            var description: String { rawValue }

            case dbInitializationError = "dbie"
            case dbSaveExcludedHTTPSDomainsError = "dbsw"
            case dbSaveBloomFilterError = "dbsb"

            case configurationFetchError = "cfgfetch"

            case trackerDataParseFailed = "tds_p"
            case trackerDataReloadFailed = "tds_r"
            case trackerDataCouldNotBeLoaded = "tds_l"
            
            case privacyConfigurationParseFailed = "pcf_p"
            case privacyConfigurationReloadFailed = "pcf_r"
            case privacyConfigurationCouldNotBeLoaded = "pcf_l"

            case fileStoreWriteFailed = "fswf"
            case fileMoveToDownloadsFailed = "df"

            case suggestionsFetchFailed = "sgf"
            case appOpenURLFailed = "url"
            case appStateRestorationFailed = "srf"
            
            case contentBlockingErrorReportingIssue = "content_blocking_error_reporting_issue"

            case contentBlockingTDSCompilationFailed = "content_blocking_compilation_error_fetched_tds"
            case contentBlockingTempListCompilationFailed = "content_blocking_compilation_error_temp_list"
            case contentBlockingAllowListCompilationFailed = "content_blocking_compilation_error_allow_list"
            case contentBlockingUnpSitesCompilationFailed = "content_blocking_compilation_error_unprotected_list"
            case contentBlockingFallbackCompilationFailed = "content_blocking_compilation_error_fallback_tds"

            case contentBlockingCompilationTime = "content_blocking_compilation_time"

            case clickToLoadTDSCompilationFailed = "click_to_load_compilation_error_fetched_tds"
            case clickToLoadTempListCompilationFailed = "click_to_load_compilation_error_temp_list"
            case clickToLoadAllowListCompilationFailed = "click_to_load_compilation_error_allow_list"
            case clickToLoadUnpSitesCompilationFailed = "click_to_load_compilation_error_unprotected_list"
            case clickToLoadFallbackCompilationFailed = "click_to_load_compilation_error_fallback_tds"

            case secureVaultInitError = "secure_vault_init_error"
            case secureVaultError = "secure_vault_error"

            case feedbackReportingFailed = "feedback_reporting_failed"
            
            case blankNavigationOnBurnFailed = "blank_navigation_on_burn_failed"
        }

    }
}
// swiftlint:enable identifier_name

extension Pixel.Event {

    var name: String {
        switch self {
        case .appLaunch(isDefault: let isDefault, launch: let launch):
            return "ml_mac_app-launch_\(isDefault)_\(launch)"
        case .launchTiming:
            return "ml_mac_launch-timing"

        case .appUsage:
            return "m_mac_usage"

        case .appActiveUsage(isDefault: let isDefault, avgTabs: let avgTabs):
            return "m_mac_active-usage_\(isDefault)_\(avgTabs)"

        case .browserMadeDefault:
            return "m_mac_made-default-browser"

        case .burn(repetition: let repetition, burnedTabs: let tabs, burnedWindows: let windows):
            return "m_mac_fire-button.\(repetition)_\(tabs)_\(windows)"

        case .crash:
            return "m_mac_crash"

        case .brokenSiteReport:
            return "epbf_macos_desktop"

        case .compileRulesWait(onboardingShown: let onboardingShown, waitTime: let waitTime, result: let result):
            return "m_mac_cbr-wait_\(onboardingShown)_\(waitTime)_\(result)"

        case .fireproof(kind: let kind, repetition: let repetition, suggested: let suggested):
            return "m_mac_fireproof_\(kind)_\(repetition)_\(suggested)"

        case .fireproofSuggested(repetition: let repetition):
            return "m_mac_fireproof-suggested_\(repetition)"

        case .manageBookmarks(repetition: let repetition, source: let source):
            return "m_mac_manage-bookmarks_\(repetition)_\(source)"

        case .bookmarksList(repetition: let repetition, source: let source):
            return "m_mac_bookmarks-list_\(repetition)_\(source)"

        case .manageLogins(repetition: let repetition, source: let source):
            return "m_mac_manage-logins_\(repetition)_\(source)"

        case .manageDownloads(repetition: let repetition, source: let source):
            return "m_mac_manage-downloads_\(repetition)_\(source)"

        case .bookmark(fireproofed: let fireproofed, repetition: let repetition, source: let source):
            return "m_mac_bookmark_\(fireproofed)_\(repetition)_\(source)"

        case .favorite(fireproofed: let fireproofed, repetition: let repetition, source: let source):
            return "m_mac_favorite_\(fireproofed)_\(repetition)_\(source)"

        case .navigation(kind: let kind, source: let source):
            return "m_mac_navigation_\(kind)_\(source)"
            
        case .serp:
            return "m_mac_navigation_search"

        case .suggestionsDisplayed(hasBookmark: let hasBookmark, hasFavorite: let hasFavorite, hasHistoryEntry: let hasHistoryEntry):
            return "m_mac_suggestions-displayed_\(hasBookmark)_\(hasFavorite)_\(hasHistoryEntry)"

        case .sharingMenu(repetition: let repetition, result: let result):
            return "m_mac_share_\(repetition)_\(result)"

        case .moreMenu(repetition: let repetition, result: let result):
            return "m_mac_more-menu_\(repetition)_\(result)"

        case .refresh(source: let source):
            return "m_mac_refresh_\(source)"

        case .importedLogins(repetition: let repetition, source: let source):
            return "m_mac_imported-logins_\(repetition)_\(source)"

        case .exportedLogins(repetition: let repetition):
            return "m_mac_exported-logins_\(repetition)"

        case .importedBookmarks(repetition: let repetition, source: let source):
            return "m_mac_imported-bookmarks_\(repetition)_\(source)"

        case .exportedBookmarks(repetition: let repetition):
            return "m_mac_exported-bookmarks_\(repetition)"

        case .formAutofilled(kind: let kind):
            return "m_mac_autofill_\(kind)"

        case .autofillItemSaved(kind: let kind):
            return "m_mac_save_\(kind)"
            
        case .waitlistFirstLaunch:
            return "m_mac_waitlist_first_launch_while_locked"
            
        case .waitlistPresentedLockScreen:
            return "m_mac_waitlist_lock_screen_presented"
            
        case .waitlistDismissedLockScreen:
            return "m_mac_waitlist_lock_screen_dismissed"

        case .debug(event: let event, error: _):
            return "m_mac_debug_\(event)"

        case .onboardingStartPressed:
            return "m_mac_onboarding_start_pressed"

        case .onboardingImportPressed:
            return "m_mac_onboarding_import_pressed"

        case .onboardingImportSkipped:
            return "m_mac_onboarding_import_skipped"

        case .onboardingSetDefaultPressed:
            return "m_mac_onboarding_setdefault_pressed"

        case .onboardingSetDefaultSkipped:
            return "m_mac_onboarding_setdefault_skipped"

        case .onboardingTypingSkipped:
            return "m_mac_onboarding_setdefault_skipped"

        case .autoconsentOptOutFailed:
            return "m_mac_autoconsent_optout_failed"

        case .autoconsentSelfTestFailed:
            return "m_mac_autoconsent_selftest_failed"
            
        case .passwordManagerLockScreenPreferencesButtonPressed:
            return "m_mac_password_mananger_lock_screen_preferences_button_pressed"
            
        case .passwordManagerLockScreenDisabled:
            return "m_mac_password_mananger_lock_screen_disabled"
            
        case .passwordManagerLockScreenTimeoutSelected1Minute:
            return "m_mac_password_mananger_lock_screen_timeout_selected_1_minute"

        case .passwordManagerLockScreenTimeoutSelected5Minutes:
            return "m_mac_password_mananger_lock_screen_timeout_selected_5_minutes"
            
        case .passwordManagerLockScreenTimeoutSelected15Minutes:
            return "m_mac_password_mananger_lock_screen_timeout_selected_15_minutes"
            
        case .passwordManagerLockScreenTimeoutSelected30Minutes:
            return "m_mac_password_mananger_lock_screen_timeout_selected_30_minutes"
            
        case .passwordManagerLockScreenTimeoutSelected1Hour:
            return "m_mac_password_mananger_lock_screen_timeout_selected_1_hour"
            
        case .ampBlockingRulesCompilationFailed:
            return "m_mac_amp_rules_compilation_failed"
        }
    }

}
