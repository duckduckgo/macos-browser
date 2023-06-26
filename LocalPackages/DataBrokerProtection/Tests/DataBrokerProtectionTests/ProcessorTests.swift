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

        let expectedExtractedProfiles = [ExtractedProfile]()
        let runner = MockRunner(optOutAction: nil,
                                scanAction: nil,
                                scanResults: expectedExtractedProfiles)

        let runnerProvider = MockRunnerProvider(runner: runner)
        let scheduler = DataBrokerProtectionProcessor(database: database,
                                                      config: config,
                                                      operationRunnerProvider: runnerProvider)

        let expectation = XCTestExpectation(description: "All scans finished.")

        let expectedScanDate = Date().addingTimeInterval(database.commonScheduleConfig.maintenanceScan)

        scheduler.runScanOnAllDataBrokers {
            database.brokerProfileQueryDataList.forEach {
                XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: expectedScanDate, date2: $0.scanData.preferredRunDate))
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 15.0)
    }

    func testOptOutQueuedOperations() {
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

        let expectation = XCTestExpectation(description: "All opt out finished.")

        scheduler.runQueuedOperations()

        var notificationCounter = 0
        let expectedScanDate = Date().addingTimeInterval(database.commonScheduleConfig.confirmOptOutScan)

        let handler: (Notification) -> Bool = { notification in
            notificationCounter += 1

            let optOutDataRemovedFirst = database.brokerProfileQueryDataList.flatMap { $0.optOutsData }.filter { $0.extractedProfile.name == "ProfileToRemoveFirst"}.first!
            let optOutDataRemovedSecond = database.brokerProfileQueryDataList.flatMap { $0.optOutsData }.filter { $0.extractedProfile.name == "ProfileToRemoveSecond"}.first!

            let scanDataRemovedFirst = database.brokerProfileQueryDataList.compactMap { $0.scanData }.filter { $0.brokerProfileQueryID == optOutDataRemovedFirst.brokerProfileQueryID }.first!
            let scanDataRemovedSecond = database.brokerProfileQueryDataList.compactMap { $0.scanData }.filter { $0.brokerProfileQueryID == optOutDataRemovedSecond.brokerProfileQueryID }.first!


            if notificationCounter == 1  {
                XCTAssertTrue(optOutDataRemovedFirst.historyEvents.last?.type == .optOutRequested(extractedProfileID: optOutDataRemovedFirst.extractedProfile.id))

                XCTAssertNil(optOutDataRemovedSecond.historyEvents.last)

                // Check if the scan date for optOut request respect the preferredDate for the config
                XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: scanDataRemovedFirst.preferredRunDate, date2: expectedScanDate))
                XCTAssertFalse(areDatesEqualIgnoringSeconds(date1: scanDataRemovedSecond.preferredRunDate, date2: expectedScanDate))

            } else if notificationCounter == 2 {
                XCTAssertTrue(optOutDataRemovedFirst.historyEvents.last?.type == .optOutRequested(extractedProfileID: optOutDataRemovedFirst.extractedProfile.id))
                XCTAssertTrue(optOutDataRemovedSecond.historyEvents.last?.type == .optOutRequested(extractedProfileID: optOutDataRemovedSecond.extractedProfile.id))
                expectation.fulfill()

                // Check if the scan date for optOut request respect the preferredDate for the config
                XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: scanDataRemovedFirst.preferredRunDate, date2: expectedScanDate))
                XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: scanDataRemovedSecond.preferredRunDate, date2: expectedScanDate))
            }
            return true
        }

        let notification = XCTNSNotificationExpectation(name: DataBrokerNotifications.didFinishOptOut,
                                                        object: nil,
                                                        notificationCenter: notificationCenter)

        notification.handler = handler
        wait(for: [expectation], timeout: 15.0)
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
            name: "1",
            steps: [Step](),
            schedulingConfig: commonScheduleConfig
        )

        let databroker2 = DataBroker(
            name: "2",
            steps: [Step](),
            schedulingConfig: commonScheduleConfig
        )

        let brokerProfileQueryID1 = UUID()
        let optOutToRemoveSecond = OptOutOperationData(brokerProfileQueryID: brokerProfileQueryID1,
                                                      preferredRunDate: Date().addingTimeInterval(-100),
                                                      historyEvents: [HistoryEvent](),
                                                      extractedProfile: ExtractedProfile(name: "ProfileToRemoveSecond"))

        let brokerProfileQueryID2 = UUID()
        var extractedProfile = ExtractedProfile(name: "ProfileAlreadyRemoved")
        extractedProfile.removedDate = Date()

        let historyEvents: [HistoryEvent] = [.init(type: .optOutConfirmed(extractedProfileID: extractedProfile.id))]
        let removedOptOutOperationData = OptOutOperationData(brokerProfileQueryID: brokerProfileQueryID2,
                                                      preferredRunDate: Date(),
                                                      historyEvents: historyEvents,
                                                      extractedProfile: extractedProfile)


        let optOutToRemoveFirst = OptOutOperationData(brokerProfileQueryID: brokerProfileQueryID2,
                                                      preferredRunDate: Date().addingTimeInterval(-1000),
                                                      historyEvents: [HistoryEvent](),
                                                      extractedProfile: ExtractedProfile(name: "ProfileToRemoveFirst"))

        let data1 = BrokerProfileQueryData(
            id: brokerProfileQueryID1,
            profileQuery: ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 46),
            dataBroker: databroker1,
            optOutOperationsData: [optOutToRemoveSecond]
        )

        let data2 = BrokerProfileQueryData(
            id:brokerProfileQueryID2,
            profileQuery: ProfileQuery(firstName: "Jane", lastName: "Smith", city: "New York", state: "NY", age: 32),
            dataBroker: databroker1,
            optOutOperationsData: [removedOptOutOperationData, optOutToRemoveFirst]
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
