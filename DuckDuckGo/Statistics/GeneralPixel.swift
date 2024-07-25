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

enum GeneralPixel: PixelKitEventV2 {

    case crash
    case crashOnCrashHandlersSetUp
    case compileRulesWait(onboardingShown: OnboardingShown, waitTime: CompileRulesWaitTime, result: WaitResult)
    case launchInitial(cohort: String)

    case serp(cohort: String?)
    case serpInitial(cohort: String)
    case serpDay21to27(cohort: String)

    case dailyOsVersionCounter

    case dataImportFailed(source: DataImport.Source, sourceVersion: String?, error: any DataImportError)

    case formAutofilled(kind: FormAutofillKind)
    case autofillItemSaved(kind: FormAutofillKind)

    case autofillLoginsSaveLoginInlineDisplayed
    case autofillLoginsSaveLoginInlineConfirmed
    case autofillLoginsSaveLoginInlineDismissed

    case autofillLoginsSavePasswordInlineDisplayed
    case autofillLoginsSavePasswordInlineConfirmed
    case autofillLoginsSavePasswordInlineDismissed

    case autofillLoginsSaveLoginModalExcludeSiteConfirmed
    case autofillLoginsSettingsResetExcludedDisplayed
    case autofillLoginsSettingsResetExcludedConfirmed
    case autofillLoginsSettingsResetExcludedDismissed

    case autofillLoginsUpdatePasswordInlineDisplayed
    case autofillLoginsUpdatePasswordInlineConfirmed
    case autofillLoginsUpdatePasswordInlineDismissed

    case autofillLoginsUpdateUsernameInlineDisplayed
    case autofillLoginsUpdateUsernameInlineConfirmed
    case autofillLoginsUpdateUsernameInlineDismissed

    case autofillActiveUser
    case autofillEnabledUser
    case autofillOnboardedUser
    case autofillToggledOn
    case autofillToggledOff
    case autofillLoginsStacked
    case autofillCreditCardsStacked
    case autofillIdentitiesStacked

    case autofillManagementOpened
    case autofillManagementCopyUsername
    case autofillManagementCopyPassword
    case autofillManagementDeleteLogin
    case autofillManagementDeleteAllLogins
    case autofillManagementSaveLogin
    case autofillManagementUpdateLogin

    case autofillLoginsSettingsEnabled
    case autofillLoginsSettingsDisabled

    case bitwardenPasswordAutofilled
    case bitwardenPasswordSaved

    case ampBlockingRulesCompilationFailed

    case adClickAttributionDetected
    case adClickAttributionActive
    case adClickAttributionPageLoads

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
    case duckPlayerOverlayYoutubeImpressions
    case duckPlayerOverlayYoutubeWatchHere
    case duckPlayerSettingAlwaysDuckPlayer
    case duckPlayerSettingAlwaysOverlaySERP
    case duckPlayerSettingAlwaysOverlayYoutube
    case duckPlayerSettingAlwaysSettings
    case duckPlayerSettingNeverOverlaySERP
    case duckPlayerSettingNeverOverlayYoutube
    case duckPlayerSettingNeverSettings
    case duckPlayerSettingBackToDefault
    case duckPlayerWatchOnYoutube
    case duckPlayerAutoplaySettingsOn
    case duckPlayerAutoplaySettingsOff
    case duckPlayerNewTabSettingsOn
    case duckPlayerNewTabSettingsOff

    // Dashboard
    case dashboardProtectionAllowlistAdd(triggerOrigin: String?)
    case dashboardProtectionAllowlistRemove(triggerOrigin: String?)

    // Survey
    case surveyRemoteMessageDisplayed(messageID: String)
    case surveyRemoteMessageDismissed(messageID: String)
    case surveyRemoteMessageOpened(messageID: String)

    // VPN
    case vpnBreakageReport(category: String, description: String, metadata: String)

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
    case syncBookmarksObjectLimitExceededDaily
    case syncCredentialsObjectLimitExceededDaily
    case syncBookmarksRequestSizeLimitExceededDaily
    case syncCredentialsRequestSizeLimitExceededDaily
    case syncBookmarksTooManyRequestsDaily
    case syncCredentialsTooManyRequestsDaily
    case syncSettingsTooManyRequestsDaily
    case syncBookmarksValidationErrorDaily
    case syncCredentialsValidationErrorDaily
    case syncSettingsValidationErrorDaily

