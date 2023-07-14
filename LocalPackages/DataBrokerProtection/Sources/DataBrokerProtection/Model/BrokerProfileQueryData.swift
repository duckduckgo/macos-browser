//
//  BrokerProfileQueryData.swift
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

final class BrokerProfileQueryData: Sendable {
    let id: UUID
    let dataBroker: DataBroker

    var profileQuery: ProfileQuery
    var scanData: ScanOperationData
    var optOutsData: [OptOutOperationData] = [OptOutOperationData]()
    var operationsData: [BrokerOperationData] {
        optOutsData + [scanData]
    }

    var extractedProfiles: [ExtractedProfile] {
        optOutsData.map { $0.extractedProfile }
    }

    init(id: UUID,
         profileQuery: ProfileQuery,
         dataBroker: DataBroker,
         scanOperationData: ScanOperationData? = nil,
         optOutOperationsData: [OptOutOperationData] = [OptOutOperationData]()) {
        self.id = id
        self.profileQuery = profileQuery
        self.dataBroker = dataBroker
        self.optOutsData = optOutOperationsData

        if let scanData = scanOperationData {
            self.scanData = scanData
        } else {
            self.scanData = ScanOperationData(brokerProfileQueryID: id,
                                              preferredRunDate: Date(),
                                              historyEvents: [HistoryEvent]())
        }
    }

    func updateExtractedProfiles(_ extractedProfiles: [ExtractedProfile]) {
        extractedProfiles.forEach { extractedProfile in
            // If the profile was already removed, we create a new one even if we find it again
            let isExistingProfile = optOutsData.contains {
                $0.extractedProfile.profileUrl == extractedProfile.profileUrl && $0.extractedProfile.removedDate == nil
            }

            if !isExistingProfile {
                os_log("Creating new opt-out operation data for: %@ %@", log: .dataBrokerProtection, String(describing: extractedProfile.name), extractedProfile.id.uuidString)

                let optOutOperationData = OptOutOperationData(brokerProfileQueryID: id,
                                                              historyEvents: [HistoryEvent](),
                                                              extractedProfile: extractedProfile)
                // If it's a new found profile, we'd like to opt-out ASAP
                optOutOperationData.preferredRunDate = Date()
                optOutsData.append(optOutOperationData)
            } else {
                os_log("Extracted profile already exists in database: %@ %@", log: .dataBrokerProtection, String(describing: extractedProfile.name), extractedProfile.id.uuidString)
            }
        }

        // Check for removed profiles
        let removedProfilesData = optOutsData.filter { !extractedProfiles.contains($0.extractedProfile) }
        for removedProfileData in removedProfilesData {
            let event = HistoryEvent(type: .optOutConfirmed(extractedProfileID: removedProfileData.extractedProfile.id))
            addHistoryEvent(event, for: removedProfileData)
            removedProfileData.extractedProfile.removedDate = Date()
            removedProfileData.preferredRunDate = nil
            os_log("Profile removed from optOutsData: %@", log: .dataBrokerProtection, String(describing: removedProfileData.extractedProfile))
        }
    }

    func addHistoryEvent(_ event: HistoryEvent, for operation: BrokerOperationData) {
        var op = operation
        op.addHistoryEvent(event)
    }
}
