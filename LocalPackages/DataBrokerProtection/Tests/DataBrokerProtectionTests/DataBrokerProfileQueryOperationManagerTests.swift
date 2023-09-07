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

final class DataBrokerProfileQueryOperationManagerTests: XCTestCase {

    let sut = DataBrokerProfileQueryOperationManager()
    let mockWebOperationRunner = MockWebOperationRunner()
    let mockDatabase = MockDatabase()

    override func tearDown() {
        mockWebOperationRunner.clear()
    }
    // MARK: - Run scan operation tests

    func testWhenProfileQueryIdIsNil_thenRunScanOperationThrows() async {
        do {
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mockWithoutId,
                    scanOperationData: .mock
                ),
                database: mockDatabase,
                notificationCenter: .default
            )
            XCTFail("Scan should fail when brokerProfileQueryData has no id profile query")
        } catch {
            XCTAssertEqual(error as? OperationsError, OperationsError.idsMissingForBrokerOrProfileQuery)
            XCTAssertFalse(mockWebOperationRunner.wasScanCalled)
        }
    }

    func testWhenBrokerIdIsNil_thenRunScanOperationThrows() async {
        do {
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mockWithoutId,
                    profileQuery: .mock,
                    scanOperationData: .mock
                ),
                database: mockDatabase,
                notificationCenter: .default
            )
            XCTFail("Scan should fail when brokerProfileQueryData has no id for broker")
        } catch {
            XCTAssertEqual(error as? OperationsError, OperationsError.idsMissingForBrokerOrProfileQuery)
        }
    }

    func testWhenScanStarts_thenScanStartedEventIsAddedToTheDatabase() async {
        do {
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock
                ),
                database: mockDatabase,
                notificationCenter: .default
            )
            XCTAssertEqual(mockDatabase.eventsAdded.first?.type, .scanStarted)
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testWhenScanDoesNotFoundProfiles_thenNoMatchFoundEventIsAddedToTheDatabase() async {
        do {
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock
                ),
                database: mockDatabase,
                notificationCenter: .default
            )
            XCTAssertTrue(mockDatabase.eventsAdded.contains(where: { $0.type == .noMatchFound }))
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testWhenScannedProfileIsAlreadyInTheDatabase_noOptOutOperationIsCreated() async {
        do {
            mockWebOperationRunner.scanResults = [.mockWithoutRemovedDate]
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithoutRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default
            )
            XCTAssertFalse(mockDatabase.wasUpdateRemoveDateCalled)
            XCTAssertFalse(mockDatabase.wasSaveOptOutOperationCalled)
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testWhenScannedProfileIsAlreadyInTheDatabaseAndWasRemoved_thenTheRemovedDateIsSetBackToNil() async {
        do {
            mockWebOperationRunner.scanResults = [.mockWithRemovedDate]
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default
            )
            XCTAssertTrue(mockDatabase.wasUpdateRemoveDateCalled)
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testWhenNewExtractedProfileIsNotInDatabase_thenIsAddedToTheDatabaseAndOptOutOperationIsCreated() async {
        do {
            mockWebOperationRunner.scanResults = [.mockWithoutId]
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default
            )
            XCTAssertTrue(mockDatabase.wasSaveOptOutOperationCalled)
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testWhenRemovedProfileIsFound_thenOptOutConfirmedIsAddedRemoveDateIsUpdatedAndPreferredRunDateIsSetToNil() async {
        do {
            mockWebOperationRunner.scanResults = [.mockWithoutId]
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithoutRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default
            )
            XCTAssertTrue(mockDatabase.eventsAdded.contains(where: { $0.type == .optOutConfirmed }))
            XCTAssertTrue(mockDatabase.wasUpdateRemoveDateCalled)
            XCTAssertTrue(mockDatabase.wasUpdatedPreferredRunDateForOptOutCalled)
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testWhenNoRemovedProfilesAreFound_thenNoOtherEventIsAdded() async {
        do {
            mockWebOperationRunner.scanResults = [.mockWithoutRemovedDate]
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithoutRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default
            )
            XCTAssertFalse(mockDatabase.eventsAdded.contains(where: { $0.type == .optOutConfirmed }))
            XCTAssertFalse(mockDatabase.wasUpdateRemoveDateCalled)
            XCTAssertFalse(mockDatabase.wasUpdatedPreferredRunDateForOptOutCalled)
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testWhenErrorIsCaught_thenEventIsAddedToTheDatabase() async {
        do {
            mockWebOperationRunner.shouldScanThrow = true
            _ = try await sut.runScanOperation(
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithoutRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default
            )
            XCTFail("Should throw!")
        } catch {
            XCTAssertTrue(mockDatabase.wasAddHistoryEventCalled)
            XCTAssertTrue(mockDatabase.eventsAdded.contains(where: { $0.type == .error(error: .unknown("Test error")) }))
            XCTAssertFalse(mockDatabase.eventsAdded.contains(where: { $0.type == .matchesFound }))
            XCTAssertFalse(mockDatabase.eventsAdded.contains(where: { $0.type == .noMatchFound }))
            XCTAssertFalse(mockDatabase.wasSaveOptOutOperationCalled)
        }
    }

    // MARK: - Run opt-out operation tests

    func testWhenNoBrokerIdIsPresent_thenOptOutOperationThrows() async {
        do {
            _ = try await sut.runOptOutOperation(
                for: .mockWithoutRemovedDate,
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mockWithoutId,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default
            )
            XCTFail("Scan should fail when brokerProfileQueryData has no id profile query")
        } catch {
            XCTAssertEqual(error as? OperationsError, OperationsError.idsMissingForBrokerOrProfileQuery)
            XCTAssertFalse(mockWebOperationRunner.wasOptOutCalled)
        }
    }

    func testWhenNoProfileQueryIdIsPresent_thenOptOutOperationThrows() async {
        do {
            _ = try await sut.runOptOutOperation(
                for: .mockWithoutRemovedDate,
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mockWithoutId,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default
            )
            XCTFail("Scan should fail when brokerProfileQueryData has no id profile query")
        } catch {
            XCTAssertEqual(error as? OperationsError, OperationsError.idsMissingForBrokerOrProfileQuery)
            XCTAssertFalse(mockWebOperationRunner.wasOptOutCalled)
        }
    }

    func testWhenNoExtractedProfileIdIsPresent_thenOptOutOperationThrows() async {
        do {
            _ = try await sut.runOptOutOperation(
                for: .mockWithoutId,
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithoutId)]
                ),
                database: mockDatabase,
                notificationCenter: .default
            )
            XCTFail("Scan should fail when brokerProfileQueryData has no id profile query")
        } catch {
            XCTAssertEqual(error as? OperationsError, OperationsError.idsMissingForBrokerOrProfileQuery)
            XCTAssertFalse(mockWebOperationRunner.wasOptOutCalled)
        }
    }

    func testWhenExtractdProfileHasRemovedDate_thenNothingHappens() async {
        do {
            _ = try await sut.runOptOutOperation(
                for: .mockWithRemovedDate,
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default
            )
            XCTAssertFalse(mockDatabase.wasDatabaseCalled)
            XCTAssertFalse(mockWebOperationRunner.wasOptOutCalled)
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testOptOutStartedEventIsAdded_whenExtractedProfileOptOutStarts() async {
        do {
            _ = try await sut.runOptOutOperation(
                for: .mockWithoutRemovedDate,
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithoutRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default
            )
            XCTAssertTrue(mockDatabase.eventsAdded.contains(where: { $0.type == .optOutStarted }))
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testOptOutRequestedEventIsAdded_whenExtractedProfileOptOutFinishesWithoutError() async {
        do {
            _ = try await sut.runOptOutOperation(
                for: .mockWithoutRemovedDate,
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithoutRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default
            )
            XCTAssertTrue(mockDatabase.eventsAdded.contains(where: { $0.type == .optOutRequested }))
        } catch {
            XCTFail("Should not throw")
        }
    }

    func testErrorEventIsAdded_whenWebRunnerFails() async {
        do {
            mockWebOperationRunner.shouldOptOutThrow = true
            _ = try await sut.runOptOutOperation(
                for: .mockWithoutRemovedDate,
                on: mockWebOperationRunner,
                brokerProfileQueryData: .init(
                    dataBroker: .mock,
                    profileQuery: .mock,
                    scanOperationData: .mock,
                    optOutOperationsData: [OptOutOperationData.mock(with: .mockWithoutRemovedDate)]
                ),
                database: mockDatabase,
                notificationCenter: .default
            )
            XCTFail("Should throw!")
        } catch {
            XCTAssertTrue(mockDatabase.eventsAdded.contains(where: { $0.type == .optOutStarted }))
            XCTAssertFalse(mockDatabase.eventsAdded.contains(where: { $0.type == .optOutRequested }))
            XCTAssertTrue(mockDatabase.eventsAdded.contains(where: { $0.type == .error(error: DataBrokerProtectionError.unknown("Test error")) }))
        }
    }

    // MARK: - Update operation dates tests

    func testWhenUpdatingDatesOnOptOutAndLastEventIsError_thenWeSetPreferredRunDateWithRetryErrorDate() {
        let brokerId: Int64 = 1
        let profileQueryId: Int64 = 1
        let extractedProfileId: Int64 = 1
        mockDatabase.lastHistoryEventToReturn = HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .error(error: .unknown("Test error")))
        let schedulingConfig = DataBrokerScheduleConfig(retryError: 1, confirmOptOutScan: 0, maintenanceScan: 0)

        sut.updateOperationDataDates(brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId, schedulingConfig: schedulingConfig, database: mockDatabase)

        XCTAssertTrue(mockDatabase.wasUpdatedPreferredRunDateForOptOutCalled)
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: mockDatabase.lastPreferredRunDateOnOptOut, date2: Date().addingTimeInterval(schedulingConfig.retryError.hoursToSeconds)))
    }

    func testWhenUpdatingDatesOnScanAndLastEventIsError_thenWeSetPreferredRunDateWithRetryErrorDate() {
        let brokerId: Int64 = 1
        let profileQueryId: Int64 = 1
        mockDatabase.lastHistoryEventToReturn = HistoryEvent(extractedProfileId: nil, brokerId: brokerId, profileQueryId: profileQueryId, type: .error(error: .unknown("Test error")))
        let schedulingConfig = DataBrokerScheduleConfig(retryError: 1, confirmOptOutScan: 0, maintenanceScan: 0)

        sut.updateOperationDataDates(brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: nil, schedulingConfig: schedulingConfig, database: mockDatabase)

        XCTAssertTrue(mockDatabase.wasUpdatedPreferredRunDateForScanCalled)
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: mockDatabase.lastPreferredRunDateOnScan, date2: Date().addingTimeInterval(schedulingConfig.retryError.hoursToSeconds)))
    }

    func testWhenUpdatingDatesAndLastEventIsOptOutRequested_thenWeSetScanPreferredRunDateWithConfirmOptOutDate() {
        let brokerId: Int64 = 1
        let profileQueryId: Int64 = 1
        let extractedProfileId: Int64 = 1
        mockDatabase.lastHistoryEventToReturn = HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .optOutRequested)
        let schedulingConfig = DataBrokerScheduleConfig(retryError: 0, confirmOptOutScan: 1, maintenanceScan: 0)

        sut.updateOperationDataDates(brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId, schedulingConfig: schedulingConfig, database: mockDatabase)

        XCTAssertTrue(mockDatabase.wasUpdatedPreferredRunDateForScanCalled)
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: mockDatabase.lastPreferredRunDateOnScan, date2: Date().addingTimeInterval(schedulingConfig.confirmOptOutScan.hoursToSeconds)))
    }

    func testWhenUpdatingDatesAndLastEventIsOptOutRequested_thenWeSetOptOutPreferredRunDateToNil() {
        let brokerId: Int64 = 1
        let profileQueryId: Int64 = 1
        let extractedProfileId: Int64 = 1
        mockDatabase.lastHistoryEventToReturn = HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .optOutRequested)
        let schedulingConfig = DataBrokerScheduleConfig(retryError: 0, confirmOptOutScan: 1, maintenanceScan: 0)

        sut.updateOperationDataDates(brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId, schedulingConfig: schedulingConfig, database: mockDatabase)

        XCTAssertTrue(mockDatabase.wasUpdatedPreferredRunDateForScanCalled)
        XCTAssertNil(mockDatabase.lastPreferredRunDateOnOptOut)
    }

    func testWhenUpdatingDatesAndLastEventIsMatchesFound_thenWeSetScanPreferredDateToMaintanence() {
        let brokerId: Int64 = 1
        let profileQueryId: Int64 = 1
        let extractedProfileId: Int64 = 1
        mockDatabase.lastHistoryEventToReturn = HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .matchesFound)
        let schedulingConfig = DataBrokerScheduleConfig(retryError: 0, confirmOptOutScan: 0, maintenanceScan: 1)

        sut.updateOperationDataDates(brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId, schedulingConfig: schedulingConfig, database: mockDatabase)

        XCTAssertTrue(mockDatabase.wasUpdatedPreferredRunDateForScanCalled)
        XCTAssertTrue(areDatesEqualIgnoringSeconds(date1: mockDatabase.lastPreferredRunDateOnScan, date2: Date().addingTimeInterval(schedulingConfig.maintenanceScan.hoursToSeconds)))
    }

    func testWhenUpdatingDatesAndLastEventIsOptOutStarted_thenNothingHappens() {
        let brokerId: Int64 = 1
        let profileQueryId: Int64 = 1
        let extractedProfileId: Int64 = 1
        mockDatabase.lastHistoryEventToReturn = HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .optOutStarted)
        let schedulingConfig = DataBrokerScheduleConfig(retryError: 0, confirmOptOutScan: 0, maintenanceScan: 1)

        sut.updateOperationDataDates(brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId, schedulingConfig: schedulingConfig, database: mockDatabase)

        XCTAssertFalse(mockDatabase.wasUpdatedPreferredRunDateForScanCalled)
        XCTAssertFalse(mockDatabase.wasUpdatedPreferredRunDateForOptOutCalled)
        XCTAssertNil(mockDatabase.lastPreferredRunDateOnScan)
        XCTAssertNil(mockDatabase.lastPreferredRunDateOnOptOut)
    }

    func testWhenUpdatingDatesAndLastEventIsScanStarted_thenNothingHappens() {
        let brokerId: Int64 = 1
        let profileQueryId: Int64 = 1
        let extractedProfileId: Int64 = 1
        mockDatabase.lastHistoryEventToReturn = HistoryEvent(extractedProfileId: extractedProfileId, brokerId: brokerId, profileQueryId: profileQueryId, type: .scanStarted)
        let schedulingConfig = DataBrokerScheduleConfig(retryError: 0, confirmOptOutScan: 0, maintenanceScan: 1)

        sut.updateOperationDataDates(brokerId: brokerId, profileQueryId: profileQueryId, extractedProfileId: extractedProfileId, schedulingConfig: schedulingConfig, database: mockDatabase)

        XCTAssertFalse(mockDatabase.wasUpdatedPreferredRunDateForScanCalled)
        XCTAssertFalse(mockDatabase.wasUpdatedPreferredRunDateForOptOutCalled)
        XCTAssertNil(mockDatabase.lastPreferredRunDateOnScan)
        XCTAssertNil(mockDatabase.lastPreferredRunDateOnOptOut)
    }
}

