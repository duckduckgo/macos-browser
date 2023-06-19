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
        let dataBroker = DataBroker(name: "Test Broker", steps: [Step]())

        let database = MockDataBase()

        let brokerProfileQueryData = brokerProfileQueryData(for: profileQuery,
                                                            dataBroker: dataBroker,
                                                            database: database)

        let operationsManager = BrokerProfileQueryOperationsManager(brokerProfileQueryData: brokerProfileQueryData,
                                                                    database: database)

        let expectedExtractedProfiles = [ExtractedProfile]()

        let runner = MockRunner(optOutAction: nil,
                                scanAction: nil,
                                scanResults: expectedExtractedProfiles)

        try await operationsManager.runScanOperation(on: runner)
        let data = operationsManager.brokerProfileQueryData

        let expectedHistoryTypes: [HistoryEvent.EventType] = [.scanStarted, .noMatchFound]

        let historyTypes = data.scanData.historyEvents.map { $0.type }

        XCTAssertEqual(expectedExtractedProfiles, data.extractedProfiles)
        XCTAssertEqual(data.scanData.historyEvents.count, expectedHistoryTypes.count)
        XCTAssertEqual(historyTypes, historyTypes)
    }

    func testCleanScanOperationWithResults() async throws {
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 46)
        let dataBroker = DataBroker(name: "Test Broker", steps: [Step]())
        let database = MockDataBase()

        let brokerProfileQueryData = brokerProfileQueryData(for: profileQuery,
                                                            dataBroker: dataBroker,
                                                            database: database)

        let operationsManager = BrokerProfileQueryOperationsManager(brokerProfileQueryData: brokerProfileQueryData,
                                                                    database: database)

        let expectedExtractedProfiles = [ExtractedProfile(name: "Profile1"),
                                         ExtractedProfile(name: "Profile2")]

        var expectedEvents: [HistoryEvent.EventType] = [.scanStarted]

        expectedEvents.append(contentsOf: expectedExtractedProfiles.map { HistoryEvent(type: .matchFound(profileID: $0.id)).type })

        let runner = MockRunner(optOutAction: nil,
                                scanAction: nil,
                                scanResults: expectedExtractedProfiles)

        try await operationsManager.runScanOperation(on: runner)
        let data = operationsManager.brokerProfileQueryData

        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: data.scanData.lastRunDate, date2: Date()))
        XCTAssertEqual(expectedExtractedProfiles, data.extractedProfiles)
        XCTAssertEqual(data.scanData.historyEvents.count, expectedEvents.count)
        XCTAssertEqual(expectedEvents, data.scanData.historyEvents.map { $0.type })
    }

    func testCleanScanOperationWithError() async throws {
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 46)
        let dataBroker = DataBroker(name: "Test Broker", steps: [Step]())
        let database = MockDataBase()

        let brokerProfileQueryData = brokerProfileQueryData(for: profileQuery,
                                                            dataBroker: dataBroker,
                                                            database: database)

        let operationsManager = BrokerProfileQueryOperationsManager(brokerProfileQueryData: brokerProfileQueryData,
                                                                    database: database)

        let expectedExtractedProfiles = [ExtractedProfile]()
        let expectedHistoryTypes: [HistoryEvent.EventType] = [.scanStarted, .error]

        let runner = MockRunner(optOutAction: nil,
                                scanAction: { throw NSError(domain: "test", code: 123) },
                                scanResults: expectedExtractedProfiles)

        do {
            try await operationsManager.runScanOperation(on: runner)
        } catch {
            let data = operationsManager.brokerProfileQueryData
            XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: data.scanData.lastRunDate, date2: Date()))
            XCTAssertEqual(expectedExtractedProfiles, data.extractedProfiles)
            XCTAssertEqual(data.scanData.historyEvents.count, expectedHistoryTypes.count)
            XCTAssertEqual(data.scanData.historyEvents.map { $0.type }, expectedHistoryTypes)
        }
    }

    func testOptOutOperationWithSuccess() async throws {
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 46)
        let dataBroker = DataBroker(name: "Test Broker", steps: [Step]())
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

        let operationsManager = BrokerProfileQueryOperationsManager(brokerProfileQueryData: brokerProfileQueryData,
                                                                    database: database)

        let runner = MockRunner(optOutAction: nil,
                                scanAction: nil,
                                scanResults: [ExtractedProfile]())

        try await operationsManager.runOptOutOperation(for: extractedProfile, on: runner)

        let optOutDataOperationData = profileQueryData.optOutsData.filter({ $0.id == optOutOperationData.id }).first

        let expectedHistoryTypes: [HistoryEvent.EventType] = [.optOutStarted(profileID: extractedProfile.id), .optOutRequested(profileID: extractedProfile.id)]

        XCTAssertNotNil(optOutDataOperationData)
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: optOutDataOperationData!.lastRunDate, date2: Date()))
        XCTAssertEqual(optOutDataOperationData?.historyEvents.count, expectedHistoryTypes.count)
        XCTAssertEqual(optOutDataOperationData?.historyEvents.map { $0.type }, expectedHistoryTypes)
    }

    func testOptOutOperationWithRunnerError() async throws {
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 46)
        let dataBroker = DataBroker(name: "Test Broker", steps: [Step]())
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

        let operationsManager = BrokerProfileQueryOperationsManager(brokerProfileQueryData: brokerProfileQueryData,
                                                                    database: database)

        let runner = MockRunner(optOutAction: {
            throw NSError(domain: "test", code: 123)
        },
                                scanAction: nil,
                                scanResults: [ExtractedProfile]())

        try? await operationsManager.runOptOutOperation(for: extractedProfile, on: runner)

        let optOutDataOperationData = profileQueryData.optOutsData.filter({ $0.id == optOutOperationData.id }).first

        let expectedHistoryTypes: [HistoryEvent.EventType] = [.optOutStarted(profileID: extractedProfile.id), .error]

        XCTAssertNotNil(optOutDataOperationData)
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: optOutDataOperationData!.lastRunDate, date2: Date()))
        XCTAssertEqual(optOutDataOperationData?.historyEvents.count, expectedHistoryTypes.count)
        XCTAssertEqual(optOutDataOperationData?.historyEvents.map { $0.type }, expectedHistoryTypes)
    }

    func testOptOutOperationWithoutOptOutDataError() async throws {
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 46)
        let dataBroker = DataBroker(name: "Test Broker", steps: [Step]())
        let extractedProfile = ExtractedProfile(name: "John")

        let database = MockDataBase()

        let brokerProfileQueryData = brokerProfileQueryData(for: profileQuery,
                                                            dataBroker: dataBroker,
                                                            database: database)

        let operationsManager = BrokerProfileQueryOperationsManager(brokerProfileQueryData: brokerProfileQueryData,
                                                                    database: database)

        let runner = MockRunner(optOutAction: nil,
                                scanAction: nil,
                                scanResults: [ExtractedProfile]())

        do {
            try await operationsManager.runOptOutOperation(for: extractedProfile, on: runner)
            XCTFail("Operation should throw")
        } catch {
            XCTAssertEqual(OperationsError.noOperationDataForExtractedProfile, error as! OperationsError)
        }
    }

    func testOptOutConfirmationSuccess() async throws {
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 46)
        let dataBroker = DataBroker(name: "Test Broker", steps: [Step]())

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

        let operationsManager = BrokerProfileQueryOperationsManager(brokerProfileQueryData: brokerProfileQueryData,
                                                                    database: database)

        let expectedExtractedProfiles = [extractedProfile]

        let runner = MockRunner(optOutAction: nil,
                                scanAction: nil,
                                scanResults: [ExtractedProfile]())

        try await operationsManager.runScanOperation(on: runner)
        let data = operationsManager.brokerProfileQueryData

        let scanExpectedHistoryTypes: [HistoryEvent.EventType] = [.scanStarted, .noMatchFound]
        let optOutExpectedHistoryTypes: [HistoryEvent.EventType] = [.optOutConfirmed(profileID: extractedProfile.id)]

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
        let dataBroker = DataBroker(name: "Test Broker", steps: [Step]())

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

        let operationsManager = BrokerProfileQueryOperationsManager(brokerProfileQueryData: brokerProfileQueryData,
                                                                    database: database)

        let expectedExtractedProfiles = [extractedProfile]

        let runner = MockRunner(optOutAction: nil,
                                scanAction: nil,
                                scanResults: [extractedProfile])

        try await operationsManager.runScanOperation(on: runner)
        let data = operationsManager.brokerProfileQueryData

        let scanExpectedHistoryTypes: [HistoryEvent.EventType] = [.scanStarted, .matchFound(profileID: extractedProfile.id)]

        XCTAssertEqual(expectedExtractedProfiles, data.extractedProfiles)
        XCTAssertEqual(data.scanData.historyEvents.count, scanExpectedHistoryTypes.count)
        XCTAssertEqual(data.scanData.historyEvents.map { $0.type }, scanExpectedHistoryTypes)

        XCTAssertNil(optOutOperationData.extractedProfile.removedDate)
    }

    func testOptOutConfirmationRemovedOnSomeProfiles() async throws {
        let profileQuery = ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 46)
        let dataBroker = DataBroker(name: "Test Broker", steps: [Step]())

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

        let operationsManager = BrokerProfileQueryOperationsManager(brokerProfileQueryData: brokerProfileQueryData,
                                                                    database: database)

        let expectedExtractedProfiles = [extractedProfile1]

        let runner = MockRunner(optOutAction: nil,
                                scanAction: nil,
                                scanResults: expectedExtractedProfiles)

        try await operationsManager.runScanOperation(on: runner)
        let data = operationsManager.brokerProfileQueryData

        let scanExpectedHistoryTypes: [HistoryEvent.EventType] = [.scanStarted, .matchFound(profileID: extractedProfile1.id)]
        let optOut1ExpectedHistoryTypes: [HistoryEvent.EventType] = []
        let optOut2ExpectedHistoryTypes: [HistoryEvent.EventType] = [.optOutConfirmed(profileID: extractedProfile2.id)]

        XCTAssertEqual(data.scanData.historyEvents.count, scanExpectedHistoryTypes.count)
        XCTAssertEqual(data.scanData.historyEvents.map { $0.type }, scanExpectedHistoryTypes)

        XCTAssertEqual(optOutOperationData1.historyEvents.count, optOut1ExpectedHistoryTypes.count)
        XCTAssertEqual(optOutOperationData1.historyEvents.map { $0.type }, optOut1ExpectedHistoryTypes)

        XCTAssertEqual(optOutOperationData2.historyEvents.count, optOut2ExpectedHistoryTypes.count)
        XCTAssertEqual(optOutOperationData2.historyEvents.map { $0.type }, optOut2ExpectedHistoryTypes)

        XCTAssertNil(optOutOperationData1.extractedProfile.removedDate)
        XCTAssertNotNil(optOutOperationData2.extractedProfile.removedDate)
    }

    func areDatesEqualIgnoringSeconds(date1: Date?, date2: Date?) -> Bool {
        if date1 == date2 {
            return true
        }
        guard let date1 = date1, let date2 = date2 else {
            return false
        }
        let calendar = Calendar.current
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute]

        let date1Components = calendar.dateComponents(components, from: date1)
        let date2Components = calendar.dateComponents(components, from: date2)

        let normalizedDate1 = calendar.date(from: date1Components)
        let normalizedDate2 = calendar.date(from: date2Components)

        return normalizedDate1 == normalizedDate2
    }
}

