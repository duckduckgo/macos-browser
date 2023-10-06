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
        case .debug(event: let debugEvent, error: let error):
            var params = [String: String]()

            if let errorWithUserInfo = error as? ErrorWithPixelParameters {
                params = errorWithUserInfo.errorParameters
            }

            if case let .assertionFailure(message, file, line) = debugEvent {
                params[PixelKit.Parameters.assertionMessage] = message
                params[PixelKit.Parameters.assertionFile] = String(file)
                params[PixelKit.Parameters.assertionLine] = String(line)
            }

            if let error = error {
                let nsError = error as NSError

                params[PixelKit.Parameters.errorCode] = "\(nsError.code)"
                params[PixelKit.Parameters.errorDesc] = nsError.domain

                if let underlyingError = nsError.userInfo["NSUnderlyingError"] as? NSError {
                    params[PixelKit.Parameters.underlyingErrorCode] = "\(underlyingError.code)"
                    params[PixelKit.Parameters.underlyingErrorDesc] = underlyingError.domain
                }

                if let sqlErrorCode = nsError.userInfo["SQLiteResultCode"] as? NSNumber {
                    params[PixelKit.Parameters.underlyingErrorSQLiteCode] = "\(sqlErrorCode.intValue)"
                }

                if let sqlExtendedErrorCode = nsError.userInfo["SQLiteExtendedResultCode"] as? NSNumber {
                    params[PixelKit.Parameters.underlyingErrorSQLiteExtendedCode] = "\(sqlExtendedErrorCode.intValue)"
                }
            }

            return params

        case .launchInitial(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]
        case .serpInitial(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]
        case .serpDay21to27(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort, "isDefault": DefaultBrowserPreferences().isDefault.description]
        case .setAsDefaultInitial(let cohort):
            return [PixelKit.Parameters.experimentCohort: cohort]

        case .dailyPixel(let pixel, isFirst: _):
            return pixel.parameters

        // Don't use default to force new items to be thought about
        case .crash,
             .brokenSiteReport,
             .compileRulesWait,
             .serp,
             .dataImportFailed,
             .faviconImportFailed,
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
             .emailEnabledInitial,
             .cookieManagementEnabledInitial,
             .watchInDuckPlayerInitial,
             .importDataInitial,
             .newTabInitial,
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
             .enableHomeButton,
             .disableHomeButton,
             .setnewHomePage:
            return nil
        }
    }

}
