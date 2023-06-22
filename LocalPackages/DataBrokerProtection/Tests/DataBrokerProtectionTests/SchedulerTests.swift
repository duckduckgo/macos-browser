//
//  SchedulerTests.swift
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

import XCTest
@testable import DataBrokerProtection

struct MockRunnerProvider: OperationRunnerProvider {
    let runner: WebOperationRunner

    func getOperationRunner() -> WebOperationRunner {
        runner
    }
}

final class SchedulerTests: XCTestCase {

    func testScheduler()  {
        let database = MockDataBase()

        let config = DataBrokerProtectionSchedulerConfig()


        let expectedExtractedProfiles = [ExtractedProfile]()
        let runner = MockRunner(optOutAction: nil,
                                scanAction: nil,
                                scanResults: expectedExtractedProfiles)

        let runnerProvider = MockRunnerProvider(runner: runner)
        let scheduler = DataBrokerProtectionScheduler(database: database,
                                                      config: config,
                                                      operationRunnerProvider: runnerProvider)
        let expectation = XCTestExpectation(description: "Open a file asynchronously.")

        scheduler.start()
        wait(for: [expectation], timeout: 10.0)
    }
}


private struct MockDataBase: DataBase {
    var brokerProfileQueryDataList: [BrokerProfileQueryData]
    var mockBrokerProfileQueryData: BrokerProfileQueryData?

    internal init(mockBrokerProfileQueryData: BrokerProfileQueryData? = nil) {
        self.mockBrokerProfileQueryData = mockBrokerProfileQueryData

        let commonScheduleConfig = DataBrokerScheduleConfig(
            emailConfirmation: 10 * 60 * 60,
            retryError: 48 * 60 * 60,
            confirmOptOutScan: 72 * 60 * 60,
            maintenanceScan: 240 * 60 * 60
        )

        let databroker1 = DataBroker(
            name: "batata",
            steps: [Step](),
            schedulingConfig: commonScheduleConfig
        )

        let databroker2 = DataBroker(
            name: "tomato",
            steps: [Step](),
            schedulingConfig: commonScheduleConfig
        )

        let brokerProfileQueryID1 = UUID()
        let optOutOperationData = OptOutOperationData(brokerProfileQueryID: brokerProfileQueryID1,
                                                      preferredRunDate: Date(),
                                                      historyEvents: [HistoryEvent](),
                                                      extractedProfile: ExtractedProfile(name: "John"))
        
        let data1 = BrokerProfileQueryData(
            id: brokerProfileQueryID1,
            profileQuery: ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 46),
            dataBroker: databroker1,
            optOutOperationsData: [optOutOperationData]
        )

        let data2 = BrokerProfileQueryData(
            id: UUID(),
            profileQuery: ProfileQuery(firstName: "Jane", lastName: "Smith", city: "New York", state: "NY", age: 32),
            dataBroker: databroker1
        )

        let data3 = BrokerProfileQueryData(
            id: UUID(),
            profileQuery: ProfileQuery(firstName: "Michael", lastName: "Johnson", city: "Los Angeles", state: "CA", age: 50),
            dataBroker: databroker2
        )

        let data4 = BrokerProfileQueryData(
            id: UUID(),
            profileQuery: ProfileQuery(firstName: "Emily", lastName: "Brown", city: "Chicago", state: "IL", age: 27),
            dataBroker: databroker2
        )

        let data5 = BrokerProfileQueryData(
            id: UUID(),
            profileQuery: ProfileQuery(firstName: "David", lastName: "Anderson", city: "Houston", state: "TX", age: 38),
            dataBroker: DataBroker(
                name: "onion",
                steps: [Step](),
                schedulingConfig: commonScheduleConfig
            )
        )

        brokerProfileQueryDataList = [data1, data2, data3, data4, data5]
    }


    func brokerProfileQueryData(for profileQuery: ProfileQuery, dataBroker: DataBroker) -> BrokerProfileQueryData? {
        if let data = mockBrokerProfileQueryData {
            return data
        }
        return BrokerProfileQueryData(id: UUID(), profileQuery: profileQuery, dataBroker: dataBroker)
    }

    func brokerProfileQueryData(for id: UUID) -> BrokerProfileQueryData? {
        brokerProfileQueryDataList.filter { $0.id == id }.first
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
        brokerProfileQueryDataList
    }

}
