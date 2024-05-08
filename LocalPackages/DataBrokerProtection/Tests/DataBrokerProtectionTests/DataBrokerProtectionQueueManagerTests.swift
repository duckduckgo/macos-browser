//
//  DataBrokerProtectionQueueManagerTests.swift
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

final class DataBrokerProtectionQueueManagerTests: XCTestCase {

    private var sut: DefaultDataBrokerProtectionQueueManager!

    private var mockQueue: MockDataBrokerProtectionOperationQueue!
    private var mockOperations: [MockDataBrokerOperation]!
    private var mockOperationsCreator: MockDataBrokerOperationsCreator!
    private var mockDatabase: MockDatabase!
    private var mockPixelHandler: MockPixelHandler!
    private var mockMismatchCalculator: MockMismatchCalculator!
    private var mockUpdater: MockDataBrokerProtectionBrokerUpdater!
    private var mockSchedulerConfig = DataBrokerProtectionProcessorConfiguration()
    private var mockRunnerProvider: MockRunnerProvider!
    private var mockUserNotification: MockUserNotification!
    private var mockDependencies: DefaultDataBrokerOperationDependencies!

    override func setUpWithError() throws {
        mockQueue = MockDataBrokerProtectionOperationQueue()
        mockOperations = (1...10).map { MockDataBrokerOperation(id: $0, operationType: .scan) }
        mockOperationsCreator = MockDataBrokerOperationsCreator(operationCollections: mockOperations)
        mockDatabase = MockDatabase()
        mockPixelHandler = MockPixelHandler()
        mockMismatchCalculator = MockMismatchCalculator(database: mockDatabase, pixelHandler: mockPixelHandler)
        mockUpdater = MockDataBrokerProtectionBrokerUpdater()
        mockRunnerProvider = MockRunnerProvider()
        mockUserNotification = MockUserNotification()

        mockDependencies = DefaultDataBrokerOperationDependencies(database: mockDatabase,
                                                                  brokerTimeInterval: 3,
                                                                  runnerProvider: mockRunnerProvider,
                                                                  notificationCenter: .default,
                                                                  pixelHandler: mockPixelHandler,
                                                                  userNotificationService: mockUserNotification)
    }

    func testWhenStartScheduledScan_andCurrentModeIsImmediate_thenCurrentOperationsAreNotInterrupted_andNewCompletionIsCalled() throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater)

        // When
        sut.startImmediateOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { _ in }

        // Then
        XCTAssert(mockQueue.operationCount == 10)

        // Given
        mockOperations = (11...20).map { MockDataBrokerOperation(id: $0, operationType: .scan) }
        mockOperationsCreator.operationCollections = mockOperations
        var completionCalled = false

        // When
        sut.startScheduledOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { _ in
            completionCalled.toggle()
        }

        // Then
        XCTAssert(mockQueue.operationCount == 10)
        XCTAssert(completionCalled)
    }

    func testWhenStartSecondImmediateScan_andCurrentModeIsImmediate_thenCurrentOperationsAreInterrupted_andCurrentCompletionIsCalled() throws {
        // Given
        var completionCalled = false
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater)

        // When
        sut.startImmediateOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { _ in
            completionCalled.toggle()
        }

        // Then
        XCTAssert(mockQueue.operationCount == 10)

        // Given
        mockOperations = (11...20).map { MockDataBrokerOperation(id: $0, operationType: .scan) }
        mockOperationsCreator.operationCollections = mockOperations

        // When
        sut.startImmediateOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { _ in }

        // Then
        XCTAssert(mockQueue.didCallCancelCount == 1)
        XCTAssert(completionCalled)
        XCTAssert(mockQueue.operations.filter { !$0.isCancelled }.count == 10)
        XCTAssert(mockQueue.operations.filter { $0.isCancelled }.count >= 0)
    }

    func testWhenScanCompletes_thenCompletionIsCalledInBarrierBlock() async throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater)
        let expectation = expectation(description: "Expected completion to be called")
        var completionCalled = false

        // When
        sut.startImmediateOperationsIfPermitted(showWebView: false,
                                                operationDependencies: mockDependencies) { errors in
            completionCalled.toggle()
            expectation.fulfill()
        }

        // Then
        await fulfillment(of: [expectation], timeout: 3)
        XCTAssert(completionCalled)
    }

    func testWhenOperationBuildingFails_thenCompletionIsCalledOnOperationCreationOneTimeError() async throws {
        // Given
        mockOperationsCreator.shouldError = true
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater)
        let expectation = expectation(description: "Expected completion to be called")
        var errorCollection: DataBrokerProtectionSchedulerErrorCollection?

        // When
        sut.startImmediateOperationsIfPermitted(showWebView: false,
                                                operationDependencies: mockDependencies) { errors in

            errorCollection = errors
            expectation.fulfill()
        }

        // Then
        await fulfillment(of: [expectation], timeout: 3)
        XCTAssertNotNil(errorCollection?.oneTimeError)
    }

    func testWhenOperationsAreRunning_andStopAllIsCalled_thenAllAreCancelled_andCompletionIsCalled() async throws {
        // Given
        mockOperations = (11...100).map { MockDataBrokerOperation(id: $0, operationType: .scan) }
        mockOperationsCreator.operationCollections = mockOperations
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater)
        let expectation = expectation(description: "Expected completion to be called")
        var completionCalled = false

        // When
        sut.startImmediateOperationsIfPermitted(showWebView: false,
                                                operationDependencies: mockDependencies) { errors in
            completionCalled.toggle()
            expectation.fulfill()
        }

        sut.stopAllOperations()

        // Then
        await fulfillment(of: [expectation], timeout: 3)
        XCTAssert(completionCalled)
    }

    // Test execute debug
    func testWhenCallDebugOptOutCommand_thenOptOutOperationsAreCreated() throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater)
        XCTAssert(mockOperationsCreator.createdType == .scan)

        // When
        sut.execute(.startOptOutOperations(showWebView: false,
                                           operationDependencies: mockDependencies,
                                           completion: nil))

        // Then
        XCTAssert(mockOperationsCreator.createdType == .optOut)
    }
}
