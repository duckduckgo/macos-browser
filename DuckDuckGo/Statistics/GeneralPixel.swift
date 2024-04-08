//
//  GeneralPixel.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import PixelKit
import BrowserServicesKit
import DDGSync
import Configuration

// swiftlint:disable:next type_body_length
enum GeneralPixel: PixelKitEventV2 {

    case crash
    case brokenSiteReport
    case compileRulesWait(onboardingShown: OnboardingShown, waitTime: CompileRulesWaitTime, result: WaitResult)
    case launchInitial(cohort: String)

    case serp
    case serpInitial(cohort: String)
    case serpDay21to27(cohort: String)

    case dailyOsVersionCounter

    case dataImportFailed(source: DataImport.Source, sourceVersion: String?, error: any DataImportError)

    case formAutofilled(kind: FormAutofillKind)
    case autofillItemSaved(kind: FormAutofillKind)

    case autofillLoginsSaveLoginModalExcludeSiteConfirmed
    case autofillLoginsSettingsResetExcludedDisplayed
    case autofillLoginsSettingsResetExcludedConfirmed
    case autofillLoginsSettingsResetExcludedDismissed

    case bitwardenPasswordAutofilled
    case bitwardenPasswordSaved

    case ampBlockingRulesCompilationFailed

    case adClickAttributionDetected
    case adClickAttributionActive
    case adClickAttributionPageLoads

    case emailEnabled
    case emailDisabled
    case emailUserPressedUseAddress
    case emailUserPressedUseAlias
    case emailUserCreatedAlias

    case jsPixel(_ pixel: AutofillUserScript.JSPixel)

    // Activation Points
    case newTabInitial
    case emailEnabledInitial
    case watchInDuckPlayerInitial
    case setAsDefaultInitial
    case importDataInitial

    // New Tab section removed
    case favoriteSectionHidden
    case recentActivitySectionHidden
    case continueSetUpSectionHidden

    // Fire Button
    case fireButtonFirstBurn
    case fireButton(option: FireButtonOption)

    // Duck Player
    case duckPlayerDailyUniqueView
    case duckPlayerViewFromYoutubeViaMainOverlay
    case duckPlayerViewFromYoutubeViaHoverButton
    case duckPlayerViewFromYoutubeAutomatic
    case duckPlayerViewFromSERP
    case duckPlayerViewFromOther
    case duckPlayerSettingAlways
    case duckPlayerSettingNever
    case duckPlayerSettingBackToDefault

    // Dashboard
    case dashboardProtectionAllowlistAdd(triggerOrigin: String?)
    case dashboardProtectionAllowlistRemove(triggerOrigin: String?)

    // VPN
    case vpnBreakageReport(category: String, description: String, metadata: String)

    // VPN
    case networkProtectionWaitlistUserActive
    case networkProtectionWaitlistEntryPointMenuItemDisplayed
    case networkProtectionWaitlistEntryPointToolbarButtonDisplayed
    case networkProtectionWaitlistIntroDisplayed
    case networkProtectionWaitlistNotificationShown
    case networkProtectionWaitlistNotificationTapped
    case networkProtectionWaitlistTermsAndConditionsDisplayed
    case networkProtectionWaitlistTermsAndConditionsAccepted
    case networkProtectionRemoteMessageDisplayed(messageID: String)
    case networkProtectionRemoteMessageDismissed(messageID: String)
    case networkProtectionRemoteMessageOpened(messageID: String)
    case networkProtectionEnabledOnSearch
    case networkProtectionGeoswitchingOpened
    case networkProtectionGeoswitchingSetNearest
    case networkProtectionGeoswitchingSetCustom
    case networkProtectionGeoswitchingNoLocations

    // Sync
    case syncSignupDirect
    case syncSignupConnect
    case syncLogin
    case syncDaily
    case syncDuckAddressOverride
    case syncSuccessRateDaily
    case syncLocalTimestampResolutionTriggered(Feature)
    case syncBookmarksCountLimitExceededDaily
    case syncCredentialsCountLimitExceededDaily
    case syncBookmarksRequestSizeLimitExceededDaily
    case syncCredentialsRequestSizeLimitExceededDaily