final class MockDatabase: DataBrokerProtectionRepository {
    var wasSaveProfileCalled = false
    var wasFetchProfileCalled = false
    var wasSaveOptOutOperationCalled = false
    var wasBrokerProfileQueryDataCalled = false
    var wasFetchAllBrokerProfileQueryDataCalled = false
    var wasUpdatedPreferredRunDateForScanCalled = false
    var wasUpdatedPreferredRunDateForOptOutCalled = false
    var wasUpdateLastRunDateForScanCalled = false
    var wasUpdateLastRunDateForOptOutCalled = false
    var wasUpdateRemoveDateCalled = false
    var wasAddHistoryEventCalled = false
    var wasFetchLastHistoryEventCalled = false

    var eventsAdded = [HistoryEvent]()
    var lastHistoryEventToReturn: HistoryEvent?
    var lastPreferredRunDateOnScan: Date?
    var lastPreferredRunDateOnOptOut: Date?

    lazy var callsList: [Bool] = [
        wasSaveProfileCalled,
        wasFetchProfileCalled,
        wasSaveOptOutOperationCalled,
        wasBrokerProfileQueryDataCalled,
        wasFetchAllBrokerProfileQueryDataCalled,
        wasUpdatedPreferredRunDateForScanCalled,
        wasUpdatedPreferredRunDateForOptOutCalled,
        wasUpdateLastRunDateForScanCalled,
        wasUpdateLastRunDateForOptOutCalled,
        wasUpdateRemoveDateCalled,
        wasAddHistoryEventCalled,
        wasFetchLastHistoryEventCalled]

