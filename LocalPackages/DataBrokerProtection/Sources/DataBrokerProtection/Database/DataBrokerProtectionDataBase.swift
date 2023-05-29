//
//  DataBrokerProtectionDataBase.swift
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

protocol DataBase {
    func saveOperationData(_ data: BrokerOperationData)
    func scanOperationData(for profileQueryID: UUID) -> ScanOperationData
    func optOutOperationData(for profileQueryID: UUID) -> [OptOutOperationData]
    func brokerProfileQueryData(for id: UUID) -> BrokerProfileQueryData
    func fetchAllBrokerProfileQueryData() -> [BrokerProfileQueryData]
}

class DataBrokerProtectionDataBase: DataBase {

    func brokerProfileQueryData(for id: UUID) -> BrokerProfileQueryData {
        return BrokerProfileQueryData.createTestScenario()
    }

    func saveOperationData(_ data: BrokerOperationData) {

    }

    func scanOperationData(for profileQueryID: UUID) -> ScanOperationData {
        let profileQuery = brokerProfileQueryData(for: profileQueryID)

        return ScanOperationData(brokerProfileQueryID: profileQueryID,
                                 preferredRunDate: Date(),
                                 historyEvents: [HistoryEvent]())
    }

    func optOutOperationData(for profileQueryID: UUID) -> [OptOutOperationData] {
        let profileQuery = brokerProfileQueryData(for: profileQueryID)
        let extractedProfile = ExtractedProfile(name: "Duck")
        let data = OptOutOperationData(brokerProfileQueryID: profileQueryID,
                                       preferredRunDate: Date(),
                                       historyEvents: [HistoryEvent](),
                                       brokerProfile: profileQuery,
                                       extractedProfile: extractedProfile)
        return [data]
    }

    func fetchAllBrokerProfileQueryData() -> [BrokerProfileQueryData] {
        let data = BrokerProfileQueryData.createTestScenario()

        return [data]
    }

}
