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
    private var mockOperationsBuilder: MockDataBrokerOperationsBuilder!
    private var mockDatabase: MockDatabase!
    private var mockPixelHandler: MockPixelHandler!
    private var mockMismatchCalculator: MockMismatchCalculator!
    private var mockUpdater: MockDataBrokerProtectionBrokerUpdater!
    private var mockSchedulerConfig: MockSchedulerConfig!
    private var mockRunnerProvider: MockRunnerProvider!
    private var mockUserNotification: MockUserNotification!
    private var mockDependencies: DefaultDataBrokerOperationDependencies!

    override func setUpWithError() throws {
        mockQueue = MockDataBrokerProtectionOperationQueue()
        mockOperations = (1...10).map { MockDataBrokerOperation(id: $0, operationType: .scan) }
        mockOperationsBuilder = MockDataBrokerOperationsBuilder(operationCollections: mockOperations)
        mockDatabase = MockDatabase()
        mockPixelHandler = MockPixelHandler()
        mockMismatchCalculator = MockMismatchCalculator(database: mockDatabase, pixelHandler: mockPixelHandler)
        mockUpdater = MockDataBrokerProtectionBrokerUpdater()
        mockSchedulerConfig = MockSchedulerConfig()
        mockRunnerProvider = MockRunnerProvider()
        mockUserNotification = MockUserNotification()

        mockDependencies = DefaultDataBrokerOperationDependencies(database: mockDatabase,
                                                                  brokerTimeInterval: 3,
                                                                  runnerProvider: mockRunnerProvider,
                                                                  notificationCenter: .default,
                                                                  pixelHandler: mockPixelHandler,
                                                                  userNotificationService: mockUserNotification)
    }

    func testWhenStartScheduledScan_andCurrentModeIsImmediate_thenCurrentOperationsAreNotInterrupted_andScheduledCompletionIsCalled() throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsBuilder: mockOperationsBuilder,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater)

        // When
        sut.startImmediateOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { _ in }

        // Then
        XCTAssert(mockQueue.operationCount == 10)

        // Given
        mockOperations = (11...20).map { MockDataBrokerOperation(id: $0, operationType: .scan) }
        mockOperationsBuilder.operationCollections = mockOperations

        // When
        var completionCalled = false
        sut.startScheduledOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { _ in
            completionCalled.toggle()
        }

        // Then
        XCTAssert(mockQueue.operationCount == 10)
        XCTAssert(completionCalled)
    }

    func testWhenStartSecondImmediateScan_andCurrentModeIsImmediate_thenCurrentOperationsAreInterrupted_andCurrentImmediateCompletionIsCalled() throws {
        // Given
        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsBuilder: mockOperationsBuilder,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater)

        // When
        var completionCalled = false
        sut.startImmediateOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { _ in
            completionCalled.toggle()
        }

        // Then
        XCTAssert(mockQueue.operationCount == 10)

        // Given
        mockOperations = (11...20).map { MockDataBrokerOperation(id: $0, operationType: .scan) }
        mockOperationsBuilder.operationCollections = mockOperations

        // When
        sut.startImmediateOperationsIfPermitted(showWebView: false, operationDependencies: mockDependencies) { _ in }

        // Then
        XCTAssert(mockQueue.didCallCancelCount == 1)
        XCTAssert(completionCalled)
        XCTAssert(mockQueue.operations.filter { !$0.isCancelled }.count == 10)
        XCTAssert(mockQueue.operations.filter { $0.isCancelled }.count >= 0)
    }

    func testWhenScanCompletes_thenCompletionIsCalledOnceInBarrierBlock() throws {

    }

    func testWhenOperationBuildingFails_thenCompletionIsCalledOnError() throws {

    }

    // Test stop all

    // Test execute debug
}