    // Remote Messaging Framework
    case remoteMessageShown
    case remoteMessageShownUnique
    case remoteMessageDismissed
    case remoteMessageActionClicked
    case remoteMessagePrimaryActionClicked
    case remoteMessageSecondaryActionClicked

    // DataBroker Protection Waitlist
    case dataBrokerProtectionWaitlistUserActive
    case dataBrokerProtectionWaitlistEntryPointMenuItemDisplayed
    case dataBrokerProtectionWaitlistIntroDisplayed
    case dataBrokerProtectionWaitlistNotificationShown
    case dataBrokerProtectionWaitlistNotificationTapped
    case dataBrokerProtectionWaitlistCardUITapped
    case dataBrokerProtectionWaitlistTermsAndConditionsDisplayed
    case dataBrokerProtectionWaitlistTermsAndConditionsAccepted

    // Login Item events
    case dataBrokerEnableLoginItemDaily
    case dataBrokerDisableLoginItemDaily
    case dataBrokerResetLoginItemDaily
    case dataBrokerDisableAndDeleteDaily

    // Default Browser
    case defaultRequestedFromHomepage
    case defaultRequestedFromHomepageSetupView
    case defaultRequestedFromSettings
    case defaultRequestedFromOnboarding

    // Adding to the Dock
    case addToDockOnboardingStepPresented
    case userAddedToDockDuringOnboarding
    case userSkippedAddingToDockFromOnboarding
    case startBrowsingOnboardingStepPresented
    case addToDockNewTabPageCardPresented
    case userAddedToDockFromNewTabPageCard
    case userAddedToDockFromSettings
    case serpAddedToDock

    case protectionToggledOffBreakageReport

    // Password Import Keychain Prompt
    case passwordImportKeychainPrompt
    case passwordImportKeychainPromptDenied

    // Autocomplete
    case autocompleteClickPhrase
    case autocompleteClickWebsite
    case autocompleteClickBookmark
    case autocompleteClickFavorite
    case autocompleteClickHistory
    case autocompleteToggledOff
    case autocompleteToggledOn

    // Onboarding Experiment
    case onboardingCohortAssigned(cohort: String)
    case onboardingHomeButtonEnabled(cohort: String)
    case onboardingBookmarksBarShown(cohort: String)
    case onboardingSessionRestoreEnabled(cohort: String)
    case onboardingSetAsDefaultRequested(cohort: String)
    case onboardingAddToDockRequested(cohort: String)
    case onboardingImportRequested(cohort: String)
    case onboardingStepCompleteWelcome
    case onboardingStepCompleteGetStarted
    case onboardingStepCompletePrivateByDefault
    case onboardingStepCompleteCleanerBrowsing
    case onboardingStepCompleteSystemSettings
    case onboardingStepCompleteCustomize
    case onboardingExceptionReported(message: String, id: String)
    case onboardingSearchPerformed5to7(cohort: String)
    case onboardingHomeButtonUsed5to7(cohort: String)
    case onboardingBookmarkUsed5to7(cohort: String)
    case onboardingSessionRestoreEnabled5to7(cohort: String)
    case onboardingSetAsDefaultEnabled5to7(cohort: String)
    case onboardingDuckplayerUsed5to7(cohort: String)

    // MARK: - Debug

    case assertionFailure(message: String, file: StaticString, line: UInt)

    case dbMakeDatabaseError(error: Error?)
    case dbContainerInitializationError(error: Error)
    case dbInitializationError(error: Error)
    case dbSaveExcludedHTTPSDomainsError(error: Error?)
    case dbSaveBloomFilterError(error: Error?)

    case remoteMessagingSaveConfigError
    case remoteMessagingUpdateMessageShownError
    case remoteMessagingUpdateMessageStatusError

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
    case historySaveFailedDaily
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
    case updaterDidFindUpdate
    case updaterDidNotFindUpdate
    case updaterDidDownloadUpdate
    case updaterDidRunUpdate

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
    case syncBookmarksPatchCompressionFailed
    case syncCredentialsProviderInitializationFailed
    case syncCredentialsFailed
    case syncCredentialsPatchCompressionFailed
    case syncSettingsFailed
    case syncSettingsMetadataUpdateFailed
    case syncSettingsPatchCompressionFailed
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

