//
//  OperationPreferredDateUpdater.swift
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
import Common

enum OperationPreferredDateUpdaterOrigin {
    case optOut
    case scan
}

protocol OperationPreferredDateUpdater {
    var database: DataBrokerProtectionRepository { get }

    func updateOperationDataDates(origin: OperationPreferredDateUpdaterOrigin,
                                  brokerId: Int64,
                                  profileQueryId: Int64,
                                  extractedProfileId: Int64?,
                                  schedulingConfig: DataBrokerScheduleConfig) throws

    func updateChildrenBrokerForParentBroker(_ parentBroker: DataBroker, profileQueryId: Int64)
}

struct OperationPreferredDateUpdaterUseCase: OperationPreferredDateUpdater {

    let database: DataBrokerProtectionRepository
    private let calculator = OperationPreferredDateCalculator()

    func updateOperationDataDates(origin: OperationPreferredDateUpdaterOrigin,
                                  brokerId: Int64,
                                  profileQueryId: Int64,
                                  extractedProfileId: Int64?,
                                  schedulingConfig: DataBrokerScheduleConfig) throws {

        guard let brokerProfileQuery = database.brokerProfileQueryData(for: brokerId,
                                                                       and: profileQueryId) else { return }

        try updateScanOperationDataDates(origin: origin,
                                         brokerId: brokerId,
                                         profileQueryId: profileQueryId,
                                         extractedProfileId: extractedProfileId,
                                         schedulingConfig: schedulingConfig,
                                         brokerProfileQuery: brokerProfileQuery)

        // We only need to update the optOut date if we have an extracted profile ID
        if let extractedProfileId = extractedProfileId {
            try updateOptOutOperationDataDates(origin: origin,
                                               brokerId: brokerId,
                                               profileQueryId: profileQueryId,
                                               extractedProfileId: extractedProfileId,
                                               schedulingConfig: schedulingConfig,
                                               brokerProfileQuery: brokerProfileQuery)
        }
    }

    /// 1, This method fetches scan operations with the profileQueryId and with child sites of parentBrokerId
    /// 2. Then for each one it updates the preferredRunDate of the scan to its confirm scan
    func updateChildrenBrokerForParentBroker(_ parentBroker: DataBroker, profileQueryId: Int64) {
        let childBrokers = database.fetchChildBrokers(for: parentBroker.name)

        childBrokers.forEach { childBroker in
            if let childBrokerId = childBroker.id {
                let confirmOptOutScanDate = Date().addingTimeInterval(childBroker.schedulingConfig.confirmOptOutScan.hoursToSeconds)
                database.updatePreferredRunDate(confirmOptOutScanDate,
                                                brokerId: childBrokerId,
                                                profileQueryId: profileQueryId)
            }
        }
    }

    private func updateScanOperationDataDates(origin: OperationPreferredDateUpdaterOrigin,
                                              brokerId: Int64,
                                              profileQueryId: Int64,
                                              extractedProfileId: Int64?,
                                              schedulingConfig: DataBrokerScheduleConfig,
                                              brokerProfileQuery: BrokerProfileQueryData) throws {

        let currentScanPreferredRunDate = brokerProfileQuery.scanOperationData.preferredRunDate

        var newScanPreferredRunDate = try calculator.dateForScanOperation(currentPreferredRunDate: currentScanPreferredRunDate,
                                                                          historyEvents: brokerProfileQuery.events,
                                                                          extractedProfileID: extractedProfileId,
                                                                          schedulingConfig: schedulingConfig,
                                                                          isDeprecated: brokerProfileQuery.profileQuery.deprecated)
        if let newDate = newScanPreferredRunDate, origin == .optOut {
            newScanPreferredRunDate = returnMostRecentDate(currentScanPreferredRunDate, newDate)
        }

        if newScanPreferredRunDate != currentScanPreferredRunDate {
            updatePreferredRunDate(newScanPreferredRunDate,
                                   brokerId: brokerId,
                                   profileQueryId: profileQueryId,
                                   extractedProfileId: nil)
        }
    }

    private func updateOptOutOperationDataDates(origin: OperationPreferredDateUpdaterOrigin,
                                                brokerId: Int64,
                                                profileQueryId: Int64,
                                                extractedProfileId: Int64?,
                                                schedulingConfig: DataBrokerScheduleConfig,
                                                brokerProfileQuery: BrokerProfileQueryData) throws {

        let optOutOperation = brokerProfileQuery.optOutOperationsData.filter { $0.extractedProfile.id == extractedProfileId }.first
        let currentOptOutPreferredRunDate = optOutOperation?.preferredRunDate

        var newOptOutPreferredDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: currentOptOutPreferredRunDate,
                                                                           historyEvents: brokerProfileQuery.events,
                                                                           extractedProfileID: extractedProfileId,
                                                                           schedulingConfig: schedulingConfig)

        if let newDate = newOptOutPreferredDate, origin == .scan {
            newOptOutPreferredDate = returnMostRecentDate(currentOptOutPreferredRunDate, newDate)
        }

        if newOptOutPreferredDate != currentOptOutPreferredRunDate {
            updatePreferredRunDate(newOptOutPreferredDate,
                                   brokerId: brokerId,
                                   profileQueryId: profileQueryId,
                                   extractedProfileId: extractedProfileId)
        }
    }

    private func returnMostRecentDate(_ date1: Date?, _ date2: Date?) -> Date? {
        guard let date1 = date1 else { return date2 }
        guard let date2 = date2 else { return date1 }

        return min(date1, date2)
    }

    private func updatePreferredRunDate( _ date: Date?,
                                         brokerId: Int64,
                                         profileQueryId: Int64,
                                         extractedProfileId: Int64?) {
        if let extractedProfileId = extractedProfileId {
            database.updatePreferredRunDate(date, brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId)
        } else {
            database.updatePreferredRunDate(date, brokerId: brokerId, profileQueryId: profileQueryId)
        }

        os_log("Updating preferredRunDate on operation with brokerId %{public}@ and profileQueryId %{public}@", log: .dataBrokerProtection, brokerId.description, profileQueryId.description)
    }
}
