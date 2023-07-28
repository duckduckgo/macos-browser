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
    func fetchAllBrokerProfileQueryData(useFakeBroker: Bool) -> [BrokerProfileQueryData]
    func brokerProfileQueryData(for id: UUID) -> BrokerProfileQueryData?
}

final class DataBrokerProtectionDataBase: DataBase {
    // Data in memory for tests
    public var dataBrokers = [DataBroker]()
    public var brokerProfileQueriesData = [BrokerProfileQueryData]()
    public var testProfileQuery: ProfileQuery?

    func brokerProfileQueryData(for profileQuery: ProfileQuery, dataBroker: DataBroker) -> BrokerProfileQueryData? {
        brokerProfileQueriesData.filter {
            $0.profileQuery.fullName == profileQuery.fullName
            && dataBroker.id == $0.dataBroker.id
        }.first
    }

    func brokerProfileQueryData(for id: UUID) -> BrokerProfileQueryData? {
        brokerProfileQueriesData.filter { $0.id == id }.first
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

    func fetchAllBrokerProfileQueryData(useFakeBroker: Bool) -> [BrokerProfileQueryData] {
        self.dataBrokers.removeAll()
        self.brokerProfileQueriesData.removeAll()

        var dataBroker: DataBroker

        if useFakeBroker {
            dataBroker = DataBroker.initFromResource("fake.verecor.com")
        } else {
            dataBroker = DataBroker.initFromResource("verecor.com")
        }

        let profileQuery = testProfileQuery!
        let queryData = BrokerProfileQueryData(id: UUID(), profileQuery: profileQuery, dataBroker: dataBroker)

        self.dataBrokers.append(dataBroker)
        self.brokerProfileQueriesData.append(queryData)

        return brokerProfileQueriesData
    }
}
