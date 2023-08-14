//
//  OperationsTests.swift
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

final class OperationsTests: XCTestCase {

    private func brokerProfileQueryData(for profileQuery: ProfileQuery,
                                        dataBroker: DataBroker,
                                        database: DataBase) -> BrokerProfileQueryData {
        if let queryData = database.brokerProfileQueryData(for: profileQuery,
                                                           dataBroker: dataBroker) {
            return queryData
        } else {
            return BrokerProfileQueryData(id: UUID(),
                profileQuery: profileQuery,
                dataBroker: dataBroker)
        }
    }

    func testCleanScanOperationNoResults() async throws {
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 46)
        let dataBroker = DataBroker(name: "Test Broker",
            steps: [Step](),
            schedulingConfig: DataBrokerScheduleConfig(emailConfirmation: 10 * 60 * 60,
                retryError: 48 * 60 * 60,
                confirmOptOutScan: 72 * 60 * 60,
                maintenanceScan: 240 * 60 * 60))

        let database = MockDataBase()

        let brokerProfileQueryData = brokerProfileQueryData(for: profileQuery,
            dataBroker: dataBroker,
            database: database)

        let expectedExtractedProfiles = [ExtractedProfile]()

        let runner = MockRunner(optOutAction: nil,
            scanAction: nil,
            scanResults: expectedExtractedProfiles)

        try await DataBrokerProfileQueryOperationManager().runOperation(operationData: brokerProfileQueryData.scanData,
            brokerProfileQueryData: brokerProfileQueryData,
            database: database,
            runner: runner)
        let data = brokerProfileQueryData

        let expectedPreferredDate = Date().addingTimeInterval(dataBroker.schedulingConfig.maintenanceScan)

        let expectedHistoryTypes: [HistoryEvent.EventType] = [.scanStarted, .noMatchFound]

        let historyTypes = data.scanData.historyEvents.map { $0.type }

