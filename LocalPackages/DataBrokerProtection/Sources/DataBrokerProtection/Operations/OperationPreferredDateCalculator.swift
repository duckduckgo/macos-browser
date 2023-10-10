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

struct OperationPreferredDateCalculator {

    func dateForScanOperation(currentPreferredRunDate: Date?,
                              historyEvents: [HistoryEvent],
                              extractedProfileID: Int64?,
                              schedulingConfig: DataBrokerScheduleConfig,
                              isDeprecated: Bool = false) throws -> Date? {

        var newDate: Date?
        guard let lastEvent = historyEvents.last else {
            throw DataBrokerProtectionError.cantCalculatePreferredRunDate
        }

        switch lastEvent.type {

        case .optOutConfirmed:
            if isDeprecated {
                return nil
            } else {
                newDate = Date().addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds)
            }
        case .noMatchFound, .matchesFound:
            newDate = Date().addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds)
        case .error:
            newDate = Date().addingTimeInterval(schedulingConfig.retryError.hoursToSeconds)
        case .optOutStarted, .scanStarted:
            newDate = currentPreferredRunDate
        case .optOutRequested:
            newDate = Date().addingTimeInterval(schedulingConfig.confirmOptOutScan.hoursToSeconds)
        }

        return returnMostRecentDate(newDate, currentPreferredRunDate)
    }

    func dateForOptOutOperation(currentPreferredRunDate: Date?,
                                historyEvents: [HistoryEvent],
                                extractedProfileID: Int64?,
                                schedulingConfig: DataBrokerScheduleConfig) throws -> Date? {

        var newDate: Date?

        guard let lastEvent = historyEvents.last else {
            throw DataBrokerProtectionError.cantCalculatePreferredRunDate
        }

        switch lastEvent.type {

        case .matchesFound:
            if let extractedProfileID = extractedProfileID, shouldScheduleNewOptOut(events: historyEvents,
                                                                                    extractedProfileId: extractedProfileID,
                                                                                    schedulingConfig: schedulingConfig) {
                newDate = Date()
            } else {
                newDate = currentPreferredRunDate
            }
        case .error:
            newDate = Date().addingTimeInterval(schedulingConfig.retryError.hoursToSeconds)
        case .optOutStarted, .scanStarted, .noMatchFound:
            newDate = currentPreferredRunDate
        case .optOutConfirmed, .optOutRequested:
            newDate = nil
        }

        return returnMostRecentDate(newDate, currentPreferredRunDate)
    }

    private func returnMostRecentDate(_ date1: Date?, _ date2: Date?) -> Date? {
        guard let date1 = date1 else { return date2 }
        guard let date2 = date2 else { return date1 }

        return min(date1, date2)
    }

    // If the time elapsed since the last profile removal exceeds the current date plus maintenance period (expired), we should proceed with scheduling a new opt-out request as the broker has failed to honor the previous one.
    private func shouldScheduleNewOptOut(events: [HistoryEvent],
                                         extractedProfileId: Int64,
                                         schedulingConfig: DataBrokerScheduleConfig) -> Bool {
        guard let lastRemovalEvent = events.last(where: { $0.type == .optOutRequested && $0.extractedProfileId == extractedProfileId }) else {
            return false
        }

        return lastRemovalEvent.date.addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds) < Date()
    }
}