    var wasDatabaseCalled: Bool {
        callsList.filter { $0 }.count > 0 // If one value is true. The database was called
    }

    func save(_ profile: DataBrokerProtectionProfile) {
        wasSaveProfileCalled = true
    }

    func fetchProfile() -> DataBrokerProtectionProfile? {
        wasFetchProfileCalled = true
        return nil
    }

    func saveOptOutOperation(optOut: OptOutOperationData, extractedProfile: ExtractedProfile) throws {
        wasSaveOptOutOperationCalled = true
    }

    func brokerProfileQueryData(for brokerId: Int64, and profileQueryId: Int64) -> BrokerProfileQueryData? {
        wasBrokerProfileQueryDataCalled = true

        if let lastHistoryEventToReturn = self.lastHistoryEventToReturn {
            let scanOperationData = ScanOperationData(brokerId: brokerId, profileQueryId: profileQueryId, historyEvents: [lastHistoryEventToReturn])

            return BrokerProfileQueryData(dataBroker: .mock, profileQuery: .mock, scanOperationData: scanOperationData)
        } else {
            return nil
        }
    }

    func fetchAllBrokerProfileQueryData(for profileId: Int64) -> [BrokerProfileQueryData] {
        wasFetchAllBrokerProfileQueryDataCalled = true
        return [BrokerProfileQueryData]()
    }

    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) {
        lastPreferredRunDateOnScan = date
        wasUpdatedPreferredRunDateForScanCalled = true
    }

    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) {
        lastPreferredRunDateOnOptOut = date
        wasUpdatedPreferredRunDateForOptOutCalled = true
    }

    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) {
        wasUpdateLastRunDateForScanCalled = true
    }

    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) {
        wasUpdateLastRunDateForOptOutCalled = true
    }

    func updateRemovedDate(_ date: Date?, on extractedProfileId: Int64) {
        wasUpdateRemoveDateCalled = true
    }

    func add(_ historyEvent: HistoryEvent) {
        wasAddHistoryEventCalled = true
        eventsAdded.append(historyEvent)
    }

    func fetchLastEvent(brokerId: Int64, profileQueryId: Int64) -> HistoryEvent? {
        wasFetchLastHistoryEventCalled = true

        return lastHistoryEventToReturn
    }

    func hasMatches() -> Bool {
        false
    }

    func clear() {
        wasSaveProfileCalled = false
        wasFetchProfileCalled = false
        wasSaveOptOutOperationCalled = false
        wasBrokerProfileQueryDataCalled = false
        wasFetchAllBrokerProfileQueryDataCalled = false
        wasUpdatedPreferredRunDateForScanCalled = false
        wasUpdatedPreferredRunDateForOptOutCalled = false
        wasUpdateLastRunDateForScanCalled = false
        wasUpdateLastRunDateForOptOutCalled = false
        wasUpdateRemoveDateCalled = false
        wasAddHistoryEventCalled = false
        wasFetchLastHistoryEventCalled = false
        eventsAdded.removeAll()
        lastHistoryEventToReturn = nil
        lastPreferredRunDateOnScan = nil
        lastPreferredRunDateOnOptOut = nil
    }
}

