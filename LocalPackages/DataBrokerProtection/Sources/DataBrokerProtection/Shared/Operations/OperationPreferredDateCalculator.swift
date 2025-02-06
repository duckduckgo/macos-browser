//
//  OperationPreferredDateCalculator.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

protocol DateProtocol {
    var now: Date { get }
}

struct SystemDate: DateProtocol {
    var now: Date {
        return Date()
    }
}

struct OperationPreferredDateCalculator {

    func dateForScanOperation(currentPreferredRunDate: Date?,
                              historyEvents: [HistoryEvent],
                              extractedProfileID: Int64?,
                              schedulingConfig: DataBrokerScheduleConfig,
                              isDeprecated: Bool = false) throws -> Date? {
        guard let lastEvent = historyEvents.last else {
            throw DataBrokerProtectionError.cantCalculatePreferredRunDate
        }

        switch lastEvent.type {
        case .optOutConfirmed:
            if isDeprecated {
                return nil
            } else {
                return Date().addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds)
            }
        case .noMatchFound, .matchesFound, .reAppearence:
            return Date().addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds)
        case .error:
            return Date().addingTimeInterval(schedulingConfig.retryError.hoursToSeconds)
        case .optOutStarted, .scanStarted:
            return currentPreferredRunDate
        case .optOutRequested:
            return Date().addingTimeInterval(schedulingConfig.confirmOptOutScan.hoursToSeconds)
        }
    }

    func dateForOptOutOperation(currentPreferredRunDate: Date?,
                                historyEvents: [HistoryEvent],
                                extractedProfileID: Int64?,
                                schedulingConfig: DataBrokerScheduleConfig,
                                attemptCount: Int64?,
                                date: DateProtocol = SystemDate()) throws -> Date? {
        guard let lastEvent = historyEvents.last else {
            throw DataBrokerProtectionError.cantCalculatePreferredRunDate
        }

        switch lastEvent.type {
        case .matchesFound, .reAppearence:
            if let extractedProfileID = extractedProfileID, shouldScheduleNewOptOut(events: historyEvents,
                                                                                    extractedProfileId: extractedProfileID,
                                                                                    schedulingConfig: schedulingConfig,
                                                                                    attemptCount: attemptCount) {
                return date.now
            } else {
                return currentPreferredRunDate
            }
        case .error:
            return date.now.addingTimeInterval(calculateNextRunDateOnError(schedulingConfig: schedulingConfig, historyEvents: historyEvents))
        case .optOutStarted, .scanStarted, .noMatchFound:
            return currentPreferredRunDate
        case .optOutConfirmed:
            return nil
        case .optOutRequested:
            // Previously, opt-out jobs with `nil` preferredRunDate were never executed,
            // but we need this following the child-to-parent-broker transition
            // to prevent repeated scheduling of those former child broker opt-out jobs.
            // https://app.asana.com/0/0/1208832818650310/f
            return date.now.addingTimeInterval(schedulingConfig.hoursUntilNextOptOutAttempt.hoursToSeconds)
        }
    }

    // If the time elapsed since the last profile removal exceeds the current date plus maintenance period (expired),
    // and the number of attempts is still fewer than the configurable limit,
    // we should proceed with scheduling a new opt-out request as the broker has failed to honor the previous one.
    private func shouldScheduleNewOptOut(events: [HistoryEvent],
                                         extractedProfileId: Int64,
                                         schedulingConfig: DataBrokerScheduleConfig,
                                         attemptCount: Int64?) -> Bool {
        let currentAttempt = attemptCount ?? 0
        if schedulingConfig.maxAttempts != -1, currentAttempt >= schedulingConfig.maxAttempts {
            return false
        }

        guard let lastRemovalEvent = events.last(where: { $0.type == .optOutRequested && $0.extractedProfileId == extractedProfileId }) else {
            return false
        }

        let lastRemovalEventDate = lastRemovalEvent.date.addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds)
        return lastRemovalEventDate < Date()
    }

    private func calculateNextRunDateOnError(schedulingConfig: DataBrokerScheduleConfig,
                                             historyEvents: [HistoryEvent]) -> TimeInterval {
        let pastTries = historyEvents.filter { $0.isError }.count
        let doubleValue = pow(2.0, Double(pastTries))

        if doubleValue > Double(schedulingConfig.retryError) {
            return schedulingConfig.retryError.hoursToSeconds
        } else {
            let intValue = Int(doubleValue)
            return intValue.hoursToSeconds
        }
    }
}