    // DataBroker Protection Waitlist
    case dataBrokerProtectionWaitlistUserActive
    case dataBrokerProtectionWaitlistEntryPointMenuItemDisplayed
    case dataBrokerProtectionWaitlistIntroDisplayed
    case dataBrokerProtectionWaitlistNotificationShown
    case dataBrokerProtectionWaitlistNotificationTapped
    case dataBrokerProtectionWaitlistCardUITapped
    case dataBrokerProtectionWaitlistTermsAndConditionsDisplayed
    case dataBrokerProtectionWaitlistTermsAndConditionsAccepted
    case dataBrokerProtectionRemoteMessageDisplayed(messageID: String)
    case dataBrokerProtectionRemoteMessageDismissed(messageID: String)
    case dataBrokerProtectionRemoteMessageOpened(messageID: String)

    // Login Item events
    case dataBrokerEnableLoginItemDaily
    case dataBrokerDisableLoginItemDaily
    case dataBrokerResetLoginItemDaily
    case dataBrokerDisableAndDeleteDaily

    // DataBrokerProtection Other
    case dataBrokerProtectionErrorWhenFetchingSubscriptionAuthTokenAfterSignIn

    // Default Browser
    case defaultRequestedFromHomepage
    case defaultRequestedFromHomepageSetupView
    case defaultRequestedFromSettings
    case defaultRequestedFromOnboarding

    case protectionToggledOffBreakageReport
    case toggleProtectionsDailyCount
    case toggleReportDoNotSend
    case toggleReportDismiss

    // Password Import Keychain Prompt
    case passwordImportKeychainPrompt
    case passwordImportKeychainPromptDenied

    // MARK: - Debug

    case assertionFailure(message: String, file: StaticString, line: UInt)

    case dbMakeDatabaseError(error: Error?)
    case dbContainerInitializationError(error: Error)
    case dbInitializationError(error: Error)
    case dbSaveExcludedHTTPSDomainsError(error: Error?)
    case dbSaveBloomFilterError(error: Error?)

    case configurationFetchError(error: Error)

    case trackerDataParseFailed
    case trackerDataReloadFailed
    case trackerDataCouldNotBeLoaded

    case privacyConfigurationParseFailed
    case privacyConfigurationReloadFailed
    case privacyConfigurationCouldNotBeLoaded

    case fileStoreWriteFailed
    case fileMoveToDownloadsFailed
    case fileAccessRelatedItemFailed
    case fileGetDownloadLocationFailed
    case fileDownloadCreatePresentersFailed
    case downloadResumeDataCodingFailed

    case suggestionsFetchFailed
    case appOpenURLFailed
    case appStateRestorationFailed

    case contentBlockingErrorReportingIssue

    case contentBlockingCompilationFailed(listType: CompileRulesListType, component: ContentBlockerDebugEvents.Component)

    case contentBlockingCompilationTime

    case secureVaultInitError(error: Error)
    case secureVaultError(error: Error)

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
    case bitwardenRespondedCannotDecryptUnique // (repetition: Repetition = .init(key: "bitwardenRespondedCannotDecryptUnique")) // TODO: REIMPLEMENTATION??
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

    case faviconDecryptionFailedUnique
    case downloadListItemDecryptionFailedUnique
    case historyEntryDecryptionFailedUnique
    case permissionDecryptionFailedUnique

    // Errors from Bookmarks Module
    case missingParent
    case bookmarksSaveFailed
    case bookmarksSaveFailedOnImport

