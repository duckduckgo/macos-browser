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
import Bookmarks
import Configuration

extension Pixel {

    enum Event {
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

        case serp

        case dataImportFailed(action: DataImportAction, source: DataImportSource)
        case faviconImportFailed(source: DataImportSource)

        case formAutofilled(kind: FormAutofillKind)
        case autofillItemSaved(kind: FormAutofillKind)

        case autoconsentOptOutFailed
        case autoconsentSelfTestFailed

        case ampBlockingRulesCompilationFailed

        case adClickAttributionDetected
        case adClickAttributionActive

        case emailEnabled
        case emailDisabled
        case emailUserPressedUseAddress
        case emailUserPressedUseAlias
        case emailUserCreatedAlias

        case jsPixel(_ pixel: AutofillUserScript.JSPixel)
        case debug(event: Debug, error: Error? = nil)

        enum Debug {

            case assertionFailure(message: String, file: StaticString, line: UInt)

            case dbMakeDatabaseError
            case dbContainerInitializationError
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
            case fileGetDownloadLocationFailed

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
            case bookmarksStoreFavoritesFolderMigrationFailed

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

            case removedInvalidBookmarkManagedObjects

            case bitwardenNotResponding
            case bitwardenRespondedCannotDecrypt
            case bitwardenRespondedCannotDecryptUnique(repetition: Repetition = .init(key: "bitwardenRespondedCannotDecryptUnique"))
            case bitwardenHandshakeFailed
            case bitwardenDecryptionOfSharedKeyFailed
            case bitwardenStoringOfTheSharedKeyFailed
            case bitwardenCredentialRetrievalFailed
            case bitwardenCredentialCreationFailed
            case bitwardenCredentialUpdateFailed
            case bitwardenRespondedWithError
            case bitwardenNoActiveVault
            case bitwardenParsingFailed
            case bitwardenStatusParsingFailed
            case bitwardenHmacComparisonFailed
            case bitwardenDecryptionFailed
            case bitwardenSendingOfMessageFailed
            case bitwardenSharedKeyInjectionFailed

            case updaterAborted
            case userSelectedToSkipUpdate
            case userSelectedToInstallUpdate
            case userSelectedToDismissUpdate

            case faviconDecryptionFailed
            case downloadListItemDecryptionFailed
            case historyEntryDecryptionFailed
            case permissionDecryptionFailed

            // Errors from Bookmarks Module
            case missingParent
            case bookmarksSaveFailed
            case bookmarksSaveFailedOnImport

            case bookmarksCouldNotLoadDatabase
            case bookmarksCouldNotPrepareDatabase
            case bookmarksMigrationAlreadyPerformed
            case bookmarksMigrationFailed
            case bookmarksMigrationCouldNotPrepareDatabase
            case bookmarksMigrationCouldNotPrepareDatabaseOnFailedMigration
            case bookmarksMigrationCouldNotRemoveOldStore

            case invalidPayload(Configuration)

            case burnerTabMisplaced

        }

    }
}

extension Pixel.Event {

    var name: String {
        switch self {
        case .crash:
            return "m_mac_crash"

        case .brokenSiteReport:
            return "epbf_macos_desktop"

        case .compileRulesWait(onboardingShown: let onboardingShown, waitTime: let waitTime, result: let result):
            return "m_mac_cbr-wait_\(onboardingShown)_\(waitTime)_\(result)"

        case .serp:
            return "m_mac_navigation_search"

        case .dataImportFailed(action: let action, source: let source):
            return "m_mac_data-import-failed_\(action)_\(source)"

        case .faviconImportFailed(source: let source):
            return "m_mac_favicon-import-failed_\(source)"

        case .formAutofilled(kind: let kind):
            return "m_mac_autofill_\(kind)"

        case .autofillItemSaved(kind: let kind):
            return "m_mac_save_\(kind)"

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

        // Deliberately omit the `m_mac_` prefix in order to format these pixels the same way as other platforms
        case .emailEnabled: return "email_enabled_macos_desktop"
        case .emailDisabled: return "email_disabled_macos_desktop"
        case .emailUserPressedUseAddress: return "email_filled_main_macos_desktop"
        case .emailUserPressedUseAlias: return "email_filled_random_macos_desktop"
        case .emailUserCreatedAlias: return "email_generated_button_macos_desktop"

        case .jsPixel(let pixel):
            // Email pixels deliberately avoid using the `m_mac_` prefix.
            if pixel.isEmailPixel {
                return "\(pixel.pixelName)_macos_desktop"
            } else {
                return "m_mac_\(pixel.pixelName)"
            }
        }
    }
}

extension Pixel.Event.Debug {