        XCTAssertEqual(expectedExtractedProfiles, data.extractedProfiles)
        XCTAssertEqual(data.scanData.historyEvents.count, expectedHistoryTypes.count)
        XCTAssertEqual(historyTypes, historyTypes)
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: data.scanData.preferredRunDate, date2: expectedPreferredDate))
    }

    func testCleanScanOperationWithResults() async throws {
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 46)
        let dataBroker = DataBroker(name: "Test Broker",
            steps: [Step](),
            schedulingConfig: DataBrokerScheduleConfig(emailConfirmation: 10 * 60 * 60,
                retryError: 48 * 60 * 60,
                confirmOptOutScan: 72 * 60 * 60,
                maintenanceScan: 240 * 60 * 60))
        let database = MockDataBase()

        let brokerProfileQueryData = brokerProfileQueryData(for: profileQuery,
            dataBroker: dataBroker,
            database: database)

        let expectedExtractedProfiles = [
            ExtractedProfile(name: "Profile1", profileUrl: "profile1"),
            ExtractedProfile(name: "Profile2", profileUrl: "profile2")
        ]

        var expectedEvents: [HistoryEvent.EventType] = [.scanStarted]

        expectedEvents.append(contentsOf: expectedExtractedProfiles.map { HistoryEvent(type: .matchFound(extractedProfileID: $0.id)).type })

        let runner = MockRunner(optOutAction: nil,
            scanAction: nil,
            scanResults: expectedExtractedProfiles)

        let expectedScanPreferredDate = Date().addingTimeInterval(dataBroker.schedulingConfig.maintenanceScan)
        let expectedOptOutPreferredDate = Date()

        try await DataBrokerProfileQueryOperationManager().runOperation(operationData: brokerProfileQueryData.scanData,
            brokerProfileQueryData: brokerProfileQueryData,
            database: database,
            runner: runner)

        let data = brokerProfileQueryData

        for optOutData in data.optOutsData {
            XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: optOutData.preferredRunDate, date2: expectedOptOutPreferredDate))
        }

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: data.scanData.preferredRunDate, date2: expectedScanPreferredDate))
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: data.scanData.lastRunDate, date2: Date()))
        XCTAssertEqual(expectedExtractedProfiles, data.extractedProfiles)
        XCTAssertEqual(data.scanData.historyEvents.count, expectedEvents.count)
        XCTAssertEqual(expectedEvents, data.scanData.historyEvents.map { $0.type })
    }

    func testCleanScanOperationWithError() async throws {
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 46)
        let dataBroker = DataBroker(name: "Test Broker",
            steps: [Step](),
            schedulingConfig: DataBrokerScheduleConfig(emailConfirmation: 10 * 60 * 60,
                retryError: 48 * 60 * 60,
                confirmOptOutScan: 72 * 60 * 60,
                maintenanceScan: 240 * 60 * 60))
        let database = MockDataBase()

        let brokerProfileQueryData = brokerProfileQueryData(for: profileQuery,
            dataBroker: dataBroker,
            database: database)

        let expectedExtractedProfiles = [ExtractedProfile]()
        let expectedHistoryTypes: [HistoryEvent.EventType] = [.scanStarted, .error]
        let expectedScanPreferredDate = Date().addingTimeInterval(dataBroker.schedulingConfig.retryError)

        let runner = MockRunner(optOutAction: nil,
            scanAction: { throw NSError(domain: "test", code: 123) },
            scanResults: expectedExtractedProfiles)

        do {
            try await DataBrokerProfileQueryOperationManager().runOperation(operationData: brokerProfileQueryData.scanData,
                brokerProfileQueryData: brokerProfileQueryData,
                database: database,
                runner: runner)
            XCTFail("Should not succeed")
        } catch {
            let data = brokerProfileQueryData
            XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: data.scanData.lastRunDate, date2: Date()))
            XCTAssertEqual(expectedExtractedProfiles, data.extractedProfiles)
            XCTAssertEqual(data.scanData.historyEvents.count, expectedHistoryTypes.count)
            XCTAssertEqual(data.scanData.historyEvents.map { $0.type }, expectedHistoryTypes)
            XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: data.scanData.preferredRunDate, date2: expectedScanPreferredDate))

        }
    }

    func testOptOutOperationWithSuccess() async throws {
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 46)
        let dataBroker = DataBroker(name: "Test Broker",
            steps: [Step](),
            schedulingConfig: DataBrokerScheduleConfig(emailConfirmation: 10 * 60 * 60,
                retryError: 48 * 60 * 60,
                confirmOptOutScan: 72 * 60 * 60,
                maintenanceScan: 240 * 60 * 60))
        let extractedProfile = ExtractedProfile(name: "John")

        let optOutOperationData = OptOutOperationData(brokerProfileQueryID: UUID(),
            preferredRunDate: Date(),
            historyEvents: [HistoryEvent](),
            extractedProfile: extractedProfile)

        let profileQueryData = BrokerProfileQueryData(id: UUID(),
            profileQuery: profileQuery,
            dataBroker: dataBroker,
            optOutOperationsData: [optOutOperationData])

        // Setting it nil to force the opt-out operation to set its own date on the scan once it finishes
        profileQueryData.scanData.preferredRunDate = nil

        let database = MockDataBase(mockBrokerProfileQueryData: profileQueryData)

        let brokerProfileQueryData = brokerProfileQueryData(for: profileQuery,
            dataBroker: dataBroker,
            database: database)

        let runner = MockRunner(optOutAction: nil,
            scanAction: nil,
            scanResults: [ExtractedProfile]())

        try await DataBrokerProfileQueryOperationManager().runOperation(operationData: optOutOperationData,
            brokerProfileQueryData: brokerProfileQueryData,
            database: database,
            runner: runner)

        let expectedScanPreferredDate = Date().addingTimeInterval(dataBroker.schedulingConfig.confirmOptOutScan)

        let optOutDataOperationData = profileQueryData.optOutsData.filter({ $0.id == optOutOperationData.id }).first

        let expectedHistoryTypes: [HistoryEvent.EventType] = [.optOutStarted(extractedProfileID: extractedProfile.id), .optOutRequested(extractedProfileID: extractedProfile.id)]

        XCTAssertNotNil(optOutDataOperationData)
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: optOutDataOperationData!.lastRunDate, date2: Date()))
        XCTAssertEqual(optOutDataOperationData?.historyEvents.count, expectedHistoryTypes.count)
        XCTAssertEqual(optOutDataOperationData?.historyEvents.map { $0.type }, expectedHistoryTypes)
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: profileQueryData.scanData.preferredRunDate, date2: expectedScanPreferredDate))
        XCTAssertNil(optOutOperationData.preferredRunDate)
    }

    func testOptOutOperationWithRunnerError() async throws {
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 46)
        let dataBroker = DataBroker(name: "Test Broker",
            steps: [Step](),
            schedulingConfig: DataBrokerScheduleConfig(emailConfirmation: 10 * 60 * 60,
                retryError: 48 * 60 * 60,
                confirmOptOutScan: 72 * 60 * 60,
                maintenanceScan: 240 * 60 * 60))
        let extractedProfile = ExtractedProfile(name: "John")

        let optOutOperationData = OptOutOperationData(brokerProfileQueryID: UUID(),
            preferredRunDate: Date(),
            historyEvents: [HistoryEvent](),
            extractedProfile: extractedProfile)

        let profileQueryData = BrokerProfileQueryData(id: UUID(),
            profileQuery: profileQuery,
            dataBroker: dataBroker,
            optOutOperationsData: [optOutOperationData])

        let database = MockDataBase(mockBrokerProfileQueryData: profileQueryData)

        let brokerProfileQueryData = brokerProfileQueryData(for: profileQuery,
            dataBroker: dataBroker,
            database: database)

        let runner = MockRunner(optOutAction: {
            throw NSError(domain: "test", code: 123)
        },
            scanAction: nil,
            scanResults: [ExtractedProfile]())

        try? await DataBrokerProfileQueryOperationManager().runOperation(operationData: optOutOperationData,
            brokerProfileQueryData: brokerProfileQueryData,
            database: database,
            runner: runner)

        let optOutDataOperationData = profileQueryData.optOutsData.filter({ $0.id == optOutOperationData.id }).first

        let expectedHistoryTypes: [HistoryEvent.EventType] = [.optOutStarted(extractedProfileID: extractedProfile.id), .error]

        let expectedOptOutPreferredDate = Date().addingTimeInterval(dataBroker.schedulingConfig.retryError)

        XCTAssertNotNil(optOutDataOperationData)
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: optOutDataOperationData!.lastRunDate, date2: Date()))
        XCTAssertEqual(optOutDataOperationData?.historyEvents.count, expectedHistoryTypes.count)
        XCTAssertEqual(optOutDataOperationData?.historyEvents.map { $0.type }, expectedHistoryTypes)
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: optOutDataOperationData?.preferredRunDate, date2: expectedOptOutPreferredDate))
    }

    func testOptOutConfirmationSuccess() async throws {
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 46)
        let dataBroker = DataBroker(name: "Test Broker",
            steps: [Step](),
            schedulingConfig: DataBrokerScheduleConfig(emailConfirmation: 10 * 60 * 60,
                retryError: 48 * 60 * 60,
                confirmOptOutScan: 72 * 60 * 60,
                maintenanceScan: 240 * 60 * 60))

        let extractedProfile = ExtractedProfile(name: "John")

        let optOutOperationData = OptOutOperationData(brokerProfileQueryID: UUID(),
            preferredRunDate: Date(),
            historyEvents: [HistoryEvent](),
            extractedProfile: extractedProfile)

        let profileQueryData = BrokerProfileQueryData(id: UUID(),
            profileQuery: profileQuery,
            dataBroker: dataBroker,
            optOutOperationsData: [optOutOperationData])

        let database = MockDataBase(mockBrokerProfileQueryData: profileQueryData)

        let brokerProfileQueryData = brokerProfileQueryData(for: profileQuery,
            dataBroker: dataBroker,
            database: database)

        let expectedExtractedProfiles = [extractedProfile]

        let runner = MockRunner(optOutAction: nil,
                                scanAction: nil,
                                scanResults: [ExtractedProfile]())

        try await DataBrokerProfileQueryOperationManager().runOperation(operationData: brokerProfileQueryData.scanData,
                                                                        brokerProfileQueryData: brokerProfileQueryData,
                                                                        database: database,
                                                                        runner: runner)

        let data = brokerProfileQueryData

        let scanExpectedHistoryTypes: [HistoryEvent.EventType] = [.scanStarted, .noMatchFound]
        let optOutExpectedHistoryTypes: [HistoryEvent.EventType] = [.optOutConfirmed(extractedProfileID: extractedProfile.id)]

        let expectedScanPreferredDate = Date().addingTimeInterval(dataBroker.schedulingConfig.maintenanceScan)

        XCTAssertNil(optOutOperationData.preferredRunDate)
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: data.scanData.preferredRunDate, date2: expectedScanPreferredDate))

        XCTAssertEqual(expectedExtractedProfiles, data.extractedProfiles)
        XCTAssertEqual(data.scanData.historyEvents.count, scanExpectedHistoryTypes.count)
        XCTAssertEqual(data.scanData.historyEvents.map { $0.type }, scanExpectedHistoryTypes)

        XCTAssertEqual(optOutOperationData.historyEvents.count, optOutExpectedHistoryTypes.count)
        XCTAssertEqual(optOutOperationData.historyEvents.map { $0.type }, optOutExpectedHistoryTypes)

        if let date = optOutOperationData.extractedProfile.removedDate {
            XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: date, date2: Date()))
        } else {
            XCTFail("No removed date one extracted profile")
        }
    }

    func testOptOutConfirmationNotRemoved() async throws {
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 46)
        let dataBroker = DataBroker(name: "Test Broker",
            steps: [Step](),
            schedulingConfig: DataBrokerScheduleConfig(emailConfirmation: 10 * 60 * 60,
                retryError: 48 * 60 * 60,
                confirmOptOutScan: 72 * 60 * 60,
                maintenanceScan: 240 * 60 * 60))

        let extractedProfile = ExtractedProfile(name: "John")

        let optOutOperationData = OptOutOperationData(brokerProfileQueryID: UUID(),
            preferredRunDate: Date(),
            historyEvents: [HistoryEvent](),
            extractedProfile: extractedProfile)

        let profileQueryData = BrokerProfileQueryData(id: UUID(),
            profileQuery: profileQuery,
            dataBroker: dataBroker,
            optOutOperationsData: [optOutOperationData])

        let database = MockDataBase(mockBrokerProfileQueryData: profileQueryData)

        let brokerProfileQueryData = brokerProfileQueryData(for: profileQuery,
            dataBroker: dataBroker,
            database: database)

        let expectedExtractedProfiles = [extractedProfile]

        let runner = MockRunner(optOutAction: nil,
            scanAction: nil,
            scanResults: [extractedProfile])

        try await DataBrokerProfileQueryOperationManager().runOperation(operationData: brokerProfileQueryData.scanData,
            brokerProfileQueryData: brokerProfileQueryData,
            database: database,
            runner: runner)
        let data = brokerProfileQueryData

        let scanExpectedHistoryTypes: [HistoryEvent.EventType] = [.scanStarted, .matchFound(extractedProfileID: extractedProfile.id)]

        let expectedOptOutPreferredDate = Date()
        let expectedScanPreferredDate = Date().addingTimeInterval(dataBroker.schedulingConfig.maintenanceScan)

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: optOutOperationData.preferredRunDate, date2: expectedOptOutPreferredDate))
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: data.scanData.preferredRunDate, date2: expectedScanPreferredDate))

        XCTAssertEqual(expectedExtractedProfiles, data.extractedProfiles)
        XCTAssertEqual(data.scanData.historyEvents.count, scanExpectedHistoryTypes.count)
        XCTAssertEqual(data.scanData.historyEvents.map { $0.type }, scanExpectedHistoryTypes)

        XCTAssertNil(optOutOperationData.extractedProfile.removedDate)
    }

    func testOptOutConfirmationRemovedOnSomeProfiles() async throws {
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 46)
        let dataBroker = DataBroker(name: "Test Broker",
            steps: [Step](),
            schedulingConfig: DataBrokerScheduleConfig(emailConfirmation: 10 * 60 * 60,
                retryError: 48 * 60 * 60,
                confirmOptOutScan: 72 * 60 * 60,
                maintenanceScan: 240 * 60 * 60))

        let extractedProfile1 = ExtractedProfile(name: "John")

        let optOutOperationData1 = OptOutOperationData(brokerProfileQueryID: UUID(),
            preferredRunDate: Date(),
            historyEvents: [HistoryEvent](),
            extractedProfile: extractedProfile1)

        let extractedProfile2 = ExtractedProfile(name: "John2")

        let optOutOperationData2 = OptOutOperationData(brokerProfileQueryID: UUID(),
            preferredRunDate: Date(),
            historyEvents: [HistoryEvent](),
            extractedProfile: extractedProfile2)

        let profileQueryData = BrokerProfileQueryData(id: UUID(),
            profileQuery: profileQuery,
            dataBroker: dataBroker,
            optOutOperationsData: [optOutOperationData1, optOutOperationData2])

        let database = MockDataBase(mockBrokerProfileQueryData: profileQueryData)

        let brokerProfileQueryData = brokerProfileQueryData(for: profileQuery,
            dataBroker: dataBroker,
            database: database)

        let expectedExtractedProfiles = [extractedProfile1]

        let runner = MockRunner(optOutAction: nil,
            scanAction: nil,
            scanResults: expectedExtractedProfiles)

        try await DataBrokerProfileQueryOperationManager().runOperation(operationData: brokerProfileQueryData.scanData,
            brokerProfileQueryData: brokerProfileQueryData,
            database: database,
            runner: runner)
        let data = brokerProfileQueryData

        let scanExpectedHistoryTypes: [HistoryEvent.EventType] = [.scanStarted, .matchFound(extractedProfileID: extractedProfile1.id)]
        let optOut1ExpectedHistoryTypes: [HistoryEvent.EventType] = []
        let optOut2ExpectedHistoryTypes: [HistoryEvent.EventType] = [.optOutConfirmed(extractedProfileID: extractedProfile2.id)]

        XCTAssertEqual(data.scanData.historyEvents.count, scanExpectedHistoryTypes.count)
        XCTAssertEqual(data.scanData.historyEvents.map { $0.type }, scanExpectedHistoryTypes)

        XCTAssertEqual(optOutOperationData1.historyEvents.count, optOut1ExpectedHistoryTypes.count)
        XCTAssertEqual(optOutOperationData1.historyEvents.map { $0.type }, optOut1ExpectedHistoryTypes)

        XCTAssertEqual(optOutOperationData2.historyEvents.count, optOut2ExpectedHistoryTypes.count)
        XCTAssertEqual(optOutOperationData2.historyEvents.map { $0.type }, optOut2ExpectedHistoryTypes)

        XCTAssertNil(optOutOperationData1.extractedProfile.removedDate)
        XCTAssertNotNil(optOutOperationData2.extractedProfile.removedDate)
    }
}