    case bookmarksCouldNotLoadDatabase(error: Error?)
    case bookmarksCouldNotPrepareDatabase
    case bookmarksMigrationAlreadyPerformed
    case bookmarksMigrationFailed
    case bookmarksMigrationCouldNotPrepareDatabase
    case bookmarksMigrationCouldNotPrepareDatabaseOnFailedMigration
    case bookmarksMigrationCouldNotRemoveOldStore
    case bookmarksMigrationCouldNotPrepareMultipleFavoriteFolders

    case syncSentUnauthenticatedRequest
    case syncMetadataCouldNotLoadDatabase
    case syncBookmarksProviderInitializationFailed
    case syncBookmarksFailed
    case syncCredentialsProviderInitializationFailed
    case syncCredentialsFailed
    case syncSettingsFailed
    case syncSettingsMetadataUpdateFailed
    case syncSignupError(error: Error)
    case syncLoginError(error: Error)
    case syncLogoutError(error: Error)
    case syncUpdateDeviceError(error: Error)
    case syncRemoveDeviceError(error: Error)
    case syncDeleteAccountError(error: Error)
    case syncLoginExistingAccountError(error: Error)
    case syncCannotCreateRecoveryPDF

    case bookmarksCleanupFailed
    case bookmarksCleanupAttemptedWhileSyncWasEnabled
    case favoritesCleanupFailed
    case bookmarksFaviconsFetcherStateStoreInitializationFailed
    case bookmarksFaviconsFetcherFailed

    case credentialsDatabaseCleanupFailed
    case credentialsCleanupAttemptedWhileSyncWasEnabled

    case invalidPayload(Configuration) // BSK>Configuration

    case burnerTabMisplaced

    case networkProtectionRemoteMessageFetchingFailed
    case networkProtectionRemoteMessageStorageFailed
    case dataBrokerProtectionRemoteMessageFetchingFailed
    case dataBrokerProtectionRemoteMessageStorageFailed

    case loginItemUpdateError(loginItemBundleID: String, action: String, buildType: String, osVersion: String)

    // Tracks installation without tracking retention.
    case installationAttribution

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

        case .dailyOsVersionCounter:
            return "m_mac_daily-os-version-counter"

        case .dataImportFailed(source: let source, sourceVersion: _, error: let error) where error.action == .favicons:
            return "m_mac_favicon-import-failed_\(source)"
        case .dataImportFailed(source: let source, sourceVersion: _, error: let error):
            return "m_mac_data-import-failed_\(error.action)_\(source)"

        case .formAutofilled(kind: let kind):
            return "m_mac_autofill_\(kind)"

        case .autofillItemSaved(kind: let kind):
            return "m_mac_save_\(kind)"

        case .autofillLoginsSaveLoginModalExcludeSiteConfirmed:
            return "m_mac_autofill_logins_save_login_exclude_site_confirmed"
        case .autofillLoginsSettingsResetExcludedDisplayed:
            return "m_mac_autofill_settings_reset_excluded_displayed"
        case .autofillLoginsSettingsResetExcludedConfirmed:
            return "m_mac_autofill_settings_reset_excluded_confirmed"
        case .autofillLoginsSettingsResetExcludedDismissed:
            return "m_mac_autofill_settings_reset_excluded_dismissed"

        case .bitwardenPasswordAutofilled:
            return "m_mac_bitwarden_autofill_password"

        case .bitwardenPasswordSaved:
            return "m_mac_bitwarden_save_password"

        case .ampBlockingRulesCompilationFailed:
            return "m_mac_amp_rules_compilation_failed"

        case .adClickAttributionDetected:
            return "m_mac_ad_click_detected"

        case .adClickAttributionActive:
            return "m_mac_ad_click_active"

        case .adClickAttributionPageLoads:
            return "m_mac_ad_click_page_loads"

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
        case .emailEnabledInitial:
            return "m_mac.enable-email-protection.initial"

