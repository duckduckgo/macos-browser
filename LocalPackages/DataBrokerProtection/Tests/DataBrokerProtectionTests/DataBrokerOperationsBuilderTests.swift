//
//  DataBrokerOperationsBuilderTests.swift
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

@testable import DataBrokerProtection
import XCTest

final class DataBrokerOperationsBuilderTests: XCTestCase {

    private let sut: DataBrokerOperationsBuilder = DefaultDataBrokerOperationsBuilder()

    // Dependencies
    private var mockDatabase: MockDatabase!
    private var mockSchedulerConfig: MockSchedulerConfig!
    private var mockRunnerProvider: MockRunnerProvider!
    private var mockPixelHandler: MockPixelHandler!
    private var mockUserNotification: MockUserNotification!
    var mockDependencies: DefaultDataBrokerOperationDependencies!

    override func setUpWithError() throws {
        mockDatabase = MockDatabase()
        mockSchedulerConfig = MockSchedulerConfig()
        mockRunnerProvider = MockRunnerProvider()
        mockPixelHandler = MockPixelHandler()
        mockUserNotification = MockUserNotification()

        mockDependencies = DefaultDataBrokerOperationDependencies(database: mockDatabase,
                                                        brokerTimeInterval: mockSchedulerConfig.intervalBetweenSameBrokerOperations,
                                                        runnerProvider: mockRunnerProvider,
                                                        notificationCenter: .default,
                                                        pixelHandler: mockPixelHandler,
                                                        userNotificationService: mockUserNotification)
    }

    func testWhenBuildOperations_andBrokerQueryDataHasDuplicateBrokers_thenDuplicatesAreIgnored() throws {
        // Given
        let dataBrokerProfileQueries: [BrokerProfileQueryData] = [
            .init(dataBroker: .mock(withId: 1),
                  profileQuery: .mock,
                  scanJobData: .mock(withBrokerId: 1)),
            .init(dataBroker: .mock(withId: 1),
                  profileQuery: .mock,
                  scanJobData: .mock(withBrokerId: 1)),
            .init(dataBroker: .mock(withId: 2),
                  profileQuery: .mock,
                  scanJobData: .mock(withBrokerId: 2)),
            .init(dataBroker: .mock(withId: 2),
                  profileQuery: .mock,
                  scanJobData: .mock(withBrokerId: 2)),
            .init(dataBroker: .mock(withId: 2),
                  profileQuery: .mock,
                  scanJobData: .mock(withBrokerId: 2)),
            .init(dataBroker: .mock(withId: 3),
                  profileQuery: .mock,
                  scanJobData: .mock(withBrokerId: 2)),
        ]
        mockDatabase.brokerProfileQueryDataToReturn = dataBrokerProfileQueries

        // When
        let result = try! sut.operations(operationType: .manualScan, priorityDate: Date(), showWebView: false, operationDependencies: mockDependencies)

        // Then
        XCTAssert(result.count == 3)
    }
}
