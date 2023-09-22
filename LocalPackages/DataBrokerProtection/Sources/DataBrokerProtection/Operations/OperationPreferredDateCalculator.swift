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
                              schedulingConfig: DataBrokerScheduleConfig) -> Date? {

        var newDate: Date?
        guard let lastEvent = historyEvents.last else { return currentPreferredRunDate }

        switch lastEvent.type {

        case .noMatchFound:
            newDate = Date().addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds)
        case .matchesFound:
            newDate = Date().addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds)
        case .error:
            newDate = Date().addingTimeInterval(schedulingConfig.retryError.hoursToSeconds)
        case .optOutStarted:
            newDate = currentPreferredRunDate
        case .optOutRequested:
            newDate = Date().addingTimeInterval(schedulingConfig.confirmOptOutScan.hoursToSeconds)
        case .optOutConfirmed:
            newDate = Date().addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds)
        case .scanStarted:
            newDate = currentPreferredRunDate
        }

        return returnMostRecentDate(newDate, date2: currentPreferredRunDate)
    }

    func dateForOptOutOperation(currentPreferredRunDate: Date?,
                                historyEvents: [HistoryEvent],
                                extractedProfileID: Int64?,
                                schedulingConfig: DataBrokerScheduleConfig) -> Date? {

        var newDate: Date?

        guard let lastEvent = historyEvents.last else { return currentPreferredRunDate }

        switch lastEvent.type {

        case .noMatchFound:
            newDate = currentPreferredRunDate
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
        case .optOutStarted:
            newDate = currentPreferredRunDate
        case .optOutRequested:
            newDate = nil
        case .optOutConfirmed:
            newDate = nil
        case .scanStarted:
            newDate = currentPreferredRunDate
        }

        return returnMostRecentDate(newDate, date2: currentPreferredRunDate)
    }

    private func returnMostRecentDate(_ date1: Date?, date2: Date?) -> Date? {
        guard let date1 = date1 else { return date2 }
        guard let date2 = date2 else { return date1 }

        if date1 > date2 {
            return date2
        } else {
            return date1
        }
    }

    // If the last time we removed the profile has a bigger time difference than the current date + maintenance we should schedule for a new optout
    private func shouldScheduleNewOptOut(events: [HistoryEvent],
                                         extractedProfileId: Int64,
                                         schedulingConfig: DataBrokerScheduleConfig) -> Bool {
        guard let lastRemovalEvent = events.last(where: { $0.type == .optOutRequested && $0.extractedProfileId == extractedProfileId }) else {
            return false
        }

        return lastRemovalEvent.date.addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds) < Date()
    }
}