private struct MockDataBase: DataBase {
    var mockBrokerProfileQueryData: BrokerProfileQueryData?

    func brokerProfileQueryData(for profileQuery: ProfileQuery, dataBroker: DataBroker) -> BrokerProfileQueryData? {
        if let data = mockBrokerProfileQueryData {
            return data
        }
        return BrokerProfileQueryData(id: UUID(), profileQuery: profileQuery, dataBroker: dataBroker)
    }

    func brokerProfileQueryData(for id: UUID) -> BrokerProfileQueryData? {
        BrokerProfileQueryData(id: UUID(),
            profileQuery: ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 46),
            dataBroker: DataBroker(name: "batata",
                steps: [Step](),
                schedulingConfig: DataBrokerScheduleConfig(emailConfirmation: 10 * 60 * 60,
                    retryError: 48 * 60 * 60,
                    confirmOptOutScan: 72 * 60 * 60,
                    maintenanceScan: 240 * 60 * 60)))

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
        let data = BrokerProfileQueryData(id: UUID(),
            profileQuery: ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 46),
            dataBroker: DataBroker(name: "batata",
                steps: [Step](),
                schedulingConfig: DataBrokerScheduleConfig(emailConfirmation: 10 * 60 * 60,
                    retryError: 48 * 60 * 60,
                    confirmOptOutScan: 72 * 60 * 60,
                    maintenanceScan: 240 * 60 * 60)))
        return [data]
    }

}