        case .watchInDuckPlayerInitial:
            return "m_mac.watch-in-duckplayer.initial"
        case .setAsDefaultInitial:
            return "m_mac.set-as-default.initial"
        case .importDataInitial:
            return "m_mac.import-data.initial"
        case .newTabInitial:
            return "m_mac.new-tab-opened.initial"
        case .favoriteSectionHidden:
            return "m_mac.favorite-section-hidden"
        case .recentActivitySectionHidden:
            return "m_mac.recent-activity-section-hidden"
        case .continueSetUpSectionHidden:
            return "m_mac.continue-setup-section-hidden"

            // Fire Button
        case .fireButtonFirstBurn:
            return "m_mac_fire_button_first_burn"
        case .fireButton(option: let option):
            return "m_mac_fire_button_\(option)"

        case .duckPlayerDailyUniqueView:
            return "m_mac_duck-player_daily-unique-view"
        case .duckPlayerViewFromYoutubeViaMainOverlay:
            return "m_mac_duck-player_view-from_youtube_main-overlay"
        case .duckPlayerViewFromYoutubeViaHoverButton:
            return "m_mac_duck-player_view-from_youtube_hover-button"
        case .duckPlayerViewFromYoutubeAutomatic:
            return "m_mac_duck-player_view-from_youtube_automatic"
        case .duckPlayerViewFromSERP:
            return "m_mac_duck-player_view-from_serp"
        case .duckPlayerViewFromOther:
            return "m_mac_duck-player_view-from_other"
        case .duckPlayerSettingAlways:
            return "m_mac_duck-player_setting_always"
        case .duckPlayerSettingNever:
            return "m_mac_duck-player_setting_never"
        case .duckPlayerSettingBackToDefault:
            return "m_mac_duck-player_setting_back-to-default"

        case .dashboardProtectionAllowlistAdd:
            return "m_mac_mp_wla"
        case .dashboardProtectionAllowlistRemove:
            return "m_mac_mp_wlr"

        case .launchInitial:
            return "m.mac.first-launch"
        case .serpInitial:
            return "m.mac.navigation.first-search"
        case .serpDay21to27:
            return "m.mac.search-day-21-27.initial"

        case .vpnBreakageReport:
            return "m_mac_vpn_breakage_report"

        case .networkProtectionWaitlistUserActive:
            return "m_mac_netp_waitlist_user_active"
        case .networkProtectionWaitlistEntryPointMenuItemDisplayed:
            return "m_mac_netp_imp_settings_entry_menu_item"
        case .networkProtectionWaitlistEntryPointToolbarButtonDisplayed:
            return "m_mac_netp_imp_settings_entry_toolbar_button"
        case .networkProtectionWaitlistIntroDisplayed:
            return "m_mac_netp_imp_intro_screen"
        case .networkProtectionWaitlistNotificationShown:
            return "m_mac_netp_ev_waitlist_notification_shown"
        case .networkProtectionWaitlistNotificationTapped:
            return "m_mac_netp_ev_waitlist_notification_launched"
        case .networkProtectionWaitlistTermsAndConditionsDisplayed:
            return "m_mac_netp_imp_terms"
        case .networkProtectionWaitlistTermsAndConditionsAccepted:
            return "m_mac_netp_ev_terms_accepted"
        case .networkProtectionRemoteMessageDisplayed(let messageID):
            return "m_mac_netp_remote_message_displayed_\(messageID)"
        case .networkProtectionRemoteMessageDismissed(let messageID):
            return "m_mac_netp_remote_message_dismissed_\(messageID)"
        case .networkProtectionRemoteMessageOpened(let messageID):
            return "m_mac_netp_remote_message_opened_\(messageID)"
        case .networkProtectionEnabledOnSearch:
            return "m_mac_netp_ev_enabled_on_search"

