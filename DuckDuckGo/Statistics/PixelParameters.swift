//
//  PixelParameters.swift
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
import PixelKit

extension Pixel.Event {

    var parameters: [String: String]? {
        switch self {
        case .pixelKitEvent(let event):
            return event.parameters

        case .debug(event: let debugEvent, error: let error):
            var params = error?.pixelParameters ?? [:]

            if let debugParams = debugEvent.parameters {
                params.merge(debugParams) { (current, _) in current }
            }

            if case let .assertionFailure(message, file, line) = debugEvent {
                params[PixelKit.Parameters.assertionMessage] = message
                params[PixelKit.Parameters.assertionFile] = String(file)
                params[PixelKit.Parameters.assertionLine] = String(line)
            }

            return params

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

        case .dailyPixel(let pixel, isFirst: _):
            return pixel.parameters

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

        // Don't use default to force new items to be thought about
        case .crash,
             .brokenSiteReport,
             .compileRulesWait,
             .serp,
             .formAutofilled,
             .autofillItemSaved,
             .autofillLoginsSaveLoginModalExcludeSiteConfirmed,
             .autofillLoginsSettingsResetExcludedDisplayed,
             .autofillLoginsSettingsResetExcludedConfirmed,
             .autofillLoginsSettingsResetExcludedDismissed,
             .bitwardenPasswordAutofilled,
             .bitwardenPasswordSaved,
             .ampBlockingRulesCompilationFailed,
             .adClickAttributionDetected,
             .adClickAttributionActive,
             .adClickAttributionPageLoads,
             .emailEnabled,
             .emailDisabled,
             .emailUserCreatedAlias,
             .emailUserPressedUseAlias,
             .emailUserPressedUseAddress,
             .jsPixel,
             .emailEnabledInitial,
             .watchInDuckPlayerInitial,
             .importDataInitial,
             .newTabInitial,
             .setAsDefaultInitial,
             .favoriteSectionHidden,
             .recentActivitySectionHidden,
             .continueSetUpSectionHidden,
             .fireButtonFirstBurn,
             .fireButton,
             .duckPlayerDailyUniqueView,
             .duckPlayerViewFromYoutubeViaMainOverlay,
             .duckPlayerViewFromYoutubeViaHoverButton,
             .duckPlayerViewFromYoutubeAutomatic,
             .duckPlayerViewFromSERP,
             .duckPlayerViewFromOther,
             .duckPlayerSettingAlways,
             .duckPlayerSettingNever,
             .duckPlayerSettingBackToDefault,
             .networkProtectionWaitlistEntryPointMenuItemDisplayed,
             .networkProtectionWaitlistEntryPointToolbarButtonDisplayed,
             .networkProtectionWaitlistNotificationShown,
             .networkProtectionWaitlistNotificationTapped,
             .networkProtectionWaitlistTermsAndConditionsDisplayed,
             .networkProtectionWaitlistTermsAndConditionsAccepted,
             .networkProtectionWaitlistUserActive,
             .networkProtectionWaitlistIntroDisplayed,
             .networkProtectionRemoteMessageDisplayed,
             .networkProtectionRemoteMessageDismissed,
             .networkProtectionRemoteMessageOpened,
             .networkProtectionEnabledOnSearch,
             .networkProtectionGeoswitchingOpened,
             .networkProtectionGeoswitchingSetNearest,
             .networkProtectionGeoswitchingSetCustom,
             .networkProtectionGeoswitchingNoLocations,
             .syncSignupDirect,
             .syncSignupConnect,
             .syncLogin,
             .syncDaily,
             .syncDuckAddressOverride,
             .syncLocalTimestampResolutionTriggered,
             .syncBookmarksCountLimitExceededDaily,
             .syncCredentialsCountLimitExceededDaily,
             .syncBookmarksRequestSizeLimitExceededDaily,
             .syncCredentialsRequestSizeLimitExceededDaily,
             .dataBrokerProtectionWaitlistUserActive,
             .dataBrokerProtectionWaitlistEntryPointMenuItemDisplayed,
             .dataBrokerProtectionWaitlistIntroDisplayed,
             .dataBrokerProtectionWaitlistNotificationShown,
             .dataBrokerProtectionWaitlistNotificationTapped,
             .dataBrokerProtectionWaitlistCardUITapped,
             .dataBrokerProtectionWaitlistTermsAndConditionsDisplayed,
             .dataBrokerProtectionWaitlistTermsAndConditionsAccepted,
             .dataBrokerProtectionErrorWhenFetchingSubscriptionAuthTokenAfterSignIn,
             .dataBrokerProtectionRemoteMessageOpened,
             .dataBrokerProtectionRemoteMessageDisplayed,
             .dataBrokerProtectionRemoteMessageDismissed,
             .dataBrokerDisableAndDeleteDaily,
             .dataBrokerEnableLoginItemDaily,
             .dataBrokerDisableLoginItemDaily,
             .dataBrokerResetLoginItemDaily:
            return nil
        }
    }

}