struct MockRunner: WebOperationRunner {
    let optOutAction: (() throws -> Void)?
    let scanAction: (() throws -> Void)?
    let scanResults: [ExtractedProfile]

    func scan(_ profileQuery: BrokerProfileQueryData) async throws -> [ExtractedProfile] {
        try scanAction?()
        return scanResults
    }

    func optOut(profileQuery: DataBrokerProtection.BrokerProfileQueryData, extractedProfile: DataBrokerProtection.ExtractedProfile) async throws {
        try optOutAction?()
    }
}

extension HistoryEvent.EventType {
    public static func == (lhs: HistoryEvent.EventType, rhs: HistoryEvent.EventType) -> Bool {
        switch (lhs, rhs) {
        case (.noMatchFound, .noMatchFound):
            return true
        case let (.matchFound(extractedProfileID: lhsProfileID), .matchFound(extractedProfileID: rhsProfileID)):
            return lhsProfileID == rhsProfileID
        case (.error, .error):
            return true
        case let (.optOutRequested(extractedProfileID: lhsProfileID), .optOutRequested(extractedProfileID: rhsProfileID)):
            return lhsProfileID == rhsProfileID
        case let (.optOutConfirmed(extractedProfileID: lhsProfileID), .optOutConfirmed(extractedProfileID: rhsProfileID)):
            return lhsProfileID == rhsProfileID
        case let (.optOutStarted(extractedProfileID: lhsProfileID), .optOutStarted(extractedProfileID: rhsProfileID)):
            return lhsProfileID == rhsProfileID
        case (.scanStarted, .scanStarted):
            return true
        default:
            return false
        }
    }
}