            // Sync
        case .syncSignupDirect:
            return "m_mac_sync_signup_direct"
        case .syncSignupConnect:
            return "m_mac_sync_signup_connect"
        case .syncLogin:
            return "m_mac_sync_login"
        case .syncDaily:
            return "m_mac_sync_daily"
        case .syncDuckAddressOverride:
            return "m_mac_sync_duck_address_override"
        case .syncSuccessRateDaily:
            return "m_mac_sync_success_rate_daily"
        case .syncLocalTimestampResolutionTriggered(let feature):
            return "m_mac_sync_\(feature.name)_local_timestamp_resolution_triggered"
        case .syncBookmarksCountLimitExceededDaily: return "m_mac_sync_bookmarks_count_limit_exceeded_daily"
        case .syncCredentialsCountLimitExceededDaily: return "m_mac_sync_credentials_count_limit_exceeded_daily"
        case .syncBookmarksRequestSizeLimitExceededDaily: return "m_mac_sync_bookmarks_request_size_limit_exceeded_daily"
        case .syncCredentialsRequestSizeLimitExceededDaily: return "m_mac_sync_credentials_request_size_limit_exceeded_daily"

        case .dataBrokerProtectionWaitlistUserActive:
            return "m_mac_dbp_waitlist_user_active"
        case .dataBrokerProtectionWaitlistEntryPointMenuItemDisplayed:
            return "m_mac_dbp_imp_settings_entry_menu_item"
        case .dataBrokerProtectionWaitlistIntroDisplayed:
            return "m_mac_dbp_imp_intro_screen"
        case .dataBrokerProtectionWaitlistNotificationShown:
            return "m_mac_dbp_ev_waitlist_notification_shown"
        case .dataBrokerProtectionWaitlistNotificationTapped:
            return "m_mac_dbp_ev_waitlist_notification_launched"
        case .dataBrokerProtectionWaitlistCardUITapped:
            return "m_mac_dbp_ev_waitlist_card_ui_launched"
        case .dataBrokerProtectionWaitlistTermsAndConditionsDisplayed:
            return "m_mac_dbp_imp_terms"
        case .dataBrokerProtectionWaitlistTermsAndConditionsAccepted:
            return "m_mac_dbp_ev_terms_accepted"
        case .dataBrokerProtectionErrorWhenFetchingSubscriptionAuthTokenAfterSignIn:
            return "m_mac_dbp_error_when_fetching_subscription_auth_token_after_sign_in"
        case .dataBrokerProtectionRemoteMessageDisplayed(let messageID):
            return "m_mac_dbp_remote_message_displayed_\(messageID)"
        case .dataBrokerProtectionRemoteMessageDismissed(let messageID):
            return "m_mac_dbp_remote_message_dismissed_\(messageID)"
        case .dataBrokerProtectionRemoteMessageOpened(let messageID):
            return "m_mac_dbp_remote_message_opened_\(messageID)"

        case .dataBrokerEnableLoginItemDaily: return "m_mac_dbp_daily_login-item_enable"
        case .dataBrokerDisableLoginItemDaily: return "m_mac_dbp_daily_login-item_disable"
        case .dataBrokerResetLoginItemDaily: return "m_mac_dbp_daily_login-item_reset"
        case .dataBrokerDisableAndDeleteDaily: return "m_mac_dbp_daily_disable-and-delete"

        case .networkProtectionGeoswitchingOpened:
            return "m_mac_netp_imp_geoswitching_c"
        case .networkProtectionGeoswitchingSetNearest:
            return "m_mac_netp_ev_geoswitching_set_nearest"
        case .networkProtectionGeoswitchingSetCustom:
            return "m_mac_netp_ev_geoswitching_set_custom"
        case .networkProtectionGeoswitchingNoLocations:
            return "m_mac_netp_ev_geoswitching_no_locations"

        case .defaultRequestedFromHomepage: return "m_mac_default_requested_from_homepage"
        case .defaultRequestedFromHomepageSetupView: return "m_mac_default_requested_from_homepage_setup_view"
        case .defaultRequestedFromSettings: return "m_mac_default_requested_from_settings"
        case .defaultRequestedFromOnboarding: return "m_mac_default_requested_from_onboarding"

