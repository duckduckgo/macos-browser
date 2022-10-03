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
import BrowserServicesKit

// swiftlint:disable identifier_name
extension Pixel {

    enum Event {
        case appLaunch(isDefault: IsDefaultBrowser = .init(), launch: AppLaunch)
        case launchTiming

        case appUsage

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

        case navigation(kind: NavigationKind, source: NavigationAccessPoint)

        case serp

        case importedLogins(repetition: Repetition = .init(key: "imported-logins"), source: DataImportSource)
        case importedBookmarks(repetition: Repetition = .init(key: "imported-bookmarks"), source: DataImportSource)
        
        case dataImportFailed(action: DataImportAction, source: DataImportSource)

        case formAutofilled(kind: FormAutofillKind)
        case autofillItemSaved(kind: FormAutofillKind)
        
        case waitlistFirstLaunch
        case waitlistPresentedLockScreen
        case waitlistDismissedLockScreen

        case autoconsentOptOutFailed
        case autoconsentSelfTestFailed
        
        case ampBlockingRulesCompilationFailed
        
        case adClickAttributionDetected
        case adClickAttributionActive
        
        case debug(event: Debug, error: Error? = nil)

        enum Debug {

            case dbInitializationError
            case dbSaveExcludedHTTPSDomainsError
            case dbSaveBloomFilterError

            case configurationFetchError

            case trackerDataParseFailed
            case trackerDataReloadFailed
            case trackerDataCouldNotBeLoaded

            case privacyConfigurationParseFailed
            case privacyConfigurationReloadFailed
            case privacyConfigurationCouldNotBeLoaded

            case fileStoreWriteFailed
            case fileMoveToDownloadsFailed

            case suggestionsFetchFailed
            case appOpenURLFailed
            case appStateRestorationFailed

            case contentBlockingErrorReportingIssue
            
            case contentBlockingCompilationFailed(listType: CompileRulesListType,
                                                  component: ContentBlockerDebugEvents.Component)

            case contentBlockingCompilationTime

            case secureVaultInitError
            case secureVaultError

            case feedbackReportingFailed

            case blankNavigationOnBurnFailed

            case historyRemoveFailed
            case historyReloadFailed
            case historyCleanEntriesFailed
            case historyCleanVisitsFailed
            case historySaveFailed
            case historyInsertVisitFailed
            case historyRemoveVisitsFailed

            case emailAutofillKeychainError

            case bookmarksStoreRootFolderMigrationFailed
            
            case adAttributionCompilationFailedForAttributedRulesList
            case adAttributionGlobalAttributedRulesDoNotExist
            case adAttributionDetectionHeuristicsDidNotMatchDomain
            case adAttributionLogicUnexpectedStateOnRulesCompiled
            case adAttributionLogicUnexpectedStateOnInheritedAttribution
            case adAttributionLogicUnexpectedStateOnRulesCompilationFailed
            case adAttributionDetectionInvalidDomainInParameter
            case adAttributionLogicRequestingAttributionTimedOut
            case adAttributionLogicWrongVendorOnSuccessfulCompilation
            case adAttributionLogicWrongVendorOnFailedCompilation
            
            case webKitDidTerminate
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

        case .navigation(kind: let kind, source: let source):
            return "m_mac_navigation_\(kind)_\(source)"
            
        case .serp:
            return "m_mac_navigation_search"

        case .importedLogins(repetition: let repetition, source: let source):
            return "m_mac_imported-logins_\(repetition)_\(source)"

        case .importedBookmarks(repetition: let repetition, source: let source):
            return "m_mac_imported-bookmarks_\(repetition)_\(source)"
            
        case .dataImportFailed(action: let action, source: let source):
            return "m_mac_data-import-failed_\(action)_\(source)"

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
            return "m_mac_debug_\(event.name)"

        case .autoconsentOptOutFailed:
            return "m_mac_autoconsent_optout_failed"

        case .autoconsentSelfTestFailed:
            return "m_mac_autoconsent_selftest_failed"
            
        case .ampBlockingRulesCompilationFailed:
            return "m_mac_amp_rules_compilation_failed"
            
        case .adClickAttributionDetected:
            return "m_mac_ad_click_detected"
            
        case .adClickAttributionActive:
            return "m_mac_ad_click_active"
        }
    }
}

extension Pixel.Event.Debug {
    
