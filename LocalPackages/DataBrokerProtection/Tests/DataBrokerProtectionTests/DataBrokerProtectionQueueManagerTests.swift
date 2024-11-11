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
    private var mockSchedulerConfig = DataBrokerExecutionConfig(mode: .normal)
    private var mockRunnerProvider: MockRunnerProvider!
    private var mockUserNotification: MockUserNotificationService!
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
        mockUserNotification = MockUserNotificationService()

        mockDependencies = DefaultDataBrokerOperationDependencies(database: mockDatabase,
                                                                  config: DataBrokerExecutionConfig(mode: .normal),
                                                                  runnerProvider: mockRunnerProvider,
                                                                  notificationCenter: .default,
                                                                  pixelHandler: mockPixelHandler,
                                                                  userNotificationService: mockUserNotification)
    }

    func testWhenStartImmediateScanOperations_thenCreatorIsCalledWithManualScanOperationType() async throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater,
                                                      pixelHandler: mockPixelHandler)

        // When
        sut.startImmediateScanOperationsIfPermitted(showWebView: false,
                                                operationDependencies: mockDependencies,
                                                    errorHandler: nil,
                                                   completion: nil)

        // Then
        XCTAssertEqual(mockOperationsCreator.createdType, .manualScan)
    }

    func testWhenStartScheduledAllOperations_thenCreatorIsCalledWithAllOperationType() async throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater,
                                                      pixelHandler: mockPixelHandler)

        // When
        sut.startScheduledAllOperationsIfPermitted(showWebView: false,
                                                operationDependencies: mockDependencies,
                                                   errorHandler: nil,
                                                   completion: nil)

        // Then
        XCTAssertEqual(mockOperationsCreator.createdType, .all)
    }

    func testWhenStartScheduledScanOperations_thenCreatorIsCalledWithScheduledScanOperationType() async throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater,
                                                      pixelHandler: mockPixelHandler)

        // When
        sut.startScheduledScanOperationsIfPermitted(showWebView: false,
                                                operationDependencies: mockDependencies,
                                                    errorHandler: nil,
                                                   completion: nil)

        // Then
        XCTAssertEqual(mockOperationsCreator.createdType, .scheduledScan)
    }

    func testWhenStartImmediateScan_andScanCompletesWithErrors_thenCompletionIsCalledWithErrors() async throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater,
                                                      pixelHandler: mockPixelHandler)
        let mockOperation = MockDataBrokerOperation(id: 1, operationType: .manualScan, errorDelegate: sut)
        let mockOperationWithError = MockDataBrokerOperation(id: 2, operationType: .manualScan, errorDelegate: sut, shouldError: true)
        mockOperationsCreator.operationCollections = [mockOperation, mockOperationWithError]
        let expectation = expectation(description: "Expected completion to be called")
        var errorCollection: DataBrokerProtectionAgentErrorCollection!
        let expectedConcurrentOperations = DataBrokerExecutionConfig(mode: .normal).concurrentOperationsFor(.manualScan)
        var errorHandlerCalled = false

        // When
        sut.startImmediateScanOperationsIfPermitted(showWebView: false,
                                                operationDependencies: mockDependencies) { errors in
            errorCollection = errors
            errorHandlerCalled = true
        } completion: {
            XCTAssertTrue(errorHandlerCalled)
            expectation.fulfill()
        }

        mockQueue.completeAllOperations()

        // Then
        await fulfillment(of: [expectation], timeout: 5)
        XCTAssert(errorCollection.operationErrors?.count == 1)
        XCTAssertNil(mockOperationsCreator.priorityDate)
        XCTAssertEqual(mockQueue.maxConcurrentOperationCount, expectedConcurrentOperations)
    }

    func testWhenStartScheduledAllOperations_andOperationsCompleteWithErrors_thenErrorHandlerIsCalledWithErrors_followedByCompletionBlock() async throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater,
                                                      pixelHandler: mockPixelHandler)
        let mockOperation = MockDataBrokerOperation(id: 1, operationType: .all, errorDelegate: sut)
        let mockOperationWithError = MockDataBrokerOperation(id: 2, operationType: .all, errorDelegate: sut, shouldError: true)
        mockOperationsCreator.operationCollections = [mockOperation, mockOperationWithError]
        let expectation = expectation(description: "Expected completion to be called")
        var errorCollection: DataBrokerProtectionAgentErrorCollection!
        let expectedConcurrentOperations = DataBrokerExecutionConfig(mode: .normal).concurrentOperationsFor(.all)
        var errorHandlerCalled = false

        // When
        sut.startScheduledAllOperationsIfPermitted(showWebView: false,
                                                operationDependencies: mockDependencies) { errors in
            errorCollection = errors
            errorHandlerCalled = true
        } completion: {
            XCTAssertTrue(errorHandlerCalled)
            expectation.fulfill()
        }

        mockQueue.completeAllOperations()

        // Then
        await fulfillment(of: [expectation], timeout: 5)
        XCTAssert(errorCollection.operationErrors?.count == 1)
        XCTAssertNotNil(mockOperationsCreator.priorityDate)
        XCTAssertEqual(mockQueue.maxConcurrentOperationCount, expectedConcurrentOperations)
    }

    func testWhenStartScheduledScanOperations_andOperationsCompleteWithErrors_thenCompletionIsCalledWithErrors() async throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater,
                                                      pixelHandler: mockPixelHandler)
        let mockOperation = MockDataBrokerOperation(id: 1, operationType: .scheduledScan, errorDelegate: sut)
        let mockOperationWithError = MockDataBrokerOperation(id: 2, operationType: .scheduledScan, errorDelegate: sut, shouldError: true)
        mockOperationsCreator.operationCollections = [mockOperation, mockOperationWithError]
        let expectation = expectation(description: "Expected errors to be returned in completion")
        var errorCollection: DataBrokerProtectionAgentErrorCollection!
        let expectedConcurrentOperations = DataBrokerExecutionConfig(mode: .normal).concurrentOperationsFor(.scheduledScan)
        var errorHandlerCalled = false

        // When
        sut.startScheduledScanOperationsIfPermitted(showWebView: false,
                                                operationDependencies: mockDependencies) { errors in
            errorCollection = errors
            errorHandlerCalled = true
        } completion: {
            XCTAssertTrue(errorHandlerCalled)
            expectation.fulfill()
        }

        mockQueue.completeAllOperations()

        // Then
        await fulfillment(of: [expectation], timeout: 5)
        XCTAssert(errorCollection.operationErrors?.count == 1)
        XCTAssertNotNil(mockOperationsCreator.priorityDate)
        XCTAssertEqual(mockQueue.maxConcurrentOperationCount, expectedConcurrentOperations)
    }

    func testWhenStartImmediateScan_andCurrentModeIsScheduled_thenCurrentOperationsAreInterrupted_andCurrentCompletionIsCalledWithErrors() async throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater,
                                                      pixelHandler: mockPixelHandler)
        let mockOperationsWithError = (1...2).map { MockDataBrokerOperation(id: $0, operationType: .manualScan, errorDelegate: sut, shouldError: true) }
        var mockOperations = (3...4).map { MockDataBrokerOperation(id: $0, operationType: .manualScan, errorDelegate: sut) }
        mockOperationsCreator.operationCollections = mockOperationsWithError + mockOperations
        var errorCollection: DataBrokerProtectionAgentErrorCollection!

        // When
        sut.startScheduledAllOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { errors in
            errorCollection = errors
        } completion: {
            // no-op
        }

        mockQueue.completeOperationsUpTo(index: 2)

        // Then
        XCTAssert(mockQueue.operationCount == 2)

        // Given
        mockOperations = (5...8).map { MockDataBrokerOperation(id: $0, operationType: .manualScan, errorDelegate: sut) }
        mockOperationsCreator.operationCollections = mockOperations

        // When
        sut.startImmediateScanOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { _ in
        } completion: {
            // no-op
        }

        // Then
        XCTAssert(errorCollection.operationErrors?.count == 2)
        let error = errorCollection.oneTimeError as? DataBrokerProtectionQueueError
        XCTAssertEqual(error, .interrupted)
        XCTAssert(mockQueue.didCallCancelCount == 1)
        XCTAssert(mockQueue.operations.filter { !$0.isCancelled }.count == 4)
        XCTAssert(mockQueue.operations.filter { $0.isCancelled }.count >= 2)
    }

    func testWhenStartImmediateScan_andCurrentModeIsImmediate_thenCurrentOperationsAreInterrupted_andCurrentCompletionIsCalledWithErrors() async throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater,
                                                      pixelHandler: mockPixelHandler)
        let mockOperationsWithError = (1...2).map { MockDataBrokerOperation(id: $0, operationType: .manualScan, errorDelegate: sut, shouldError: true) }
        var mockOperations = (3...4).map { MockDataBrokerOperation(id: $0, operationType: .manualScan, errorDelegate: sut) }
        mockOperationsCreator.operationCollections = mockOperationsWithError + mockOperations
        var errorCollection: DataBrokerProtectionAgentErrorCollection!

        // When
        sut.startImmediateScanOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { errors in
            errorCollection = errors
        } completion: {
            // no-op
        }

        mockQueue.completeOperationsUpTo(index: 2)

        // Then
        XCTAssert(mockQueue.operationCount == 2)

        // Given
        mockOperations = (5...8).map { MockDataBrokerOperation(id: $0, operationType: .manualScan, errorDelegate: sut) }
        mockOperationsCreator.operationCollections = mockOperations

        // When
        sut.startImmediateScanOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { _ in
        } completion: {
            // no-op
        }

        // Then
        XCTAssert(errorCollection.operationErrors?.count == 2)
        let error = errorCollection.oneTimeError as? DataBrokerProtectionQueueError
        XCTAssertEqual(error, .interrupted)
        XCTAssert(mockQueue.didCallCancelCount == 1)
        XCTAssert(mockQueue.operations.filter { !$0.isCancelled }.count == 4)
        XCTAssert(mockQueue.operations.filter { $0.isCancelled }.count >= 2)
    }

    func testWhenSecondImmedateScanInterruptsFirst_andFirstHadErrors_thenSecondCompletesOnlyWithNewErrors() async throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater,
                                                      pixelHandler: mockPixelHandler)
        var mockOperationsWithError = (1...2).map { MockDataBrokerOperation(id: $0, operationType: .manualScan, errorDelegate: sut, shouldError: true) }
        var mockOperations = (3...4).map { MockDataBrokerOperation(id: $0, operationType: .manualScan, errorDelegate: sut) }
        mockOperationsCreator.operationCollections = mockOperationsWithError + mockOperations
        var errorCollectionFirst: DataBrokerProtectionAgentErrorCollection!

        // When
        sut.startImmediateScanOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { errors in
            errorCollectionFirst = errors
        } completion: {
            // no-op
        }

        mockQueue.completeOperationsUpTo(index: 2)

        // Then
        XCTAssert(mockQueue.operationCount == 2)

        // Given
        var errorCollectionSecond: DataBrokerProtectionAgentErrorCollection!
        mockOperationsWithError = (5...6).map { MockDataBrokerOperation(id: $0, operationType: .manualScan, errorDelegate: sut, shouldError: true) }
        mockOperations = (7...8).map { MockDataBrokerOperation(id: $0, operationType: .manualScan, errorDelegate: sut) }
        mockOperationsCreator.operationCollections = mockOperationsWithError + mockOperations

        // When
        sut.startImmediateScanOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { errors in
            errorCollectionSecond = errors
        } completion: {
            // no-op
        }

        mockQueue.completeAllOperations()

        // Then
        XCTAssert(errorCollectionFirst.operationErrors?.count == 2)
        XCTAssert(errorCollectionSecond.operationErrors?.count == 2)
        XCTAssert(mockQueue.didCallCancelCount == 1)
    }

    func testWhenStartScheduledAllOperations_andCurrentModeIsImmediate_thenCurrentOperationsAreNotInterrupted_andNewCompletionIsCalledWithError() throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater,
                                                      pixelHandler: mockPixelHandler)
        var mockOperations = (1...5).map { MockDataBrokerOperation(id: $0, operationType: .manualScan, errorDelegate: sut) }
        var mockOperationsWithError = (6...10).map { MockDataBrokerOperation(id: $0,
                                                                             operationType: .manualScan,
                                                                             errorDelegate: sut,
                                                                             shouldError: true) }
        mockOperationsCreator.operationCollections = mockOperations + mockOperationsWithError
        var errorCollection: DataBrokerProtectionAgentErrorCollection!

        // When
        sut.startImmediateScanOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { _ in
        } completion: {
            // no-op
        }

        // Then
        XCTAssert(mockQueue.operationCount == 10)

        // Given
        mockOperations = (11...15).map { MockDataBrokerOperation(id: $0, operationType: .manualScan, errorDelegate: sut) }
        mockOperationsWithError = (16...20).map { MockDataBrokerOperation(id: $0,
                                                                          operationType: .manualScan,
                                                                          errorDelegate: sut,
                                                                          shouldError: true) }
        mockOperationsCreator.operationCollections = mockOperations + mockOperationsWithError
        let expectedError = DataBrokerProtectionQueueError.cannotInterrupt
        var completionCalled = false

        // When
        sut.startScheduledAllOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { errors in
            errorCollection = errors
            completionCalled.toggle()
        } completion: {
            // no-op
        }

        // Then
        XCTAssert(mockQueue.didCallCancelCount == 0)
        XCTAssert(mockQueue.operations.filter { !$0.isCancelled }.count == 10)
        XCTAssert(mockQueue.operations.filter { $0.isCancelled }.count == 0)
        XCTAssertEqual((errorCollection.oneTimeError as? DataBrokerProtectionQueueError), expectedError)
        XCTAssert(completionCalled)
    }

    func testWhenStartScheduledScanOperations_andCurrentModeIsImmediate_thenCurrentOperationsAreNotInterrupted_andNewCompletionIsCalledWithError() throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater,
                                                      pixelHandler: mockPixelHandler)
        var mockOperations = (1...5).map { MockDataBrokerOperation(id: $0, operationType: .manualScan, errorDelegate: sut) }
        var mockOperationsWithError = (6...10).map { MockDataBrokerOperation(id: $0,
                                                                             operationType: .manualScan,
                                                                             errorDelegate: sut,
                                                                             shouldError: true) }
        mockOperationsCreator.operationCollections = mockOperations + mockOperationsWithError
        var errorCollection: DataBrokerProtectionAgentErrorCollection!

        // When
        sut.startImmediateScanOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { _ in } completion: {
            // no-op
        }

        // Then
        XCTAssert(mockQueue.operationCount == 10)

        // Given
        mockOperations = (11...15).map { MockDataBrokerOperation(id: $0, operationType: .manualScan, errorDelegate: sut) }
        mockOperationsWithError = (16...20).map { MockDataBrokerOperation(id: $0,
                                                                          operationType: .manualScan,
                                                                          errorDelegate: sut,
                                                                          shouldError: true) }
        mockOperationsCreator.operationCollections = mockOperations + mockOperationsWithError
        let expectedError = DataBrokerProtectionQueueError.cannotInterrupt
        var completionCalled = false

        // When
        sut.startScheduledScanOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { errors in
            errorCollection = errors
        } completion: {
            completionCalled.toggle()
        }

        // Then
        XCTAssert(mockQueue.didCallCancelCount == 0)
        XCTAssert(mockQueue.operations.filter { !$0.isCancelled }.count == 10)
        XCTAssert(mockQueue.operations.filter { $0.isCancelled }.count == 0)
        XCTAssertEqual((errorCollection.oneTimeError as? DataBrokerProtectionQueueError), expectedError)
        XCTAssert(completionCalled)
    }

    func testWhenOperationBuildingFails_thenCompletionIsCalledOnOperationCreationOneTimeError() async throws {
        // Given
        mockOperationsCreator.shouldError = true
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater,
                                                      pixelHandler: mockPixelHandler)
        let expectation = expectation(description: "Expected completion to be called")
        var errorCollection: DataBrokerProtectionAgentErrorCollection!

        // When
        sut.startImmediateScanOperationsIfPermitted(showWebView: false,
                                                operationDependencies: mockDependencies) { errors in
            errorCollection = errors
        } completion: {
            expectation.fulfill()
        }

        // Then
        await fulfillment(of: [expectation], timeout: 3)
        XCTAssertNotNil(errorCollection.oneTimeError)
    }

    func testWhenCallDebugOptOutCommand_thenOptOutOperationsAreCreated() throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsCreator: mockOperationsCreator,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater,
                                                      pixelHandler: mockPixelHandler)
        let expectedConcurrentOperations = DataBrokerExecutionConfig(mode: .normal).concurrentOperationsFor(.optOut)
        XCTAssert(mockOperationsCreator.createdType == .manualScan)

        // When
        sut.execute(.startOptOutOperations(showWebView: false,
                                           operationDependencies: mockDependencies,
                                           errorHandler: nil,
                                           completion: nil))

        // Then
        XCTAssert(mockOperationsCreator.createdType == .optOut)
        XCTAssertEqual(mockQueue.maxConcurrentOperationCount, expectedConcurrentOperations)
    }
}