        case .protectionToggledOffBreakageReport: return "m_mac_protection-toggled-off-breakage-report"
        case .toggleProtectionsDailyCount: return "m_mac_toggle-protections-daily-count"
        case .toggleReportDoNotSend: return "m_mac_toggle-report-do-not-send"
        case .toggleReportDismiss: return "m_mac_toggle-report-dismiss"

            // Password Import Keychain Prompt
        case .passwordImportKeychainPrompt: return "m_mac_password_import_keychain_prompt"
        case .passwordImportKeychainPromptDenied: return "m_mac_password_import_keychain_prompt_denied"

            // DEBUG
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
        case .fileAccessRelatedItemFailed:
            return "dari"
        case .fileDownloadCreatePresentersFailed:
            return "dfpf"
        case .downloadResumeDataCodingFailed:
            return "drdc"

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

        case .faviconDecryptionFailedUnique:
            return "favicon_decryption_failed_unique"
        case .downloadListItemDecryptionFailedUnique:
            return "download_list_item_decryption_failed_unique"
        case .historyEntryDecryptionFailedUnique:
            return "history_entry_decryption_failed_unique"
        case .permissionDecryptionFailedUnique:
            return "permission_decryption_failed_unique"

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
        case .bookmarksMigrationCouldNotPrepareMultipleFavoriteFolders:
            return "bookmarks_migration_could_not_prepare_multiple_favorite_folders"

        case .syncSentUnauthenticatedRequest: return "sync_sent_unauthenticated_request"
        case .syncMetadataCouldNotLoadDatabase: return "sync_metadata_could_not_load_database"
        case .syncBookmarksProviderInitializationFailed: return "sync_bookmarks_provider_initialization_failed"
        case .syncBookmarksFailed: return "sync_bookmarks_failed"
        case .syncCredentialsProviderInitializationFailed: return "sync_credentials_provider_initialization_failed"
        case .syncCredentialsFailed: return "sync_credentials_failed"
        case .syncSettingsFailed: return "sync_settings_failed"
        case .syncSettingsMetadataUpdateFailed: return "sync_settings_metadata_update_failed"
        case .syncSignupError: return "sync_signup_error"
        case .syncLoginError: return "sync_login_error"
        case .syncLogoutError: return "sync_logout_error"
        case .syncUpdateDeviceError: return "sync_update_device_error"
        case .syncRemoveDeviceError: return "sync_remove_device_error"
        case .syncDeleteAccountError: return "sync_delete_account_error"
        case .syncLoginExistingAccountError: return "sync_login_existing_account_error"
        case .syncCannotCreateRecoveryPDF: return "sync_cannot_create_recovery_pdf"

        case .bookmarksCleanupFailed: return "bookmarks_cleanup_failed"
        case .bookmarksCleanupAttemptedWhileSyncWasEnabled: return "bookmarks_cleanup_attempted_while_sync_was_enabled"
        case .favoritesCleanupFailed: return "favorites_cleanup_failed"
        case .bookmarksFaviconsFetcherStateStoreInitializationFailed: return "bookmarks_favicons_fetcher_state_store_initialization_failed"
        case .bookmarksFaviconsFetcherFailed: return "bookmarks_favicons_fetcher_failed"

        case .credentialsDatabaseCleanupFailed: return "credentials_database_cleanup_failed"
        case .credentialsCleanupAttemptedWhileSyncWasEnabled: return "credentials_cleanup_attempted_while_sync_was_enabled"

        case .invalidPayload(let configuration): return "m_d_\(configuration.rawValue)_invalid_payload".lowercased()

        case .burnerTabMisplaced: return "burner_tab_misplaced"

        case .networkProtectionRemoteMessageFetchingFailed: return "netp_remote_message_fetching_failed"
        case .networkProtectionRemoteMessageStorageFailed: return "netp_remote_message_storage_failed"

        case .dataBrokerProtectionRemoteMessageFetchingFailed: return "dbp_remote_message_fetching_failed"
        case .dataBrokerProtectionRemoteMessageStorageFailed: return "dbp_remote_message_storage_failed"

