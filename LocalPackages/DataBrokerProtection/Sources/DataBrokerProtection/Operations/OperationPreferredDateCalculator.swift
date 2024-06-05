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
                                date: DateProtocol = SystemDate()) throws -> Date? {
        guard let lastEvent = historyEvents.last else {
            throw DataBrokerProtectionError.cantCalculatePreferredRunDate
        }

        switch lastEvent.type {
        case .matchesFound, .reAppearence:
            if let extractedProfileID = extractedProfileID, shouldScheduleNewOptOut(events: historyEvents,
                                                                                    extractedProfileId: extractedProfileID,
                                                                                    schedulingConfig: schedulingConfig) {
                return date.now
            } else {
                return currentPreferredRunDate
            }
        case .error:
            return date.now.addingTimeInterval(calculateNextRunDateOnError(schedulingConfig: schedulingConfig, historyEvents: historyEvents))
        case .optOutStarted, .scanStarted, .noMatchFound:
            return currentPreferredRunDate
        case .optOutConfirmed, .optOutRequested:
            return nil
        }
    }

    // If the time elapsed since the last profile removal exceeds the current date plus maintenance period (expired), we should proceed with scheduling a new opt-out request as the broker has failed to honor the previous one.
    private func shouldScheduleNewOptOut(events: [HistoryEvent],
                                         extractedProfileId: Int64,
                                         schedulingConfig: DataBrokerScheduleConfig) -> Bool {
        guard let lastRemovalEvent = events.last(where: { $0.type == .optOutRequested && $0.extractedProfileId == extractedProfileId }) else {
            return false
        }

        let lastRemovalEventDate = lastRemovalEvent.date.addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds)
        return lastRemovalEventDate < Date()
    }

    private func calculateNextRunDateOnError(schedulingConfig: DataBrokerScheduleConfig,
                                             historyEvents: [HistoryEvent]) -> TimeInterval {
        let pastTries = historyEvents.filter { $0.isError }.count
        return min(Int(pow(2.0, Double(pastTries))), schedulingConfig.retryError).hoursToSeconds
    }
}
