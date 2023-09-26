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

protocol OperationPreferredDateUpdater {
    var database: DataBrokerProtectionRepository { get }

    func updateOperationDataDates(brokerId: Int64,
                                  profileQueryId: Int64,
                                  extractedProfileId: Int64?,
                                  schedulingConfig: DataBrokerScheduleConfig) throws
}

struct OperationPreferredDateUpdaterUseCase: OperationPreferredDateUpdater {
    let database: DataBrokerProtectionRepository
    private let calculator = OperationPreferredDateCalculator()
    
    // It would probably be good to break this into 2 methods, for scan and opt-out
    func updateOperationDataDates(brokerId: Int64,
                                  profileQueryId: Int64,
                                  extractedProfileId: Int64?,
                                  schedulingConfig: DataBrokerScheduleConfig) throws {
        
        guard let brokerProfileQuery = database.brokerProfileQueryData(for: brokerId,
                                                                       and: profileQueryId) else { return }
        
        let currentScanPreferredRunDate = brokerProfileQuery.scanOperationData.preferredRunDate
        
        let newScanPreferredRunDate = try calculator.dateForScanOperation(currentPreferredRunDate: currentScanPreferredRunDate,
                                                                          historyEvents: brokerProfileQuery.events,
                                                                          extractedProfileID: extractedProfileId,
                                                                          schedulingConfig: schedulingConfig)
        
        if newScanPreferredRunDate != currentScanPreferredRunDate {
            updatePreferredRunDate(newScanPreferredRunDate,
                                   brokerId: brokerId,
                                   profileQueryId: profileQueryId,
                                   extractedProfileId: nil)
        }

        // We only need to update the optOut date if we have an extracted profile ID
        if let extractedProfileId = extractedProfileId {
            let optOutOperation = brokerProfileQuery.optOutOperationsData.filter { $0.extractedProfile.id == extractedProfileId }.first
            let currentOptOutPreferredRunDate = optOutOperation?.preferredRunDate

            let newOptOutPreferredDate = try calculator.dateForOptOutOperation(currentPreferredRunDate: currentOptOutPreferredRunDate,
                                                                               historyEvents: brokerProfileQuery.events,
                                                                               extractedProfileID: extractedProfileId,
                                                                               schedulingConfig: schedulingConfig)

            if newOptOutPreferredDate != currentOptOutPreferredRunDate {
                updatePreferredRunDate(newOptOutPreferredDate,
                                       brokerId: brokerId,
                                       profileQueryId: profileQueryId,
                                       extractedProfileId: extractedProfileId)
            }
        }
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