        case .loginItemUpdateError: return "login-item_update-error"

            // Installation Attribution
        case .installationAttribution: return "m_mac_install"
        }
    }

    var error: (any Error)? {
        switch self {
        case .dbMakeDatabaseError(let error?),
                .dbContainerInitializationError(let error),
                .dbInitializationError(let error),
                .dbSaveExcludedHTTPSDomainsError(let error?),
                .dbSaveBloomFilterError(let error?),
                .configurationFetchError(let error),
                .secureVaultInitError(let error),
                .secureVaultError(let error),
                .syncSignupError(let error),
                .syncLoginError(let error),
                .syncLogoutError(let error),
                .syncUpdateDeviceError(let error),
                .syncRemoveDeviceError(let error),
                .syncDeleteAccountError(let error),
                .syncLoginExistingAccountError(let error),
                .bookmarksCouldNotLoadDatabase(let error?):
            return error
        default: return nil
        }
    }

    var parameters: [String: String]? {
        switch self {
        case .loginItemUpdateError(let loginItemBundleID, let action, let buildType, let osVersion):
            return ["loginItemBundleID": loginItemBundleID, "action": action, "buildType": buildType, "macosVersion": osVersion]

        case .dataImportFailed(source: _, sourceVersion: let version, error: let error):
            var params = error.pixelParameters

            if let version {
                params[PixelKit.Parameters.sourceBrowserVersion] = version
            }
            return params

        case .launchInitial(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]

        case .serpInitial(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]

        case .serpDay21to27(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]

        case .dailyOsVersionCounter:
            return [PixelKit.Parameters.osMajorVersion: "\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)"]

        case .dashboardProtectionAllowlistAdd(let triggerOrigin):
            guard let trigger = triggerOrigin else { return nil }
            return [PixelKit.Parameters.dashboardTriggerOrigin: trigger]

        case .dashboardProtectionAllowlistRemove(let triggerOrigin):
            guard let trigger = triggerOrigin else { return nil }
            return [PixelKit.Parameters.dashboardTriggerOrigin: trigger]

        case .syncSuccessRateDaily:
            return nil

        case .vpnBreakageReport(let category, let description, let metadata):
            return [
                PixelKit.Parameters.vpnBreakageCategory: category,
                PixelKit.Parameters.vpnBreakageDescription: description,
                PixelKit.Parameters.vpnBreakageMetadata: metadata
            ]
        default: return nil
        }
    }

    public enum CompileRulesListType: String, CustomStringConvertible {

        public var description: String { rawValue }

        case tds = "tracker_data"
        case clickToLoad = "click_to_load"
        case blockingAttribution = "blocking_attribution"
        case attributed = "attributed"
        case unknown = "unknown"

    }

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

    enum FormAutofillKind: String, CustomStringConvertible {
        var description: String { rawValue }

        case password
        case card
        case identity
    }

    enum FireButtonOption: String, CustomStringConvertible {
        var description: String { rawValue }

        case tab
        case window
        case allSites = "all-sites"
    }

    enum AccessPoint: String, CustomStringConvertible {
        var description: String { rawValue }

        case button = "source-button"
        case mainMenu = "source-menu"
        case tabMenu = "source-tab-menu"
        case hotKey = "source-keyboard"
        case moreMenu = "source-more-menu"
        case newTab = "source-new-tab"

        init(sender: Any, default: AccessPoint, mainMenuCheck: (NSMenu?) -> Bool = { $0 is MainMenu }) {
            switch sender {
            case let menuItem as NSMenuItem:
                if mainMenuCheck(menuItem.topMenu) {
                    if let event = NSApp.currentEvent,
                       case .keyDown = event.type,
                       event.characters == menuItem.keyEquivalent {

                        self = .hotKey
                    } else {
                        self = .mainMenu
                    }
                } else {
                    self = `default`
                }

            case is NSButton:
                self = .button

            default:
                self = `default`
            }
        }

    }
}
