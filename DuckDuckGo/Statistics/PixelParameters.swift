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

extension DuckDuckGo_Privacy_Browser.Pixel.Event {

    var parameters: [String: String]? {
        switch self {
        case .debug(event: let debugEvent, error: let error):

            var params = error?.pixelParameters ?? [:]

            if case let .assertionFailure(message, file, line) = debugEvent {
                params[PixelKit.Pixel.Parameters.assertionMessage] = message
                params[PixelKit.Pixel.Parameters.assertionFile] = String(file)
                params[PixelKit.Pixel.Parameters.assertionLine] = String(line)
            }

            return params

        case .dataImportFailed(let error):
            return error.pixelParameters

        case .launchInitial(let cohort):
            return [PixelKit.Pixel.Parameters.experimentCohort: cohort]
        case .serpInitial(let cohort):
            return [PixelKit.Pixel.Parameters.experimentCohort: cohort]
        case .serpDay21to27(let cohort):
            return [PixelKit.Pixel.Parameters.experimentCohort: cohort, "isDefault": DefaultBrowserPreferences().isDefault.description]
        case .setAsDefaultInitial(let cohort):
            return [PixelKit.Pixel.Parameters.experimentCohort: cohort]

        case .dailyPixel(let pixel, isFirst: _):
            return pixel.parameters

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
             .emailEnabledInitial,
             .cookieManagementEnabledInitial,
             .watchInDuckPlayerInitial,
             .importDataInitial,
             .newTabInitial,
             .networkProtectionSystemExtensionUnknownActivationResult,
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
             .enableHomeButton,
             .disableHomeButton,
             .setnewHomePage:
            return nil
#if DBP
        case .optOutStart,
            .optOutEmailGenerate,
            .optOutCaptchaParse,
            .optOutCaptchaSend,
            .optOutCaptchaSolve,
            .optOutSubmit,
            .optOutEmailReceive,
            .optOutEmailConfirm,
            .optOutValidate,
            .optOutFinish,
            .optOutSubmitSuccess,
            .optOutSuccess,
            .optOutFailure,
            .parentChildMatches:
          return nil
#endif
        }
    }

}