struct MockDataBase: DataBase {
    var mockBrokerProfileQueryData: BrokerProfileQueryData?

    func brokerProfileQueryData(for profileQuery: ProfileQuery, dataBroker: DataBroker) -> BrokerProfileQueryData? {
        if let data = mockBrokerProfileQueryData {
            return data
        }
        return BrokerProfileQueryData(id: UUID(), profileQuery: profileQuery, dataBroker: dataBroker)
    }

    func brokerProfileQueryData(for id: UUID) -> BrokerProfileQueryData? {
        BrokerProfileQueryData(id: UUID(), profileQuery: ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 46), dataBroker: DataBroker(name: "batata", steps: [Step]()))
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
        let data = BrokerProfileQueryData(id: UUID(), profileQuery: ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", age: 46), dataBroker: DataBroker(name: "batata", steps: [Step]()))

        return [data]
    }

}

struct MockRunner: OperationRunner {
    let optOutAction: (() throws -> Void)?
    let scanAction: (() throws -> Void)?
    let scanResults: [ExtractedProfile]

    func scan(_ profileQuery: BrokerProfileQueryData) async throws -> [ExtractedProfile] {
        try scanAction?()
        return scanResults
    }

    func optOut(_ extractedProfile: ExtractedProfile) async throws {
        try optOutAction?()
    }
}

extension HistoryEvent.EventType: Equatable {
    public static func == (lhs: HistoryEvent.EventType, rhs: HistoryEvent.EventType) -> Bool {
        switch (lhs, rhs) {
        case (.noMatchFound, .noMatchFound):
            return true
        case let (.matchFound(profileID: lhsProfileID), .matchFound(profileID: rhsProfileID)):
            return lhsProfileID == rhsProfileID
        case (.error, .error):
            return true
        case let (.optOutRequested(profileID: lhsProfileID), .optOutRequested(profileID: rhsProfileID)):
            return lhsProfileID == rhsProfileID
        case let (.optOutConfirmed(profileID: lhsProfileID), .optOutConfirmed(profileID: rhsProfileID)):
            return lhsProfileID == rhsProfileID
        case let (.optOutStarted(profileID: lhsProfileID), .optOutStarted(profileID: rhsProfileID)):
            return lhsProfileID == rhsProfileID
        case (.scanStarted, .scanStarted):
            return true
        default:
            return false
        }
    }
}
