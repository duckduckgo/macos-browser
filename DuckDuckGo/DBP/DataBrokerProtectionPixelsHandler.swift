//
//  DataBrokerProtectionPixelsHandler.swift
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

import Foundation
import DataBrokerProtection
import PixelKit
import Common

public class DataBrokerProtectionPixelsHandler: EventMapping<DataBrokerProtectionPixels> {

    public init() {
        super.init { event, _, _, _ in
            switch event {
            case .httpError(let error, _, _),
                    .actionFailedError(let error, _, _, _),
                    .otherError(let error, _):
                PixelKit.fire(DebugEvent(event, error: error), frequency: .dailyAndCount)
            case .databaseError(error: let error, functionOccurredIn: _),
                    .cocoaError(error: let error, functionOccurredIn: _),
                    .miscError(error: let error, functionOccurredIn: _):
                PixelKit.fire(DebugEvent(event, error: error), frequency: .dailyAndCount)
            case .secureVaultInitError(let error),
                    .secureVaultError(let error),
                    .secureVaultKeyStoreReadError(let error),
                    .secureVaultKeyStoreUpdateError(let error),
                    .errorLoadingCachedConfig(let error),
                    .failedToParsePrivacyConfig(let error):
                PixelKit.fire(DebugEvent(event, error: error))
            case .ipcServerProfileSavedXPCError(error: let error),
                    .ipcServerImmediateScansFinishedWithError(error: let error),
                    .ipcServerAppLaunchedXPCError(error: let error),
                    .ipcServerAppLaunchedScheduledScansFinishedWithError(error: let error):
                PixelKit.fire(DebugEvent(event, error: error), frequency: .legacyDailyAndCount, includeAppVersionParameter: true)
            case .ipcServerProfileSavedCalledByApp,
                    .ipcServerProfileSavedReceivedByAgent,
                    .ipcServerImmediateScansInterrupted,
                    .ipcServerImmediateScansFinishedWithoutError,
                    .ipcServerAppLaunchedCalledByApp,
                    .ipcServerAppLaunchedReceivedByAgent,
                    .ipcServerAppLaunchedScheduledScansBlocked,
                    .ipcServerAppLaunchedScheduledScansInterrupted,
                    .ipcServerAppLaunchedScheduledScansFinishedWithoutError:
                PixelKit.fire(event, frequency: .legacyDailyAndCount, includeAppVersionParameter: true)
            case .parentChildMatches,
                    .optOutStart,
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
                    .optOutFillForm,
                    .optOutSuccess,
                    .optOutFailure,
                    .backgroundAgentStarted,
                    .backgroundAgentStartedStoppingDueToAnotherInstanceRunning,
                    .scanSuccess,
                    .scanFailed,
                    .scanError,
                    .dataBrokerProtectionNotificationSentFirstScanComplete,
                    .dataBrokerProtectionNotificationOpenedFirstScanComplete,
                    .dataBrokerProtectionNotificationSentFirstRemoval,
                    .dataBrokerProtectionNotificationOpenedFirstRemoval,
                    .dataBrokerProtectionNotificationScheduled2WeeksCheckIn,
                    .dataBrokerProtectionNotificationOpened2WeeksCheckIn,
                    .dataBrokerProtectionNotificationSentAllRecordsRemoved,
                    .dataBrokerProtectionNotificationOpenedAllRecordsRemoved,
                    .dailyActiveUser,
                    .weeklyActiveUser,
                    .monthlyActiveUser,
                    .weeklyReportScanning,
                    .weeklyReportRemovals,
                    .optOutJobAt7DaysConfirmed,
                    .optOutJobAt7DaysUnconfirmed,
                    .optOutJobAt14DaysConfirmed,
                    .optOutJobAt14DaysUnconfirmed,
                    .optOutJobAt21DaysConfirmed,
                    .optOutJobAt21DaysUnconfirmed,
                    .scanningEventNewMatch,
                    .scanningEventReAppearance,
                    .webUILoadingFailed,
                    .webUILoadingStarted,
                    .webUILoadingSuccess,
                    .emptyAccessTokenDaily,
                    .generateEmailHTTPErrorDaily,
                    .initialScanTotalDuration,
                    .initialScanSiteLoadDuration,
                    .initialScanPostLoadingDuration,
                    .initialScanPreStartDuration,
                    .globalMetricsWeeklyStats,
                    .globalMetricsMonthlyStats,
                    .dataBrokerMetricsWeeklyStats,
                    .dataBrokerMetricsMonthlyStats,
                    .invalidPayload,
                    .customDataBrokerStatsOptoutSubmit,
                    .customGlobalStatsOptoutSubmit,
                    .weeklyChildBrokerOrphanedOptOuts:

                PixelKit.fire(event)

            case .homeViewShowNoPermissionError,
                    .homeViewShowWebUI,
                    .homeViewShowBadPathError,
                    .homeViewCTAMoveApplicationClicked,
                    .homeViewCTAGrantPermissionClicked,

                    .entitlementCheckValid,
                    .entitlementCheckInvalid,
                    .entitlementCheckError:
                PixelKit.fire(event, frequency: .legacyDailyAndCount)
            }
        }
    }

    override init(mapping: @escaping EventMapping<DataBrokerProtectionPixels>.Mapping) {
        fatalError("Use init()")
    }
}