    case surveyRemoteMessageFetchingFailed
    case surveyRemoteMessageStorageFailed
    case loginItemUpdateError(loginItemBundleID: String, action: String, buildType: String, osVersion: String)

    // Tracks installation without tracking retention.
    case installationAttribution

    case secureVaultKeystoreEventL1KeyMigration
    case secureVaultKeystoreEventL2KeyMigration
    case secureVaultKeystoreEventL2KeyPasswordMigration

    case compilationFailed

    var name: String {
        switch self {

        case .crash:
            return "m_mac_crash"

        case .crashOnCrashHandlersSetUp:
            return "m_mac_crash_on_handlers_setup"

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

        case .autofillLoginsSaveLoginInlineDisplayed:
            return "m_mac_autofill_logins_save_login_inline_displayed"
        case .autofillLoginsSaveLoginInlineConfirmed:
            return "m_mac_autofill_logins_save_login_inline_confirmed"
        case .autofillLoginsSaveLoginInlineDismissed:
            return "m_mac_autofill_logins_save_login_inline_dismissed"

        case .autofillLoginsSavePasswordInlineDisplayed:
            return "m_mac_autofill_logins_save_password_inline_displayed"
        case .autofillLoginsSavePasswordInlineConfirmed:
            return "m_mac_autofill_logins_save_password_inline_confirmed"
        case .autofillLoginsSavePasswordInlineDismissed:
            return "m_mac_autofill_logins_save_password_inline_dismissed"

        case .autofillLoginsSaveLoginModalExcludeSiteConfirmed:
            return "m_mac_autofill_logins_save_login_exclude_site_confirmed"
        case .autofillLoginsSettingsResetExcludedDisplayed:
            return "m_mac_autofill_settings_reset_excluded_displayed"
        case .autofillLoginsSettingsResetExcludedConfirmed:
            return "m_mac_autofill_settings_reset_excluded_confirmed"
        case .autofillLoginsSettingsResetExcludedDismissed:
            return "m_mac_autofill_settings_reset_excluded_dismissed"

        case .autofillLoginsUpdatePasswordInlineDisplayed:
            return "m_mac_autofill_logins_update_password_inline_displayed"
        case .autofillLoginsUpdatePasswordInlineConfirmed:
            return "m_mac_autofill_logins_update_password_inline_confirmed"
        case .autofillLoginsUpdatePasswordInlineDismissed:
            return "m_mac_autofill_logins_update_password_inline_dismissed"

        case .autofillLoginsUpdateUsernameInlineDisplayed:
            return "m_mac_autofill_logins_update_username_inline_displayed"
        case .autofillLoginsUpdateUsernameInlineConfirmed:
            return "m_mac_autofill_logins_update_username_inline_confirmed"
        case .autofillLoginsUpdateUsernameInlineDismissed:
            return "m_mac_autofill_logins_update_username_inline_dismissed"

        case .autofillActiveUser:
            return "m_mac_autofill_activeuser"
        case .autofillEnabledUser:
            return "m_mac_autofill_enableduser"
        case .autofillOnboardedUser:
            return "m_mac_autofill_onboardeduser"
        case .autofillToggledOn:
            return "m_mac_autofill_toggled_on"
        case .autofillToggledOff:
            return "m_mac_autofill_toggled_off"
        case .autofillLoginsStacked:
            return "m_mac_autofill_logins_stacked"
        case .autofillCreditCardsStacked:
            return "m_mac_autofill_creditcards_stacked"
        case .autofillIdentitiesStacked:
            return "m_mac_autofill_identities_stacked"

        case .autofillManagementOpened:
            return "m_mac_autofill_management_opened"
        case .autofillManagementCopyUsername:
            return "m_mac_autofill_management_copy_username"
        case .autofillManagementCopyPassword:
            return "m_mac_autofill_management_copy_password"
        case .autofillManagementDeleteLogin:
            return "m_mac_autofill_management_delete_login"
        case .autofillManagementDeleteAllLogins:
            return "m_mac_autofill_management_delete_all_logins"
        case .autofillManagementSaveLogin:
            return "m_mac_autofill_management_save_login"
        case .autofillManagementUpdateLogin:
            return "m_mac_autofill_management_update_login"

        case .autofillLoginsSettingsEnabled:
            return "m_mac_autofill_logins_settings_enabled"
        case .autofillLoginsSettingsDisabled:
            return "m_mac_autofill_logins_settings_disabled"

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

        case .jsPixel(let pixel):
            // Email pixels deliberately avoid using the `m_mac_` prefix.
            if pixel.isEmailPixel {
                return "\(pixel.pixelName)_macos_desktop"
            } else {
                return "m_mac_\(pixel.pixelName)"
            }
        case .emailEnabledInitial:
            return "m_mac_enable-email-protection_initial"

        case .watchInDuckPlayerInitial:
            return "m_mac_watch-in-duckplayer_initial"
        case .setAsDefaultInitial:
            return "m_mac_set-as-default_initial"
        case .importDataInitial:
            return "m_mac_import-data_initial"
        case .newTabInitial:
            return "m_mac_new-tab-opened_initial"
        case .favoriteSectionHidden:
            return "m_mac_favorite-section-hidden"
        case .recentActivitySectionHidden:
            return "m_mac_recent-activity-section-hidden"
        case .continueSetUpSectionHidden:
            return "m_mac_continue-setup-section-hidden"

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
        case .duckPlayerSettingAlwaysSettings:
            return "m_mac_duck-player_setting_always_settings"
        case .duckPlayerOverlayYoutubeImpressions:
            return "m_mac_duck-player_overlay_youtube_impressions"
        case .duckPlayerOverlayYoutubeWatchHere:
            return "m_mac_duck-player_overlay_youtube_watch_here"
        case .duckPlayerSettingAlwaysDuckPlayer:
            return "m_mac_duck-player_setting_always_duck-player"
        case .duckPlayerSettingAlwaysOverlaySERP:
            return "m_mac_duck-player_setting_always_overlay_serp"
        case .duckPlayerSettingAlwaysOverlayYoutube:
            return "m_mac_duck-player_setting_always_overlay_youtube"
        case .duckPlayerSettingNeverOverlaySERP:
            return "m_mac_duck-player_setting_never_overlay_serp"
        case .duckPlayerSettingNeverOverlayYoutube:
            return "m_mac_duck-player_setting_never_overlay_youtube"
        case .duckPlayerSettingNeverSettings:
            return "m_mac_duck-player_setting_never_settings"
        case .duckPlayerSettingBackToDefault:
            return "m_mac_duck-player_setting_back-to-default"
        case .duckPlayerWatchOnYoutube:
            return "m_mac_duck-player_watch_on_youtube"
        case .duckPlayerAutoplaySettingsOn:
            return "duckplayer_mac_autoplay_setting-on"
        case .duckPlayerAutoplaySettingsOff:
            return "duckplayer_mac_autoplay_setting-off"
        case .duckPlayerNewTabSettingsOn:
            return "duckplayer_mac_newtab_setting-on"
        case .duckPlayerNewTabSettingsOff:
            return "duckplayer_mac_newtab_setting-off"
        case .dashboardProtectionAllowlistAdd:
            return "m_mac_mp_wla"
        case .dashboardProtectionAllowlistRemove:
            return "m_mac_mp_wlr"

        case .launchInitial:
            return "m_mac_first-launch"
        case .serpInitial:
            return "m_mac_navigation_first-search"
        case .serpDay21to27:
            return "m_mac_search-day-21-27_initial"

        case .vpnBreakageReport:
            return "m_mac_vpn_breakage_report"

        case .surveyRemoteMessageDisplayed(let messageID):
            return "m_mac_survey_remote_message_displayed_\(messageID)"
        case .surveyRemoteMessageDismissed(let messageID):
            return "m_mac_survey_remote_message_dismissed_\(messageID)"
        case .surveyRemoteMessageOpened(let messageID):
            return "m_mac_survey_remote_message_opened_\(messageID)"
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
        case .syncBookmarksObjectLimitExceededDaily: return "m_mac_sync_bookmarks_object_limit_exceeded_daily"
        case .syncCredentialsObjectLimitExceededDaily: return "m_mac_sync_credentials_object_limit_exceeded_daily"
        case .syncBookmarksRequestSizeLimitExceededDaily: return "m_mac_sync_bookmarks_request_size_limit_exceeded_daily"
        case .syncCredentialsRequestSizeLimitExceededDaily: return "m_mac_sync_credentials_request_size_limit_exceeded_daily"
        case .syncBookmarksTooManyRequestsDaily: return "m_mac_sync_bookmarks_too_many_requests_daily"
        case .syncCredentialsTooManyRequestsDaily: return "m_mac_sync_credentials_too_many_requests_daily"
        case .syncSettingsTooManyRequestsDaily: return "m_mac_sync_settings_too_many_requests_daily"
        case .syncBookmarksValidationErrorDaily: return "m_mac_sync_bookmarks_validation_error_daily"
        case .syncCredentialsValidationErrorDaily: return "m_mac_sync_credentials_validation_error_daily"
        case .syncSettingsValidationErrorDaily: return "m_mac_sync_settings_validation_error_daily"

        case .remoteMessageShown: return "m_mac_remote_message_shown"
        case .remoteMessageShownUnique: return "m_mac_remote_message_shown_unique"
        case .remoteMessageDismissed: return "m_mac_remote_message_dismissed"
        case .remoteMessageActionClicked: return "m_mac_remote_message_action_clicked"
        case .remoteMessagePrimaryActionClicked: return "m_mac_remote_message_primary_action_clicked"
        case .remoteMessageSecondaryActionClicked: return "m_mac_remote_message_secondary_action_clicked"

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

        case .addToDockOnboardingStepPresented: return "m_mac_add_to_dock_onboarding_step_presented"
        case .userAddedToDockDuringOnboarding: return "m_mac_user_added_to_dock_during_onboarding"
        case .userSkippedAddingToDockFromOnboarding: return "m_mac_user_skipped_adding_to_dock_from_onboarding"
        case .startBrowsingOnboardingStepPresented: return "m_mac_start_browsing_onboarding_step_presented"
        case .addToDockNewTabPageCardPresented: return "m_mac_add_to_dock_new_tab_page_card_presented_u"
        case .userAddedToDockFromNewTabPageCard: return "m_mac_user_added_to_dock_from_new_tab_page_card"
        case .userAddedToDockFromSettings: return "m_mac_user_added_to_dock_from_settings"
        case .serpAddedToDock: return "m_mac_serp_added_to_dock"

        case .protectionToggledOffBreakageReport: return "m_mac_protection-toggled-off-breakage-report"

            // Password Import Keychain Prompt
        case .passwordImportKeychainPrompt: return "m_mac_password_import_keychain_prompt"
        case .passwordImportKeychainPromptDenied: return "m_mac_password_import_keychain_prompt_denied"

            // Autocomplete
        case .autocompleteClickPhrase: return "m_mac_autocomplete_click_phrase"
        case .autocompleteClickWebsite: return "m_mac_autocomplete_click_website"
        case .autocompleteClickBookmark: return "m_mac_autocomplete_click_bookmark"
        case .autocompleteClickFavorite: return "m_mac_autocomplete_click_favorite"
        case .autocompleteClickHistory: return "m_mac_autocomplete_click_history"
        case .autocompleteToggledOff: return "m_mac_autocomplete_toggled_off"
        case .autocompleteToggledOn: return "m_mac_autocomplete_toggled_on"

            // Onboarding experiment
        case .onboardingCohortAssigned: return "m_mac_onboarding_cohort-assigned"
        case .onboardingHomeButtonEnabled: return
            "m_mac_onboarding_home-button-enabled"
        case .onboardingBookmarksBarShown: return "m_mac_onboarding_bookmarks-bar-shown"
        case .onboardingSessionRestoreEnabled: return "m_mac_onboarding_session-restore-enabled"
        case .onboardingSetAsDefaultRequested: return "m_mac_onboarding_set-as-default-requested"
        case .onboardingAddToDockRequested: return "m_mac_onboarding_add-to-dock-requested"
        case .onboardingImportRequested: return "m_mac_onboarding_import-requested"
        case .onboardingStepCompleteWelcome: return "m_mac_onboarding_step-complete-welcome"
        case .onboardingStepCompleteGetStarted: return "m_mac_onboarding_step-complete-getStarted"
        case .onboardingStepCompletePrivateByDefault: return "m_mac_onboarding_step-complete-privateByDefault"
        case .onboardingStepCompleteCleanerBrowsing: return "m_mac_onboarding_step-complete-cleanerBrowsing"
        case .onboardingStepCompleteSystemSettings: return "m_mac_onboarding_step-complete-systemSettings"
        case .onboardingStepCompleteCustomize: return "m_mac_onboarding_step-complete-customize"
        case .onboardingExceptionReported: return "m_mac_onboarding_exception-reported"
        case .onboardingSearchPerformed5to7: return "m_mac_onboarding_search-performed-5-7"
        case .onboardingHomeButtonUsed5to7: return "m_mac_onboarding_home-button-used-5-7"
        case .onboardingBookmarkUsed5to7: return "m_mac_onboarding_bookmark-used-5-7"
        case .onboardingSessionRestoreEnabled5to7: return "m_mac_onboarding_session-restore-enabled-5-7"
        case .onboardingSetAsDefaultEnabled5to7: return "m_mac_onboarding_set-as-default-enabled-5-7"
        case .onboardingDuckplayerUsed5to7: return "m_mac_onboarding_duckplayer-used-5-7"

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

        case .remoteMessagingSaveConfigError:
            return "remote_messaging_save_config_error"
        case .remoteMessagingUpdateMessageShownError:
            return "remote_messaging_update_message_shown_error"
        case .remoteMessagingUpdateMessageStatusError:
            return "remote_messaging_update_message_status_error"

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
        case .historySaveFailedDaily:
            return "history_save_failed_daily"
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
            return "bitwarden_responded_cannot_decrypt_d"
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
        case .updaterDidFindUpdate:
            return "updater_did_find_update"
        case .updaterDidNotFindUpdate:
            return "updater_did_not_find_update"
        case .updaterDidDownloadUpdate:
            return "updater_did_download_update"
        case .updaterDidRunUpdate:
            return "updater_did_run_update"

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
        case .syncBookmarksPatchCompressionFailed: return "sync_bookmarks_patch_compression_failed"
        case .syncCredentialsProviderInitializationFailed: return "sync_credentials_provider_initialization_failed"
        case .syncCredentialsFailed: return "sync_credentials_failed"
        case .syncCredentialsPatchCompressionFailed: return "sync_credentials_patch_compression_failed"
        case .syncSettingsFailed: return "sync_settings_failed"
        case .syncSettingsMetadataUpdateFailed: return "sync_settings_metadata_update_failed"
        case .syncSettingsPatchCompressionFailed: return "sync_settings_patch_compression_failed"
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

        case .surveyRemoteMessageFetchingFailed: return "survey_remote_message_fetching_failed"
        case .surveyRemoteMessageStorageFailed: return "survey_remote_message_storage_failed"
        case .loginItemUpdateError: return "login-item_update-error"

            // Installation Attribution
        case .installationAttribution: return "m_mac_install"

        case .secureVaultKeystoreEventL1KeyMigration: return "m_mac_secure_vault_keystore_event_l1-key-migration"
        case .secureVaultKeystoreEventL2KeyMigration: return "m_mac_secure_vault_keystore_event_l2-key-migration"
        case .secureVaultKeystoreEventL2KeyPasswordMigration: return "m_mac_secure_vault_keystore_event_l2-key-password-migration"

        case .compilationFailed: return "compilation_failed"
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

        case .serp(let cohort):
            guard let cohort else { return [:] }
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

        case .onboardingCohortAssigned(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]
        case .onboardingHomeButtonEnabled(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]
        case .onboardingBookmarksBarShown(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]
        case .onboardingSessionRestoreEnabled(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]
        case .onboardingSetAsDefaultRequested(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]
        case .onboardingAddToDockRequested(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]
        case .onboardingImportRequested(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]
        case .onboardingExceptionReported(let message, let id):
            return [PixelKit.Parameters.assertionMessage: message, "id": id]
        case .onboardingSearchPerformed5to7(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]
        case .onboardingHomeButtonUsed5to7(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]
        case .onboardingBookmarkUsed5to7(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]
        case .onboardingSessionRestoreEnabled5to7(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]
        case .onboardingSetAsDefaultEnabled5to7(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]
        case .onboardingDuckplayerUsed5to7(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]

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
