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

extension Pixel {

    enum Parameters {
        static let duration = "duration"
        static let test = "test"
    #if BETA
        static let beta = "beta"
    #endif
        static let appVersion = "appVersion"

        static let errorCode = "e"
        static let errorDesc = "d"
        static let errorCount = "c"
        static let underlyingErrorCode = "ue"
        static let underlyingErrorDesc = "ud"
        static let underlyingErrorSQLiteCode = "sqlrc"
        static let underlyingErrorSQLiteExtendedCode = "sqlerc"
    }

    enum Values {
        static let test = "1"
    #if BETA
        static let beta = "1"
    #endif
    }

}

extension Pixel.Event {

    var parameters: [String: String]? {
        switch self {
        case .debug(event: _, error: let error):
            var params = [String: String]()

            if let error = error {
                let nsError = error as NSError

                params[Pixel.Parameters.errorCode] = "\(nsError.code)"
                params[Pixel.Parameters.errorDesc] = nsError.domain
                if let underlyingError = nsError.userInfo["NSUnderlyingError"] as? NSError {
                    params[Pixel.Parameters.underlyingErrorCode] = "\(underlyingError.code)"
                    params[Pixel.Parameters.underlyingErrorDesc] = underlyingError.domain
                }
                if let sqlErrorCode = nsError.userInfo["SQLiteResultCode"] as? NSNumber {
                    params[Pixel.Parameters.underlyingErrorSQLiteCode] = "\(sqlErrorCode.intValue)"
                }
                if let sqlExtendedErrorCode = nsError.userInfo["SQLiteExtendedResultCode"] as? NSNumber {
                    params[Pixel.Parameters.underlyingErrorSQLiteExtendedCode] = "\(sqlExtendedErrorCode.intValue)"
                }
            }

            return params

        // Don't use default to force new items to be thought about
        case .appLaunch,
             .launchTiming,
             .appUsage,
             .appActiveUsage,
             .browserMadeDefault,
             .burn,
             .crash,
             .brokenSiteReport,
             .compileRulesWait,
             .fireproof,
             .fireproofSuggested,
             .bookmark,
             .manageBookmarks,
             .bookmarksList,
             .manageLogins,
             .manageDownloads,
             .favorite,
             .navigation,
             .serp,
             .suggestionsDisplayed,
             .sharingMenu,
             .moreMenu,
             .refresh,
             .importedLogins,
             .exportedLogins,
             .importedBookmarks,
             .exportedBookmarks,
             .formAutofilled,
             .autofillItemSaved,
             .onboardingStartPressed,
             .onboardingImportPressed,
             .onboardingImportSkipped,
             .onboardingSetDefaultPressed,
             .onboardingSetDefaultSkipped,
             .onboardingTypingSkipped,
             .waitlistFirstLaunch,
             .waitlistMigratedExistingInstall,
             .waitlistPresentedLockScreen,
             .waitlistDismissedLockScreen,
             .autoconsentOptOutFailed,
             .autoconsentSelfTestFailed,
             .passwordManagerLockScreenDisabled,
             .passwordManagerLockScreenPreferencesButtonPressed,
             .passwordManagerLockScreenTimeoutSelected1Minute,
             .passwordManagerLockScreenTimeoutSelected5Minutes,
             .passwordManagerLockScreenTimeoutSelected15Minutes,
             .passwordManagerLockScreenTimeoutSelected30Minutes,
             .passwordManagerLockScreenTimeoutSelected1Hour:
            
            return nil
        }
    }

}