extension Pixel.Event.Debug {

    var parameters: [String: String]? {
        switch self {
        case .loginItemUpdateError(let loginItemBundleID, let action, let buildType, let osVersion):
            return ["loginItemBundleID": loginItemBundleID, "action": action, "buildType": buildType, "macosVersion": osVersion]
        case .pixelKitEvent,
                .assertionFailure,
                .dbMakeDatabaseError,
                .dbContainerInitializationError,
                .dbInitializationError,
                .dbSaveExcludedHTTPSDomainsError,
                .dbSaveBloomFilterError,
                .configurationFetchError,
                .trackerDataParseFailed,
                .trackerDataReloadFailed,
                .trackerDataCouldNotBeLoaded,
                .privacyConfigurationParseFailed,
                .privacyConfigurationReloadFailed,
                .privacyConfigurationCouldNotBeLoaded,
                .fileStoreWriteFailed,
                .fileMoveToDownloadsFailed,
                .fileGetDownloadLocationFailed,
                .suggestionsFetchFailed,
                .appOpenURLFailed,
                .appStateRestorationFailed,
                .contentBlockingErrorReportingIssue,
                .contentBlockingCompilationFailed,
                .contentBlockingCompilationTime,
                .secureVaultInitError,
                .secureVaultError,
                .feedbackReportingFailed,
                .blankNavigationOnBurnFailed,
                .historyRemoveFailed,
                .historyReloadFailed,
                .historyCleanEntriesFailed,
                .historyCleanVisitsFailed,
                .historySaveFailed,
                .historyInsertVisitFailed,
                .historyRemoveVisitsFailed,
                .emailAutofillKeychainError,
                .bookmarksStoreRootFolderMigrationFailed,
                .bookmarksStoreFavoritesFolderMigrationFailed,
                .adAttributionCompilationFailedForAttributedRulesList,
                .adAttributionGlobalAttributedRulesDoNotExist,
                .adAttributionDetectionHeuristicsDidNotMatchDomain,
                .adAttributionLogicUnexpectedStateOnRulesCompiled,
                .adAttributionLogicUnexpectedStateOnInheritedAttribution,
                .adAttributionLogicUnexpectedStateOnRulesCompilationFailed,
                .adAttributionDetectionInvalidDomainInParameter,
                .adAttributionLogicRequestingAttributionTimedOut,
                .adAttributionLogicWrongVendorOnSuccessfulCompilation,
                .adAttributionLogicWrongVendorOnFailedCompilation,
                .webKitDidTerminate,
                .removedInvalidBookmarkManagedObjects,
                .bitwardenNotResponding,
                .bitwardenRespondedCannotDecryptUnique,
                .bitwardenHandshakeFailed,
                .bitwardenDecryptionOfSharedKeyFailed,
                .bitwardenStoringOfTheSharedKeyFailed,
                .bitwardenCredentialRetrievalFailed,
                .bitwardenCredentialCreationFailed,
                .bitwardenCredentialUpdateFailed,
                .bitwardenRespondedWithError,
                .bitwardenNoActiveVault,
                .bitwardenParsingFailed,
                .bitwardenStatusParsingFailed,
                .bitwardenHmacComparisonFailed,
                .bitwardenDecryptionFailed,
                .bitwardenSendingOfMessageFailed,
                .bitwardenSharedKeyInjectionFailed,
                .updaterAborted,
                .userSelectedToSkipUpdate,
                .userSelectedToInstallUpdate,
                .userSelectedToDismissUpdate,
                .faviconDecryptionFailedUnique,
                .downloadListItemDecryptionFailedUnique,
                .historyEntryDecryptionFailedUnique,
                .permissionDecryptionFailedUnique,
                .missingParent,
                .bookmarksSaveFailed,
                .bookmarksSaveFailedOnImport,
                .bookmarksCouldNotLoadDatabase,
                .bookmarksCouldNotPrepareDatabase,
                .bookmarksMigrationAlreadyPerformed,
                .bookmarksMigrationFailed,
                .bookmarksMigrationCouldNotPrepareDatabase,
                .bookmarksMigrationCouldNotPrepareDatabaseOnFailedMigration,
                .bookmarksMigrationCouldNotRemoveOldStore,
                .bookmarksMigrationCouldNotPrepareMultipleFavoriteFolders,
                .syncSentUnauthenticatedRequest,
                .syncMetadataCouldNotLoadDatabase,
                .syncBookmarksProviderInitializationFailed,
                .syncBookmarksFailed,
                .syncCredentialsProviderInitializationFailed,
                .syncCredentialsFailed,
                .syncSettingsFailed,
                .syncSettingsMetadataUpdateFailed,
                .syncSignupError,
                .syncLoginError,
                .syncLogoutError,
                .syncUpdateDeviceError,
                .syncRemoveDeviceError,
                .syncDeleteAccountError,
                .syncLoginExistingAccountError,
                .syncCannotCreateRecoveryPDF,
                .bookmarksCleanupFailed,
                .bookmarksCleanupAttemptedWhileSyncWasEnabled,
                .favoritesCleanupFailed,
                .bookmarksFaviconsFetcherStateStoreInitializationFailed,
                .bookmarksFaviconsFetcherFailed,
                .credentialsDatabaseCleanupFailed,
                .credentialsCleanupAttemptedWhileSyncWasEnabled,
                .invalidPayload,
                .burnerTabMisplaced,
                .networkProtectionRemoteMessageFetchingFailed,
                .networkProtectionRemoteMessageStorageFailed,
                .dataBrokerProtectionRemoteMessageFetchingFailed,
                .dataBrokerProtectionRemoteMessageStorageFailed:
            return nil
        }
    }

}

extension Error {

    var pixelParameters: [String: String] {
        var params = [String: String]()

        if let errorWithUserInfo = self as? ErrorWithPixelParameters {
            params = errorWithUserInfo.errorParameters
        }

        let nsError = self as NSError

        params[PixelKit.Parameters.errorCode] = "\(nsError.code)"
        params[PixelKit.Parameters.errorDesc] = nsError.domain

        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            params[PixelKit.Parameters.underlyingErrorCode] = "\(underlyingError.code)"
            params[PixelKit.Parameters.underlyingErrorDesc] = underlyingError.domain
        }

        if let sqlErrorCode = nsError.userInfo["SQLiteResultCode"] as? NSNumber {
            params[PixelKit.Parameters.underlyingErrorSQLiteCode] = "\(sqlErrorCode.intValue)"
        }

        if let sqlExtendedErrorCode = nsError.userInfo["SQLiteExtendedResultCode"] as? NSNumber {
            params[PixelKit.Parameters.underlyingErrorSQLiteExtendedCode] = "\(sqlExtendedErrorCode.intValue)"
        }

        return params
    }

}
