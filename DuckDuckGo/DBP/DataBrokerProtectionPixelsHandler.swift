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

    // swiftlint:disable:next function_body_length
    public init() {
        super.init { event, _, _, _ in
            switch event {
            case .error(let error, _):
                PixelKit.fire(DebugEvent(event, error: error))
            case .generalError(let error, _),
                    .secureVaultInitError(let error),
                    .secureVaultError(let error):
                PixelKit.fire(DebugEvent(event, error: error))
            case .ipcServerStartSchedulerXPCError(error: let error),
                    .ipcServerStopSchedulerXPCError(error: let error),
                    .ipcServerScanAllBrokersXPCError(error: let error),
                    .ipcServerScanAllBrokersCompletedOnAgentWithError(error: let error),
                    .ipcServerScanAllBrokersCompletionCalledOnAppWithError(error: let error),
                    .ipcServerOptOutAllBrokersCompletion(error: let error),
                    .ipcServerRunQueuedOperationsCompletion(error: let error):
                PixelKit.fire(DebugEvent(event, error: error), frequency: .dailyAndCount, includeAppVersionParameter: true)
            case .ipcServerStartSchedulerCalledByApp,
                    .ipcServerStartSchedulerReceivedByAgent,
                    .ipcServerStopSchedulerCalledByApp,
                    .ipcServerStopSchedulerReceivedByAgent,
                    .ipcServerScanAllBrokersAttemptedToCallWithoutLoginItemPermissions,
                    .ipcServerScanAllBrokersAttemptedToCallInWrongDirectory,
                    .ipcServerScanAllBrokersCalledByApp,
                    .ipcServerScanAllBrokersReceivedByAgent,
                    .ipcServerScanAllBrokersCompletedOnAgentWithoutError,
                    .ipcServerScanAllBrokersCompletionCalledOnAppWithoutError,
                    .ipcServerScanAllBrokersInterruptedOnAgent,
                    .ipcServerScanAllBrokersCompletionCalledOnAppAfterInterruption:
                PixelKit.fire(event, frequency: .dailyAndCount, includeAppVersionParameter: true)
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
                    .backgroundAgentRunOperationsAndStartSchedulerIfPossible,
                    .backgroundAgentRunOperationsAndStartSchedulerIfPossibleNoSavedProfile,
                    .backgroundAgentRunOperationsAndStartSchedulerIfPossibleRunQueuedOperationsCallbackStartScheduler,
                    .backgroundAgentStartedStoppingDueToAnotherInstanceRunning,
                    .ipcServerOptOutAllBrokers,
                    .ipcServerRunQueuedOperations,
                    .ipcServerRunAllOperations,
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
                    .initialScanPreStartDuration:
                PixelKit.fire(event)

            case .homeViewShowNoPermissionError,
                    .homeViewShowWebUI,
                    .homeViewShowBadPathError,
                    .homeViewCTAMoveApplicationClicked,
                    .homeViewCTAGrantPermissionClicked:
                PixelKit.fire(event, frequency: .dailyAndCount)
            }
        }
    }

    override init(mapping: @escaping EventMapping<DataBrokerProtectionPixels>.Mapping) {
        fatalError("Use init()")
    }
}