    var name: String {
        switch self {

        case .assertionFailure:
            return "assertion_failure"

        case .dbMakeDatabaseError:
            return "database_make_database_error"
        case .dbContainerInitializationError:
            return "database_container_error"
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
        case .fileGetDownloadLocationFailed:
            return "dl"

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
        case .bookmarksStoreFavoritesFolderMigrationFailed:
            return "bookmarks_store_favorites_folder_migration_failed"

        case .adAttributionCompilationFailedForAttributedRulesList:
            return "ad_attribution_compilation_failed_for_attributed_rules_list"
        case .adAttributionGlobalAttributedRulesDoNotExist:
            return "ad_attribution_global_attributed_rules_do_not_exist"
        case .adAttributionDetectionHeuristicsDidNotMatchDomain:
            return "ad_attribution_detection_heuristics_did_not_match_domain"
        case .adAttributionLogicUnexpectedStateOnRulesCompiled:
            return "ad_attribution_logic_unexpected_state_on_rules_compiled"
        case .adAttributionLogicUnexpectedStateOnInheritedAttribution:
            return "ad_attribution_logic_unexpected_state_on_inherited_attribution_2"
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

        case .removedInvalidBookmarkManagedObjects:
            return "removed_invalid_bookmark_managed_objects"

        case .bitwardenNotResponding:
            return "bitwarden_not_responding"
        case .bitwardenRespondedCannotDecrypt:
            return "bitwarden_responded_cannot_decrypt"
        case .bitwardenRespondedCannotDecryptUnique:
            return "bitwarden_responded_cannot_decrypt_unique"
        case .bitwardenHandshakeFailed:
            return "bitwarden_handshake_failed"
        case .bitwardenDecryptionOfSharedKeyFailed:
            return "bitwarden_decryption_of_shared_key_failed"
        case .bitwardenStoringOfTheSharedKeyFailed:
            return "bitwarden_storing_of_the_shared_key_failed"
        case .bitwardenCredentialRetrievalFailed:
            return "bitwarden_credential_retrieval_failed"
        case .bitwardenCredentialCreationFailed:
            return "bitwarden_credential_creation_failed"
        case .bitwardenCredentialUpdateFailed:
            return "bitwarden_credential_update_failed"
        case .bitwardenRespondedWithError:
            return "bitwarden_responded_with_error"
        case .bitwardenNoActiveVault:
            return "bitwarden_no_active_vault"
        case .bitwardenParsingFailed:
            return "bitwarden_parsing_failed"
        case .bitwardenStatusParsingFailed:
            return "bitwarden_status_parsing_failed"
        case .bitwardenHmacComparisonFailed:
            return "bitwarden_hmac_comparison_failed"
        case .bitwardenDecryptionFailed:
            return "bitwarden_decryption_failed"
        case .bitwardenSendingOfMessageFailed:
            return "bitwarden_sending_of_message_failed"
        case .bitwardenSharedKeyInjectionFailed:
            return "bitwarden_shared_key_injection_failed"

        case .updaterAborted:
            return "updater_aborted"
        case .userSelectedToSkipUpdate:
            return "user_selected_to_skip_update"
        case .userSelectedToInstallUpdate:
            return "user_selected_to_install_update"
        case .userSelectedToDismissUpdate:
            return "user_selected_to_dismiss_update"

        case .faviconDecryptionFailed:
            return "favicon_decryption_failed"
        case .downloadListItemDecryptionFailed:
            return "download_list_item_decryption_failed"
        case .historyEntryDecryptionFailed:
            return "history_entry_decryption_failed"
        case .permissionDecryptionFailed:
            return "permission_decryption_failed"

        case .missingParent: return "bookmark_missing_parent"
        case .bookmarksSaveFailed: return "bookmarks_save_failed"
        case .bookmarksSaveFailedOnImport: return "bookmarks_save_failed_on_import"

        case .bookmarksCouldNotLoadDatabase: return "bookmarks_could_not_load_database"
        case .bookmarksCouldNotPrepareDatabase: return "bookmarks_could_not_prepare_database"
        case .bookmarksMigrationAlreadyPerformed: return "bookmarks_migration_already_performed"
        case .bookmarksMigrationFailed: return "bookmarks_migration_failed"
        case .bookmarksMigrationCouldNotPrepareDatabase: return "bookmarks_migration_could_not_prepare_database"
        case .bookmarksMigrationCouldNotPrepareDatabaseOnFailedMigration:
            return "bookmarks_migration_could_not_prepare_database_on_failed_migration"
        case .bookmarksMigrationCouldNotRemoveOldStore: return "bookmarks_migration_could_not_remove_old_store"

        case .invalidPayload(let configuration): return "m_d_\(configuration.rawValue)_invalid_payload".lowercased()

        case .burnerTabMisplaced: return "burner_tab_misplaced"

        }
    }
}
