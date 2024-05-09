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
    private var mockOperationsCreator: MockDataBrokerOperationsCreator!
    private var mockDatabase: MockDatabase!
    private var mockPixelHandler: MockPixelHandler!
    private var mockMismatchCalculator: MockMismatchCalculator!
    private var mockUpdater: MockDataBrokerProtectionBrokerUpdater!
    private var mockSchedulerConfig = DataBrokerProtectionProcessorConfiguration()
    private var mockRunnerProvider: MockRunnerProvider!
    private var mockUserNotification: MockUserNotification!
    private var mockOperationErrorDelegate: MockDataBrokerOperationErrorDelegate!
    private var mockDependencies: DefaultDataBrokerOperationDependencies!

    override func setUpWithError() throws {
        mockQueue = MockDataBrokerProtectionOperationQueue()
        mockOperationsCreator = MockDataBrokerOperationsCreator()
        mockDatabase = MockDatabase()
        mockPixelHandler = MockPixelHandler()
        mockMismatchCalculator = MockMismatchCalculator(database: mockDatabase, pixelHandler: mockPixelHandler)
        mockUpdater = MockDataBrokerProtectionBrokerUpdater()
        mockRunnerProvider = MockRunnerProvider()
        mockUserNotification = MockUserNotification()

        mockDependencies = DefaultDataBrokerOperationDependencies(database: mockDatabase,
                                                                  config: DataBrokerProtectionProcessorConfiguration(),
                                                                  runnerProvider: mockRunnerProvider,
                                                                  notificationCenter: .default,
                                                                  pixelHandler: mockPixelHandler,
                                                                  userNotificationService: mockUserNotification)
    }

    func testWhenStartImmediateScan_andScanCompletesWithErrors_thenCompletionIsCalledWithErrors() async throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater)
        let mockOperations = [1, 2].map { MockDataBrokerOperation(id: $0, operationType: .scan, errorDelegate: sut, shouldSleep: false) }
        let mockOperationsWithError = [3, 4].map { MockDataBrokerOperation(id: $0, operationType: .scan, errorDelegate: sut, shouldError: true, shouldSleep: false) }
        mockOperationsCreator.operationCollections = mockOperations + mockOperationsWithError
        let expectation = expectation(description: "Expected errors to be returned in completion")
        var errorCollection: DataBrokerProtectionSchedulerErrorCollection!
        let expectedConcurrentOperations = DataBrokerProtectionProcessorConfiguration().concurrentOperationsFor(.scan)

        // When
        sut.startImmediateOperationsIfPermitted(showWebView: false,
                                                operationDependencies: mockDependencies) { errors in
            errorCollection = errors
            expectation.fulfill()
        }

        // Then
        await fulfillment(of: [expectation], timeout: 3)
        XCTAssert(errorCollection.operationErrors?.count == 2)
        XCTAssertEqual(mockQueue.maxConcurrentOperationCount, expectedConcurrentOperations)
    }

    func testWhenStartScheduledScan_andScanCompletesWithErrors_thenCompletionIsCalledWithErrors() async throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater)
        let mockOperations = [1, 2].map { MockDataBrokerOperation(id: $0, operationType: .scan, errorDelegate: sut, shouldSleep: false) }
        let mockOperationsWithError = [3, 4].map { MockDataBrokerOperation(id: $0, operationType: .scan, errorDelegate: sut, shouldError: true, shouldSleep: false) }
        mockOperationsCreator.operationCollections = mockOperations + mockOperationsWithError
        let expectation = expectation(description: "Expected errors to be returned in completion")
        var errorCollection: DataBrokerProtectionSchedulerErrorCollection!
        let expectedConcurrentOperations = DataBrokerProtectionProcessorConfiguration().concurrentOperationsFor(.all)

        // When
        sut.startScheduledOperationsIfPermitted(showWebView: false,
                                                operationDependencies: mockDependencies) { errors in
            errorCollection = errors
            expectation.fulfill()
        }

        // Then
        await fulfillment(of: [expectation], timeout: 3)
        XCTAssert(errorCollection.operationErrors?.count == 2)
        XCTAssertEqual(mockQueue.maxConcurrentOperationCount, expectedConcurrentOperations)
    }

    func testWhenStartSecondImmediateScan_andCurrentModeIsImmediate_thenCurrentOperationsAreInterrupted_andCurrentCompletionIsCalledWithErrors() async throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater)
        var mockOperations = (1...5).map { MockDataBrokerOperation(id: $0, operationType: .scan, errorDelegate: sut) }
        let mockOperationsWithError = (6...10).map { MockDataBrokerOperation(id: $0, operationType: .scan, errorDelegate: sut, shouldError: true) }
        mockOperationsCreator.operationCollections = mockOperations + mockOperationsWithError
        var errorCollection: DataBrokerProtectionSchedulerErrorCollection!

        // When
        sut.startImmediateOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { errors in
            errorCollection = errors
        }

        // Then
        XCTAssert(mockQueue.operationCount == 10)

        // Given
        mockOperations = (11...20).map { MockDataBrokerOperation(id: $0, operationType: .scan, errorDelegate: sut) }
        mockOperationsCreator.operationCollections = mockOperations

        // When
        sut.startImmediateOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { _ in }

        // Then
        XCTAssert(errorCollection.operationErrors?.count == 5)
        XCTAssert(mockQueue.didCallCancelCount == 1)
        XCTAssert(mockQueue.operations.filter { !$0.isCancelled }.count == 10)
        XCTAssert(mockQueue.operations.filter { $0.isCancelled }.count >= 0)
    }

    func testWhenStartScheduledScan_andCurrentModeIsImmediate_thenCurrentOperationsAreNotInterrupted_andNewCompletionIsCalledWithZeroErrors() throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater)
        var mockOperations = (1...5).map { MockDataBrokerOperation(id: $0, operationType: .scan, errorDelegate: sut) }
        var mockOperationsWithError = (6...10).map { MockDataBrokerOperation(id: $0, operationType: .scan, errorDelegate: sut, shouldError: true) }
        mockOperationsCreator.operationCollections = mockOperations + mockOperationsWithError
        var errorCollection: DataBrokerProtectionSchedulerErrorCollection!

        // When
        sut.startImmediateOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { _ in }

        // Then
        XCTAssert(mockQueue.operationCount == 10)

        // Given
        mockOperations = (11...15).map { MockDataBrokerOperation(id: $0, operationType: .scan, errorDelegate: sut) }
        mockOperationsWithError = (16...20).map { MockDataBrokerOperation(id: $0, operationType: .scan, errorDelegate: sut, shouldError: true) }
        mockOperationsCreator.operationCollections = mockOperations + mockOperationsWithError
        var completionCalled = false

        // When
        sut.startScheduledOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { errors in
            errorCollection = errors
            completionCalled.toggle()
        }

        // Then
        XCTAssert(mockQueue.didCallCancelCount == 0)
        XCTAssert(mockQueue.operations.filter { !$0.isCancelled }.count == 10)
        XCTAssert(mockQueue.operations.filter { $0.isCancelled }.count == 0)
        XCTAssertNil(errorCollection)
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
        var errorCollection: DataBrokerProtectionSchedulerErrorCollection!

        // When
        sut.startImmediateOperationsIfPermitted(showWebView: false,
                                                operationDependencies: mockDependencies) { errors in
            errorCollection = errors
            expectation.fulfill()
        }

        // Then
        await fulfillment(of: [expectation], timeout: 3)
        XCTAssertNotNil(errorCollection.oneTimeError)
    }

    func testWhenOperationsAreRunning_andStopAllIsCalled_thenAllAreCancelled_andCompletionIsCalledWithErrors() async throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater)
        let mockOperations = (1...5).map { MockDataBrokerOperation(id: $0, operationType: .scan, errorDelegate: sut) }
        let mockOperationsWithError = (6...10).map { MockDataBrokerOperation(id: $0, operationType: .scan, errorDelegate: sut, shouldError: true) }
        mockOperationsCreator.operationCollections = mockOperations + mockOperationsWithError
        let expectation = expectation(description: "Expected completion to be called")
        var errorCollection: DataBrokerProtectionSchedulerErrorCollection!

        // When
        sut.startImmediateOperationsIfPermitted(showWebView: false,
                                                operationDependencies: mockDependencies) { errors in
            errorCollection = errors
            expectation.fulfill()
        }

        sut.stopAllOperations()

        // Then
        await fulfillment(of: [expectation], timeout: 3)
        XCTAssert(errorCollection.operationErrors?.count == 5)
    }

    // Test execute debug
    func testWhenCallDebugOptOutCommand_thenOptOutOperationsAreCreated() throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater)
        let expectedConcurrentOperations = DataBrokerProtectionProcessorConfiguration().concurrentOperationsFor(.optOut)
        XCTAssert(mockOperationsCreator.createdType == .scan)

        // When
        sut.execute(.startOptOutOperations(showWebView: false,
                                           operationDependencies: mockDependencies,
                                           completion: nil))

        // Then
        XCTAssert(mockOperationsCreator.createdType == .optOut)
        XCTAssertEqual(mockQueue.maxConcurrentOperationCount, expectedConcurrentOperations)
    }
}