final class MockWebOperationRunner: WebOperationRunner {

    var shouldScanThrow = false
    var shouldOptOutThrow = false
    var scanResults = [ExtractedProfile]()
    var wasScanCalled = false
    var wasOptOutCalled = false

    func scan(_ profileQuery: DataBrokerProtection.BrokerProfileQueryData, showWebView: Bool) async throws -> [ExtractedProfile] {
        wasScanCalled = true

        if shouldScanThrow {
            throw DataBrokerProtectionError.unknown("Test error")
        } else {
            return scanResults
        }
    }

    func optOut(profileQuery: DataBrokerProtection.BrokerProfileQueryData, extractedProfile: DataBrokerProtection.ExtractedProfile, showWebView: Bool) async throws {
        wasOptOutCalled = true

        if shouldOptOutThrow {
            throw DataBrokerProtectionError.unknown("Test error")
        }
    }

    func clear() {
        shouldScanThrow = false
        shouldOptOutThrow = false
        scanResults.removeAll()
        wasScanCalled = false
        wasOptOutCalled = false
    }
}

extension ScanOperationData {

    static var mock: ScanOperationData {
        .init(
            brokerId: 1,
            profileQueryId: 1,
            historyEvents: [HistoryEvent]()
        )
    }
}

extension OptOutOperationData {

