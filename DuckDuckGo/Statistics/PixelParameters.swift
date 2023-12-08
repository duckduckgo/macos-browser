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

import PixelKit

extension Pixel.Event {

    var parameters: [String: String]? {
        switch self {
        case .pixelKitEvent(let event):
            return event.parameters

        case .debug(event: let debugEvent, error: let error):

            var params = error?.pixelParameters ?? [:]

            if case let .assertionFailure(message, file, line) = debugEvent {
                params[PixelKit.Parameters.assertionMessage] = message
                params[PixelKit.Parameters.assertionFile] = String(file)
                params[PixelKit.Parameters.assertionLine] = String(line)
            }

            return params

        case .dataImportFailed(let error):
            return error.pixelParameters

        case .launchInitial(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]
        case .serpInitial(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]
        case .serpDay21to27(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]
        case .setAsDefaultInitial(let cohort):
            guard let cohort else { return nil }
            return [PixelKit.Parameters.experimentCohort: cohort]
        case .newTabInitial(let cohort):
            guard let cohort else { return nil }
            return [PixelKit.Parameters.experimentCohort: cohort]
        case  .emailEnabledInitial(let cohort):
            guard let cohort else { return nil }
            return [PixelKit.Parameters.experimentCohort: cohort]
        case  .cookieManagementEnabledInitial(let cohort):
            guard let cohort else { return nil }
            return [PixelKit.Parameters.experimentCohort: cohort]
        case  .watchInDuckPlayerInitial(let cohort):
            guard let cohort else { return nil }
            return [PixelKit.Parameters.experimentCohort: cohort]
        case  .importDataInitial(let cohort):
            guard let cohort else { return nil }
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

        // Don't use default to force new items to be thought about
        case .crash,
             .brokenSiteReport,
             .compileRulesWait,
             .serp,
             .formAutofilled,
             .autofillItemSaved,
             .bitwardenPasswordAutofilled,
             .bitwardenPasswordSaved,
             .autoconsentOptOutFailed,
             .autoconsentSelfTestFailed,
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
             .syncSignupDirect,
             .syncSignupConnect,
             .syncLogin,
             .syncDaily,
             .syncDuckAddressOverride,
             .syncBookmarksLocalTimestampResolutionTriggered,
             .syncCredentialsLocalTimestampResolutionTriggered,
             .syncSettingsLocalTimestampResolutionTriggered,
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
             .homeButtonLeft,
             .homeButtonRight,
             .homeButtonHidden:
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
