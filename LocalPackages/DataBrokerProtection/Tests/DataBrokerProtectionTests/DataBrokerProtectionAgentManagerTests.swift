//
//  DataBrokerProtectionAgentManagerTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

final class DataBrokerProtectionAgentManagerTests: XCTestCase {

    private var sut: DataBrokerProtectionAgentManager!

    private var mockActivityScheduler: MockDataBrokerProtectionBackgroundActivityScheduler!
    private var mockNotificationService: MockUserNotificationService!
    private var mockQueueManager: MockDataBrokerProtectionOperationQueueManager!
    private var mockDataManager: MockDataBrokerProtectionDataManager!
    private var mockIPCServer: MockIPCServer!
    private var mockPixelHandler: MockPixelHandler!
    private var mockDependencies: DefaultDataBrokerOperationDependencies!
    private var mockProfile: DataBrokerProtectionProfile!

    override func setUpWithError() throws {

        mockPixelHandler = MockPixelHandler()
        mockActivityScheduler = MockDataBrokerProtectionBackgroundActivityScheduler()
        mockNotificationService = MockUserNotificationService()

        let mockDatabase = MockDatabase()
        let mockMismatchCalculator = MockMismatchCalculator(database: mockDatabase, pixelHandler: mockPixelHandler)
        mockQueueManager = MockDataBrokerProtectionOperationQueueManager(
            operationQueue: MockDataBrokerProtectionOperationQueue(),
            operationsCreator: MockDataBrokerOperationsCreator(),
            mismatchCalculator: mockMismatchCalculator,
            brokerUpdater: MockDataBrokerProtectionBrokerUpdater(),
            pixelHandler: mockPixelHandler)

        mockIPCServer = MockIPCServer(machServiceName: "")

        let fakeBroker = DataBrokerDebugFlagFakeBroker()
        mockDataManager = MockDataBrokerProtectionDataManager(pixelHandler: mockPixelHandler, fakeBrokerFlag: fakeBroker)

        mockDependencies = DefaultDataBrokerOperationDependencies(database: mockDatabase,
                                                                  config: DataBrokerExecutionConfig(),
                                                                  runnerProvider: MockRunnerProvider(),
                                                                  notificationCenter: .default,
                                                                  pixelHandler: mockPixelHandler,
                                                                  userNotificationService: mockNotificationService)

        mockProfile = DataBrokerProtectionProfile(
            names: [],
            addresses: [],
            phones: [],
            birthYear: 1992)
    }

    func testWhenAgentStart_andProfileExists_thenActivityIsScheduled_andSheduledOpereationsRun() async throws {
        // Given
        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler)

        mockDataManager.profileToReturn = mockProfile

        var schedulerStarted = false
        mockActivityScheduler.startSchedulerCompletion = {
            schedulerStarted = true
        }

        var startScheduledScansCalled = false
        mockQueueManager.startScheduledOperationsIfPermittedCalledCompletion = { _ in
            startScheduledScansCalled = true
        }

        // When
        sut.agentFinishedLaunching()

        // Then
        XCTAssertTrue(schedulerStarted)
        XCTAssertTrue(startScheduledScansCalled)
    }

    func testWhenAgentStart_andProfileDoesNotExist_thenActivityIsNotScheduled_andSheduledOpereationsNotRun() async throws {
        // Given
        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler)

        mockDataManager.profileToReturn = nil

        var schedulerStarted = false
        mockActivityScheduler.startSchedulerCompletion = {
            schedulerStarted = true
        }

        var startScheduledScansCalled = false
        mockQueueManager.startScheduledOperationsIfPermittedCalledCompletion = { _ in
            startScheduledScansCalled = true
        }

        // When
        sut.agentFinishedLaunching()

        // Then
        XCTAssertFalse(schedulerStarted)
        XCTAssertFalse(startScheduledScansCalled)
    }

    func testWhenActivitySchedulerTriggers_thenSheduledOpereationsRun() async throws {
        // Given
        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler)

        mockDataManager.profileToReturn = mockProfile

        var startScheduledScansCalled = false
        mockQueueManager.startScheduledOperationsIfPermittedCalledCompletion = { _ in
            startScheduledScansCalled = true
        }

        // When
        mockActivityScheduler.triggerDelegateCall()

        // Then
        XCTAssertTrue(startScheduledScansCalled)
    }

    func testWhenProfileSaved_thenImmediateOpereationsRun() async throws {
        // Given
        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler)

        mockDataManager.profileToReturn = mockProfile

        var startImmediateScansCalled = false
        mockQueueManager.startImmediateOperationsIfPermittedCalledCompletion = { _ in
            startImmediateScansCalled = true
        }

        // When
        sut.profileSaved()

        // Then
        XCTAssertTrue(startImmediateScansCalled)
    }

    func testWhenProfileSaved_thenUserNotificationPermissionAsked() async throws {
        // Given
        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler)

        mockNotificationService.reset()

        // When
        sut.profileSaved()

        // Then
        XCTAssertTrue(mockNotificationService.requestPermissionWasAsked)
    }

    func testWhenProfileSaved_andScansCompleted_andNoScanError_thenUserNotificationSent() async throws {
        // Given
        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler)

        mockNotificationService.reset()

        // When
        sut.profileSaved()

        // Then
        XCTAssertTrue(mockNotificationService.firstScanNotificationWasSent)
    }

    func testWhenProfileSaved_andScansCompleted_andScanError_thenUserNotificationNotSent() async throws {
        // Given
        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler)

        mockNotificationService.reset()
        mockQueueManager.startImmediateOperationsIfPermittedCompletionError = DataBrokerProtectionAgentErrorCollection(oneTimeError: NSError(domain: "test", code: 10))

        // When
        sut.profileSaved()

        // Then
        XCTAssertFalse(mockNotificationService.firstScanNotificationWasSent)
    }

    func testWhenProfileSaved_andScansCompleted_andHasMatches_thenCheckInNotificationScheduled() async throws {
        // Given
        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler)

        mockNotificationService.reset()
        mockDataManager.shouldReturnHasMatches = true

        // When
        sut.profileSaved()

        // Then
        XCTAssertTrue(mockNotificationService.checkInNotificationWasScheduled)
    }

    func testWhenProfileSaved_andScansCompleted_andHasNoMatches_thenCheckInNotificationNotScheduled() async throws {
        // Given
        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler)

        mockNotificationService.reset()
        mockDataManager.shouldReturnHasMatches = false

        // When
        sut.profileSaved()

        // Then
        XCTAssertFalse(mockNotificationService.checkInNotificationWasScheduled)
    }

    func testWhenAppLaunched_thenSheduledOpereationsRun() async throws {
        // Given
        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler)

        var startScheduledScansCalled = false
        mockQueueManager.startScheduledOperationsIfPermittedCalledCompletion = { _ in
            startScheduledScansCalled = true
        }

        // When
        sut.appLaunched()

        // Then
        XCTAssertTrue(startScheduledScansCalled)
    }
}
