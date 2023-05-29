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

/*
 This is the profileQueryData
 It has a set of optOutOperationsData and a single scanOperationData
 */
class BrokerProfileQueryData {

    let id: UUID
    var extractedProfiles: [ExtractedProfile]
    let profileQuery: ProfileQuery
    let dataBroker: DataBroker

    let scanOperationData: BrokerOperationData
    let optOutOperationsDate: [BrokerOperationData]

    internal init(id: UUID,
                  extractedProfiles: [ExtractedProfile],
                  profileQuery: ProfileQuery,
                  dataBroker: DataBroker,
                  scanOperationData: BrokerOperationData,
                  optOutOperationsDate: [BrokerOperationData]) {

        self.id = id
        self.extractedProfiles = extractedProfiles
        self.profileQuery = profileQuery
        self.dataBroker = dataBroker
        self.scanOperationData = scanOperationData
        self.optOutOperationsDate = optOutOperationsDate
    }


    func updateExtractedProfiles(_ extractedProfiles: [ExtractedProfile]) {

    }
}

//TODO: Remove later
extension BrokerProfileQueryData {
    static func createTestScenario() -> BrokerProfileQueryData {
        // Create test data
        let id = UUID()
        let profileQuery = ProfileQuery(name: "Test Query")
        let dataBroker = DataBroker(name: "Test Broker")
        let scanOperationData = ScanOperationData(brokerProfileQueryID: id, preferredRunDate: Date(), historyEvents: [], lastRunDate: nil)
        let optOutOperationsDate: [OptOutOperationData] = []

        // Create extracted profiles for different scenarios
        let profile1 = ExtractedProfile(name: "John Doe")
        let profile2 = ExtractedProfile(name: "Jane Smith")
        let profile3 = ExtractedProfile(name: "Alice Johnson")

        // Create the BrokerProfileQueryData with different scenarios
        var brokerProfileQueryData = BrokerProfileQueryData(id: id,
                                                            extractedProfiles: [],
                                                            profileQuery: profileQuery,
                                                            dataBroker: dataBroker,
                                                            scanOperationData: scanOperationData,
                                                            optOutOperationsDate: optOutOperationsDate)

      //  brokerProfileQueryData.extractedProfiles = []

        brokerProfileQueryData.extractedProfiles = [profile1]

      //  brokerProfileQueryData.extractedProfiles = [profile1, profile2, profile3]

        return brokerProfileQueryData
    }
}