    var name: String {
        switch self {
        
        case .dbInitializationError:
            return "dbie"
        case .dbSaveExcludedHTTPSDomainsError:
            return "dbsw"
        case .dbSaveBloomFilterError:
            return "dbsb"
            
        case .configurationFetchError:
            return "cfgfetch"
            
        case .trackerDataParseFailed:
            return "tds_p"
        case .trackerDataReloadFailed:
            return "tds_r"
        case .trackerDataCouldNotBeLoaded:
            return "tds_l"
            
        case .privacyConfigurationParseFailed:
            return "pcf_p"
        case .privacyConfigurationReloadFailed:
            return "pcf_r"
        case .privacyConfigurationCouldNotBeLoaded:
            return "pcf_l"
            
        case .fileStoreWriteFailed:
            return "fswf"
        case .fileMoveToDownloadsFailed:
            return "df"
            
        case .suggestionsFetchFailed:
            return "sgf"
        case .appOpenURLFailed:
            return "url"
        case .appStateRestorationFailed:
            return "srf"
            
        case .contentBlockingErrorReportingIssue:
            return "content_blocking_error_reporting_issue"
            
        case .contentBlockingCompilationFailed(let listType, let component):
            let componentString: String
            switch component {
            case .tds:
                componentString = "fetched_tds"
            case .allowlist:
                componentString = "allow_list"
            case .tempUnprotected:
                componentString = "temp_list"
            case .localUnprotected:
                componentString = "unprotected_list"
            case .fallbackTds:
                componentString = "fallback_tds"
            }
            return "content_blocking_\(listType)_compilation_error_\(componentString)"
            
        case .contentBlockingCompilationTime:
            return "content_blocking_compilation_time"
            
        case .secureVaultInitError:
            return "secure_vault_init_error"
        case .secureVaultError:
            return "secure_vault_error"
            
        case .feedbackReportingFailed:
            return "feedback_reporting_failed"
            
        case .blankNavigationOnBurnFailed:
            return "blank_navigation_on_burn_failed"
            
        case .historyRemoveFailed:
            return "history_remove_failed"
        case .historyReloadFailed:
            return "history_reload_failed"
        case .historyCleanEntriesFailed:
            return "history_clean_entries_failed"
        case .historyCleanVisitsFailed:
            return "history_clean_visits_failed"
        case .historySaveFailed:
            return "history_save_failed"
        case .historyInsertVisitFailed:
            return "history_insert_visit_failed"
        case .historyRemoveVisitsFailed:
            return "history_remove_visits_failed"
            
        case .emailAutofillKeychainError:
            return "email_autofill_keychain_error"
            
        case .bookmarksStoreRootFolderMigrationFailed:
            return "bookmarks_store_root_folder_migration_failed"
            
        case .adAttributionCompilationFailedForAttributedRulesList:
            return "ad_attribution_compilation_failed_for_attributed_rules_list"
        case .adAttributionGlobalAttributedRulesDoNotExist:
            return "ad_attribution_global_attributed_rules_do_not_exist"
        case .adAttributionDetectionHeuristicsDidNotMatchDomain:
            return "ad_attribution_detection_heuristics_did_not_match_domain"
        case .adAttributionLogicUnexpectedStateOnRulesCompiled:
            return "ad_attribution_logic_unexpected_state_on_rules_compiled"
        case .adAttributionLogicUnexpectedStateOnInheritedAttribution:
            return "ad_attribution_logic_unexpected_state_on_inherited_attribution"
        case .adAttributionLogicUnexpectedStateOnRulesCompilationFailed:
            return "ad_attribution_logic_unexpected_state_on_rules_compilation_failed"
        case .adAttributionDetectionInvalidDomainInParameter:
            return "ad_attribution_detection_invalid_domain_in_parameter"
        case .adAttributionLogicRequestingAttributionTimedOut:
            return "ad_attribution_logic_requesting_attribution_timed_out"
        case .adAttributionLogicWrongVendorOnSuccessfulCompilation:
            return "ad_attribution_logic_wrong_vendor_on_successful_compilation"
        case .adAttributionLogicWrongVendorOnFailedCompilation:
            return "ad_attribution_logic_wrong_vendor_on_failed_compilation"
            
        case .webKitDidTerminate:
            return "webkit_did_terminate"
        }
    }
}
