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
import Configuration
import Persistence
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
    private var mockAgentStopper: MockAgentStopper!
    private var mockConfigurationManager: MockConfigurationManager!
    private var mockPrivacyConfigurationManager: DBPPrivacyConfigurationManager!
    private var mockAuthenticationManager: MockAuthenticationManager!
    private var mockFreemiumDBPUserStateManager: MockFreemiumDBPUserStateManager!

    override func setUpWithError() throws {

        mockPixelHandler = MockPixelHandler()
        mockActivityScheduler = MockDataBrokerProtectionBackgroundActivityScheduler()
        mockNotificationService = MockUserNotificationService()
        mockAuthenticationManager = MockAuthenticationManager()
        mockAgentStopper = MockAgentStopper()
        mockConfigurationManager = MockConfigurationManager()
        mockPrivacyConfigurationManager = DBPPrivacyConfigurationManager()

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
                                                                  config: DataBrokerExecutionConfig(mode: .normal),
                                                                  runnerProvider: MockRunnerProvider(),
                                                                  notificationCenter: .default,
                                                                  pixelHandler: mockPixelHandler,
                                                                  userNotificationService: mockNotificationService)

        mockProfile = DataBrokerProtectionProfile(
            names: [],
            addresses: [],
            phones: [],
            birthYear: 1992)

        mockFreemiumDBPUserStateManager = MockFreemiumDBPUserStateManager()
    }

    func testWhenAgentStart_andProfileExists_andUserIsNotFreemium_thenActivityIsScheduled_andScheduledAllOperationsRun() async throws {
        // Given
        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler,
            agentStopper: mockAgentStopper,
            configurationManager: mockConfigurationManager,
            privacyConfigurationManager: mockPrivacyConfigurationManager,
            authenticationManager: mockAuthenticationManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        mockDataManager.profileToReturn = mockProfile
        mockAuthenticationManager.isUserAuthenticatedValue = true
        mockFreemiumDBPUserStateManager.didActivate = false

        let schedulerStartedExpectation = XCTestExpectation(description: "Scheduler started")
        var schedulerStarted = false
        mockActivityScheduler.startSchedulerCompletion = {
            schedulerStarted = true
            schedulerStartedExpectation.fulfill()
        }

        let scanCalledExpectation = XCTestExpectation(description: "Scan called")
        var startScheduledScansCalled = false
        mockQueueManager.startScheduledAllOperationsIfPermittedCalledCompletion = {
            startScheduledScansCalled = true
            scanCalledExpectation.fulfill()
        }

        // When
        sut.agentFinishedLaunching()

        // Then
        await fulfillment(of: [scanCalledExpectation, schedulerStartedExpectation], timeout: 1.0)
        XCTAssertTrue(schedulerStarted)
        XCTAssertTrue(startScheduledScansCalled)
    }

    func testWhenAgentStart_andProfileExists_andUserIsFreemium_thenActivityIsScheduled_andScheduledScanOperationsRun() async throws {
        // Given
        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler,
            agentStopper: mockAgentStopper,
            configurationManager: mockConfigurationManager,
            privacyConfigurationManager: mockPrivacyConfigurationManager,
            authenticationManager: mockAuthenticationManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        mockDataManager.profileToReturn = mockProfile
        mockFreemiumDBPUserStateManager.didActivate = true

        let schedulerStartedExpectation = XCTestExpectation(description: "Scheduler started")
        var schedulerStarted = false
        mockActivityScheduler.startSchedulerCompletion = {
            schedulerStarted = true
            schedulerStartedExpectation.fulfill()
        }

        let scanCalledExpectation = XCTestExpectation(description: "Scan called")
        var startScheduledScansCalled = false
        mockQueueManager.startScheduledScanOperationsIfPermittedCalledCompletion = {
            startScheduledScansCalled = true
            scanCalledExpectation.fulfill()
        }

        // When
        sut.agentFinishedLaunching()

        // Then
        await fulfillment(of: [scanCalledExpectation, schedulerStartedExpectation], timeout: 1.0)
        XCTAssertTrue(schedulerStarted)
        XCTAssertTrue(startScheduledScansCalled)
    }

    func testWhenAgentStart_andProfileDoesNotExist_andUserIsFreemium_thenActivityIsNotScheduled_andStopAgentIsCalled() async throws {
        // Given
        let mockStopAction = MockDataProtectionStopAction()
        let agentStopper = DefaultDataBrokerProtectionAgentStopper(dataManager: mockDataManager,
                                                                   entitlementMonitor: DataBrokerProtectionEntitlementMonitor(),
                                                                   authenticationManager: MockAuthenticationManager(),
                                                                   pixelHandler: mockPixelHandler,
                                                                   stopAction: mockStopAction, freemiumDBPUserStateManager: MockFreemiumDBPUserStateManager())
        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler,
            agentStopper: agentStopper,
            configurationManager: mockConfigurationManager,
            privacyConfigurationManager: mockPrivacyConfigurationManager,
            authenticationManager: mockAuthenticationManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        mockDataManager.profileToReturn = nil
        mockFreemiumDBPUserStateManager.didActivate = true

        let stopAgentExpectation = XCTestExpectation(description: "Stop agent expectation")

        var stopAgentWasCalled = false
        mockStopAction.stopAgentCompletion = {
            stopAgentWasCalled = true
            stopAgentExpectation.fulfill()
        }

        // When
        sut.agentFinishedLaunching()
        await fulfillment(of: [stopAgentExpectation], timeout: 1.0)

        // Then
        XCTAssertTrue(stopAgentWasCalled)
    }

    func testWhenAgentStart_thenPrerequisitesAreValidated_andEntitlementsAreMonitored() async {
        // Given
        let mockAgentStopper = MockAgentStopper()

        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler,
            agentStopper: mockAgentStopper,
            configurationManager: mockConfigurationManager,
            privacyConfigurationManager: mockPrivacyConfigurationManager,
            authenticationManager: mockAuthenticationManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        mockDataManager.profileToReturn = nil

        let preRequisitesExpectation = XCTestExpectation(description: "preRequisitesExpectation expectation")
        var runPrerequisitesWasCalled = false
        mockAgentStopper.validateRunPrerequisitesCompletion = {
            runPrerequisitesWasCalled = true
            preRequisitesExpectation.fulfill()
        }

        let monitorEntitlementExpectation = XCTestExpectation(description: "monitorEntitlement expectation")
        var monitorEntitlementWasCalled = false
        mockAgentStopper.monitorEntitlementCompletion = {
            monitorEntitlementWasCalled = true
            monitorEntitlementExpectation.fulfill()
        }

        // When
        sut.agentFinishedLaunching()
        await fulfillment(of: [preRequisitesExpectation, monitorEntitlementExpectation], timeout: 1.0)

        // Then
        XCTAssertTrue(runPrerequisitesWasCalled)
        XCTAssertTrue(monitorEntitlementWasCalled)
    }

    func testWhenActivitySchedulerTriggers_andUserIsNotFreemium_thenScheduledAllOperationsRun() async throws {
        // Given
        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler,
            agentStopper: mockAgentStopper,
            configurationManager: mockConfigurationManager,
            privacyConfigurationManager: mockPrivacyConfigurationManager,
            authenticationManager: mockAuthenticationManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        mockDataManager.profileToReturn = mockProfile
        mockAuthenticationManager.isUserAuthenticatedValue = true
        mockFreemiumDBPUserStateManager.didActivate = false

        var startScheduledScansCalled = false
        mockQueueManager.startScheduledAllOperationsIfPermittedCalledCompletion = {
            startScheduledScansCalled = true
        }

        // When
        mockActivityScheduler.triggerDelegateCall()

        // Then
        XCTAssertTrue(startScheduledScansCalled)
    }

    func testWhenActivitySchedulerTriggers_andUserIsFreemium_thenScheduledScanOperationsRun() async throws {
        // Given
        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler,
            agentStopper: mockAgentStopper,
            configurationManager: mockConfigurationManager,
            privacyConfigurationManager: mockPrivacyConfigurationManager,
            authenticationManager: mockAuthenticationManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        mockDataManager.profileToReturn = mockProfile
        mockFreemiumDBPUserStateManager.didActivate = true

        var startScheduledScansCalled = false
        mockQueueManager.startScheduledScanOperationsIfPermittedCalledCompletion = {
            startScheduledScansCalled = true
        }

        // When
        mockActivityScheduler.triggerDelegateCall()

        // Then
        XCTAssertTrue(startScheduledScansCalled)
    }

    func testWhenProfileSaved_andUserIsNotFreemium_thenImmediateOperationsRun() async throws {
        // Given
        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler,
            agentStopper: mockAgentStopper,
            configurationManager: mockConfigurationManager,
            privacyConfigurationManager: mockPrivacyConfigurationManager,
            authenticationManager: mockAuthenticationManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        mockDataManager.profileToReturn = mockProfile
        mockFreemiumDBPUserStateManager.didActivate = false

        var startImmediateScansCalled = false
        mockQueueManager.startImmediateScanOperationsIfPermittedCalledCompletion = {
            startImmediateScansCalled = true
        }

        // When
        sut.profileSaved()

        // Then
        XCTAssertTrue(startImmediateScansCalled)
    }

    func testWhenProfileSaved_andUserIsFreemium_thenImmediateOperationsRun() async throws {
        // Given
        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler,
            agentStopper: mockAgentStopper,
            configurationManager: mockConfigurationManager,
            privacyConfigurationManager: mockPrivacyConfigurationManager,
            authenticationManager: mockAuthenticationManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        mockDataManager.profileToReturn = mockProfile
        mockFreemiumDBPUserStateManager.didActivate = true

        var startImmediateScansCalled = false
        mockQueueManager.startImmediateScanOperationsIfPermittedCalledCompletion = {
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
            pixelHandler: mockPixelHandler,
            agentStopper: mockAgentStopper,
            configurationManager: mockConfigurationManager,
            privacyConfigurationManager: mockPrivacyConfigurationManager,
            authenticationManager: mockAuthenticationManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

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
            pixelHandler: mockPixelHandler,
            agentStopper: mockAgentStopper,
            configurationManager: mockConfigurationManager,
            privacyConfigurationManager: mockPrivacyConfigurationManager,
            authenticationManager: mockAuthenticationManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

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
            pixelHandler: mockPixelHandler,
            agentStopper: mockAgentStopper,
            configurationManager: mockConfigurationManager,
            privacyConfigurationManager: mockPrivacyConfigurationManager,
            authenticationManager: mockAuthenticationManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        mockNotificationService.reset()
        mockQueueManager.startImmediateScanOperationsIfPermittedCompletionError = DataBrokerProtectionAgentErrorCollection(oneTimeError: NSError(domain: "test", code: 10))

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
            pixelHandler: mockPixelHandler,
            agentStopper: mockAgentStopper,
            configurationManager: mockConfigurationManager,
            privacyConfigurationManager: mockPrivacyConfigurationManager,
            authenticationManager: mockAuthenticationManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

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
            pixelHandler: mockPixelHandler,
            agentStopper: mockAgentStopper,
            configurationManager: mockConfigurationManager,
            privacyConfigurationManager: mockPrivacyConfigurationManager,
            authenticationManager: mockAuthenticationManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        mockNotificationService.reset()
        mockDataManager.shouldReturnHasMatches = false

        // When
        sut.profileSaved()

        // Then
        XCTAssertFalse(mockNotificationService.checkInNotificationWasScheduled)
    }

    func testWhenAppLaunched_andUserIsNotFreemium_thenScheduledAllOperationsRun() async throws {
        // Given
        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler,
            agentStopper: mockAgentStopper,
            configurationManager: mockConfigurationManager,
            privacyConfigurationManager: mockPrivacyConfigurationManager,
            authenticationManager: mockAuthenticationManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        mockAuthenticationManager.isUserAuthenticatedValue = true
        mockFreemiumDBPUserStateManager.didActivate = false

        var startScheduledScansCalled = false
        mockQueueManager.startScheduledAllOperationsIfPermittedCalledCompletion = {
            startScheduledScansCalled = true
        }

        // When
        sut.appLaunched()

        // Then
        XCTAssertTrue(startScheduledScansCalled)
    }

    func testWhenAppLaunched_andUserIsFreemium_thenScheduledScanOperationsRun() async throws {
        // Given
        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler,
            agentStopper: mockAgentStopper,
            configurationManager: mockConfigurationManager,
            privacyConfigurationManager: mockPrivacyConfigurationManager,
            authenticationManager: mockAuthenticationManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        mockFreemiumDBPUserStateManager.didActivate = true

        var startScheduledScansCalled = false
        mockQueueManager.startScheduledScanOperationsIfPermittedCalledCompletion = {
            startScheduledScansCalled = true
        }

        // When
        sut.appLaunched()

        // Then
        XCTAssertTrue(startScheduledScansCalled)
    }

    func testWhenFirePixelsCalled_andUserIsAuthenticated_thenPixelsAreFired() async throws {
        // Given
        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler,
            agentStopper: mockAgentStopper,
            configurationManager: mockConfigurationManager,
            privacyConfigurationManager: mockPrivacyConfigurationManager,
            authenticationManager: mockAuthenticationManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        mockAuthenticationManager.isUserAuthenticatedValue = true
        mockFreemiumDBPUserStateManager.didActivate = false

        // When
        sut.fireMonitoringPixels()

        // Then
        XCTAssertNotNil(mockPixelHandler.lastFiredEvent)
    }

    func testWhenFirePixelsCalled_andUserIsNotAuthenticated_thenPixelsAreNotFired() async throws {
        // Given
        sut = DataBrokerProtectionAgentManager(
            userNotificationService: mockNotificationService,
            activityScheduler: mockActivityScheduler,
            ipcServer: mockIPCServer,
            queueManager: mockQueueManager,
            dataManager: mockDataManager,
            operationDependencies: mockDependencies,
            pixelHandler: mockPixelHandler,
            agentStopper: mockAgentStopper,
            configurationManager: mockConfigurationManager,
            privacyConfigurationManager: mockPrivacyConfigurationManager,
            authenticationManager: mockAuthenticationManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager)

        mockAuthenticationManager.isUserAuthenticatedValue = false
        mockFreemiumDBPUserStateManager.didActivate = false

        // When
        sut.fireMonitoringPixels()

        // Then
        XCTAssertNil(mockPixelHandler.lastFiredEvent)
    }

}

struct MockConfigurationFetcher: ConfigurationFetching {
    func fetch(_ configuration: Configuration, isDebug: Bool) async throws {
        return
    }

    func fetch(all configurations: [Configuration]) async throws {
        return
    }
}

struct MockConfigurationStore: ConfigurationStoring {
    func loadData(for configuration: Configuration) -> Data? {
        return nil
    }

    func loadEtag(for configuration: Configuration) -> String? {
        return nil
    }

    func loadEmbeddedEtag(for configuration: Configuration) -> String? {
        return nil
    }

    mutating func saveData(_ data: Data, for configuration: Configuration) throws {
        return
    }

    mutating func saveEtag(_ etag: String, for configuration: Configuration) throws {
        return
    }

    func fileUrl(for configuration: Configuration) -> URL {
        return URL(string: "file:///\(configuration.rawValue)")!
    }

}

final class MockConfigurationManager: DefaultConfigurationManager {
    override init(fetcher: ConfigurationFetching = MockConfigurationFetcher(),
                  store: ConfigurationStoring = MockConfigurationStore(),
                  defaults: KeyValueStoring = UserDefaults()) {
        super.init(fetcher: fetcher, store: store, defaults: defaults)
    }
}
