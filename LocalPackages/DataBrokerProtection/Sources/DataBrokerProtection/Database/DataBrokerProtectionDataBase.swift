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
    func brokerProfileQueryData(for profileQuery: ProfileQuery, dataBroker: DataBroker) -> BrokerProfileQueryData?
    func saveOperationData(_ data: BrokerOperationData)
    func scanOperationData(for profileQueryID: UUID) -> ScanOperationData
    func optOutOperationData(for profileQueryID: UUID) -> [OptOutOperationData]
    func fetchAllBrokerProfileQueryData() -> [BrokerProfileQueryData]
    func brokerProfileQueryData(for id: UUID) -> BrokerProfileQueryData?
}

final class DataBrokerProtectionDataBase: DataBase {

    func brokerProfileQueryData(for profileQuery: ProfileQuery, dataBroker: DataBroker) -> BrokerProfileQueryData? {
        return BrokerProfileQueryData(id: UUID(), profileQuery: profileQuery, dataBroker: dataBroker)
    }

    func brokerProfileQueryData(for id: UUID) -> BrokerProfileQueryData? {
        let dataBroker = DataBroker(name: "Test Broker",
                                    steps: [Step](),
                                    schedulingConfig: DataBrokerScheduleConfig(emailConfirmation: 10 * 60 * 60,
                                                                               retryError: 48 * 60 * 60,
                                                                               confirmOptOutScan: 72 * 60 * 60,
                                                                               maintenanceScan: 240 * 60 * 60))
        return BrokerProfileQueryData(id: UUID(),
                                      profileQuery: ProfileQuery(firstName: "John", lastName: "Deo", city: "Miami", state: "FL", age: 46),
                                      dataBroker: dataBroker)
    }

    func saveOperationData(_ data: BrokerOperationData) {

    }

    func scanOperationData(for profileQueryID: UUID) -> ScanOperationData {

        return ScanOperationData(brokerProfileQueryID: profileQueryID,
                                 preferredRunDate: Date(),
                                 historyEvents: [HistoryEvent]())
    }

    func optOutOperationData(for profileQueryID: UUID) -> [OptOutOperationData] {
        let extractedProfile = ExtractedProfile(name: "Duck")
        let data = OptOutOperationData(brokerProfileQueryID: profileQueryID,
                                       preferredRunDate: Date(),
                                       historyEvents: [HistoryEvent](),
                                       extractedProfile: extractedProfile)
        return [data]
    }

    func fetchAllBrokerProfileQueryData() -> [BrokerProfileQueryData] {
        let dataBroker = DataBroker(name: "Test Broker",
                                    steps: [Step](),
                                    schedulingConfig: DataBrokerScheduleConfig(emailConfirmation: 10 * 60 * 60,
                                                                               retryError: 48 * 60 * 60,
                                                                               confirmOptOutScan: 72 * 60 * 60,
                                                                               maintenanceScan: 240 * 60 * 60))

        let data = BrokerProfileQueryData(id: UUID(), profileQuery: ProfileQuery(firstName: "John", lastName: "Deo", city: "Miami", state: "FL", age: 46), dataBroker: dataBroker)

        return [data]
    }

}
