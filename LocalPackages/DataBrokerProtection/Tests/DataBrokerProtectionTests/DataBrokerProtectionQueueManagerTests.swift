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
import Common
@testable import DataBrokerProtection

final class DataBrokerProtectionQueueManagerTests: XCTestCase {

    var sut: DefaultDataBrokerProtectionQueueManager!

    func testWhenStartQueuedScan_andCurrentModeIsManual_thenCurrentOperationsAreNotInterrupted() throws {
        // Given
        let mockQueue = MockDataBrokerProtectionOperationQueue()
        var mockOperations = (1...10).map { MockDataBrokerOperationsCollection(id: $0, operationType: .scan) }
        let mockOperationsBuilder = MockDataBrokerOperationsCollectionBuilder(operationCollections: mockOperations)
        let mockDatabase = MockDatabase()
        let mockPixelHandler = MockPixelHandler()
        let mockMismatchCalculator = MockMismatchCalculator(database: mockDatabase, pixelHandler: mockPixelHandler)
        let mockUpdater = MockDataBrokerProtectionBrokerUpdater()
        let mockSchedulerConfig = MockSchedulerConfig()
        let mockRunnerProvider = MockRunnerProvider()
        let mockUserNotification = MockUserNotification()

        let mockDependencies = DefaultOperationDependencies(database: mockDatabase,
                                                            config: mockSchedulerConfig,
                                                            runnerProvider: mockRunnerProvider,
                                                            notificationCenter: .default,
                                                            pixelHandler: mockPixelHandler,
                                                            userNotificationService: mockUserNotification)

        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsBuilder: mockOperationsBuilder,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater)

        // When
        sut.startManualScans(showWebView: false, operationDependencies: mockDependencies) { _ in }

        // Then
        XCTAssert(mockQueue.didCallCancelCount == 1)
        XCTAssert(mockQueue.operationCount == 10)

        mockOperations = (11...20).map { MockDataBrokerOperationsCollection(id: $0, operationType: .scan) }
        mockOperationsBuilder.operationCollections = mockOperations

        sut.runQueuedOperations(showWebView: false, operationDependencies: mockDependencies) { _ in }

        XCTAssert(mockQueue.didCallCancelCount == 1)
        XCTAssert(mockQueue.operationCount == 10)
    }

    func testWhenStartSecondManualScan_andCurrentModeIsManual_thenCurrentOperationsAreInterrupted() throws {
        // Given
        let mockQueue = MockDataBrokerProtectionOperationQueue()
        var mockOperations = (1...10).map { MockDataBrokerOperationsCollection(id: $0, operationType: .scan) }
        let mockOperationsBuilder = MockDataBrokerOperationsCollectionBuilder(operationCollections: mockOperations)
        let mockDatabase = MockDatabase()
        let mockPixelHandler = MockPixelHandler()
        let mockMismatchCalculator = MockMismatchCalculator(database: mockDatabase, pixelHandler: mockPixelHandler)
        let mockUpdater = MockDataBrokerProtectionBrokerUpdater()
        let mockSchedulerConfig = MockSchedulerConfig()
        let mockRunnerProvider = MockRunnerProvider()
        let mockUserNotification = MockUserNotification()

        let mockDependencies = DefaultOperationDependencies(database: mockDatabase,
                                                            config: mockSchedulerConfig,
                                                            runnerProvider: mockRunnerProvider,
                                                            notificationCenter: .default,
                                                            pixelHandler: mockPixelHandler,
                                                            userNotificationService: mockUserNotification)

        sut = DefaultDataBrokerProtectionQueueManager(operationQueue: mockQueue,
                                                      operationsBuilder: mockOperationsBuilder,
                                                      mismatchCalculator: mockMismatchCalculator,
                                                      brokerUpdater: mockUpdater)

        // When
        sut.startManualScans(showWebView: false, operationDependencies: mockDependencies) { _ in }

        // Then
        XCTAssert(mockQueue.didCallCancelCount == 1)
        XCTAssert(mockQueue.operationCount == 10)

        mockOperations = (11...20).map { MockDataBrokerOperationsCollection(id: $0, operationType: .scan) }
        mockOperationsBuilder.operationCollections = mockOperations

        sut.startManualScans(showWebView: false, operationDependencies: mockDependencies) { _ in }

        XCTAssert(mockQueue.didCallCancelCount == 2)
        XCTAssert(mockQueue.operations.filter { !$0.isCancelled }.count == 10)
        XCTAssert(mockQueue.operations.filter { $0.isCancelled }.count >= 0)
    }
}
