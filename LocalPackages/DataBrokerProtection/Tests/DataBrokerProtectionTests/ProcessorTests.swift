//
//  ProcessorTests.swift
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

final class ProcessorTests: XCTestCase {

    func testScan() {
        let database = MockDataBase()

        let config = MockSchedulerConfig()

        let notificationCenter = NotificationCenter()
        let expectedExtractedProfiles = [ExtractedProfile]()
        let runner = MockRunner(optOutAction: nil,
                                scanAction: nil,
                                scanResults: expectedExtractedProfiles)

        let runnerProvider = MockRunnerProvider(runner: runner)
        let scheduler = DataBrokerProtectionProcessor(database: database,
                                                      config: config,
                                                      operationRunnerProvider: runnerProvider,
                                                      notificationCenter: notificationCenter)

        let expectation = XCTestExpectation(description: "All scans finished.")

        scheduler.runScanOnAllDataBrokers()

        var notificationCounter = 0
        let numberOfExpectedScanOperations = 5
        let expectedScanDate = Date().addingTimeInterval(database.commonScheduleConfig.maintenanceScan)

        let handler: (Notification) -> Bool = { notification in
            notificationCounter += 1

            if notificationCounter == numberOfExpectedScanOperations {
                database.brokerProfileQueryDataList.forEach {
                    XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: $0.scanData.preferredRunDate))
                }
                expectation.fulfill()

            }
            return true
        }

        let notification = XCTNSNotificationExpectation(name: DataBrokerNotifications.didFinishScan,
                                                        object: nil,
                                                        notificationCenter: notificationCenter)

        notification.handler = handler
        wait(for: [expectation], timeout: 15.0)
    }

    func testQueuedOperations() {

    }

}

struct MockSchedulerConfig: SchedulerConfig {
    var runFrequency: TimeInterval = 4 * 60 * 60
    var concurrentOperationsDifferentBrokers: Int = 2
    var intervalBetweenSameBrokerOperations: TimeInterval = 0.1
}

struct MockRunnerProvider: OperationRunnerProvider {
    let runner: WebOperationRunner

    func getOperationRunner() -> WebOperationRunner {
        runner
    }
}

private struct MockDataBase: DataBase {
    var brokerProfileQueryDataList: [BrokerProfileQueryData]
    var mockBrokerProfileQueryData: BrokerProfileQueryData?
    let commonScheduleConfig = DataBrokerScheduleConfig(
        emailConfirmation: 10 * 60 * 60,
        retryError: 48 * 60 * 60,
        confirmOptOutScan: 72 * 60 * 60,
        maintenanceScan: 240 * 60 * 60
    )

    internal init(mockBrokerProfileQueryData: BrokerProfileQueryData? = nil) {
        self.mockBrokerProfileQueryData = mockBrokerProfileQueryData

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