    static func mock(with extractedProfile: ExtractedProfile) -> OptOutOperationData {
        .init(brokerId: 1, profileQueryId: 1, historyEvents: [HistoryEvent](), extractedProfile: extractedProfile)
    }
}

extension DataBroker {

    static var mock: DataBroker {
        DataBroker(
            id: 1,
            name: "Test broker",
            steps: [Step](),
            version: "1.0",
            schedulingConfig: DataBrokerScheduleConfig(
                retryError: 0,
                confirmOptOutScan: 0,
                maintenanceScan: 0
            )
        )
    }

    static var mockWithoutId: DataBroker {
        DataBroker(
            name: "Test broker",
            steps: [Step](),
            version: "1.0",
            schedulingConfig: DataBrokerScheduleConfig(
                retryError: 0,
                confirmOptOutScan: 0,
                maintenanceScan: 0
            )
        )
    }
}

extension ProfileQuery {

    static var mock: ProfileQuery {
        .init(id: 1, firstName: "First", lastName: "Last", city: "City", state: "State", birthYear: 1980)
    }

    static var mockWithoutId: ProfileQuery {
        .init(firstName: "First", lastName: "Last", city: "City", state: "State", birthYear: 1980)
    }
}

extension ExtractedProfile {

    static var mockWithRemovedDate: ExtractedProfile {
        ExtractedProfile(id: 1, name: "Some name", profileUrl: "someURL", removedDate: Date())
    }

    static var mockWithoutRemovedDate: ExtractedProfile {
        ExtractedProfile(id: 1, name: "Some name", profileUrl: "someURL")
    }

    static var mockWithoutId: ExtractedProfile {
        ExtractedProfile(name: "Some name", profileUrl: "someOtherURL")
    }
}
