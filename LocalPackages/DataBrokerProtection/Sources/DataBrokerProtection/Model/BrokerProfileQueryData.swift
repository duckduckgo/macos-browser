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

class BrokerProfileQueryData {
    public let id: UUID
    public let profileQuery: ProfileQuery
    public let dataBroker: DataBroker

    public var scanData: ScanOperationData
    public var optOutsData: [OptOutOperationData] = [OptOutOperationData]()

    var extractedProfiles: [ExtractedProfile] {
        optOutsData.map { $0.extractedProfile }
    }

    internal init(id: UUID,
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
                $0.extractedProfile == extractedProfile && $0.extractedProfile.removedDate == nil
            }

            if !isExistingProfile {
                let optOutOperationData = OptOutOperationData(brokerProfileQueryID: id,
                                                              preferredRunDate: Date(),
                                                              historyEvents: [HistoryEvent](),
                                                              extractedProfile: extractedProfile)
                optOutsData.append(optOutOperationData)
            }
        }


        // Check for removed profiles
        let removedProfilesData = optOutsData.filter { !extractedProfiles.contains($0.extractedProfile) }
        for removedProfileData in removedProfilesData {
            let event = HistoryEvent(type: .optOutConfirmed(profileID: removedProfileData.extractedProfile.id))
            addHistoryEvent(event, for: removedProfileData)
            removedProfileData.extractedProfile.removedDate = Date()
            print("Profile removed from optOutsData: \(removedProfileData.extractedProfile)")

        }

    }


    func addHistoryEvent(_ event: HistoryEvent, for operation: BrokerOperationData) {
        var op = operation
        op.addHistoryEvent(event)
    }
}
