//
//  DataBrokerOperationTests.swift
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

final class DataBrokerOperationTests: XCTestCase {
    lazy var mockOptOutQueryData: [BrokerProfileQueryData] = {
        let brokerId: Int64 = 1

        let mockNilPreferredRunDateQueryData = Array(1...10).map {
            BrokerProfileQueryData.mock(preferredRunDate: nil, optOutJobData: [BrokerProfileQueryData.createOptOutJobData(extractedProfileId: Int64($0), brokerId: brokerId, profileQueryId: Int64($0), preferredRunDate: nil)])
        }
        let mockPastQueryData = Array(1...10).map {
            BrokerProfileQueryData.mock(preferredRunDate: .nowMinus(hours: $0), optOutJobData: [BrokerProfileQueryData.createOptOutJobData(extractedProfileId: Int64($0), brokerId: brokerId, profileQueryId: Int64($0), preferredRunDate: .nowMinus(hours: $0))])
        }
        let mockFutureQueryData = Array(1...10).map {
            BrokerProfileQueryData.mock(preferredRunDate: .nowPlus(hours: $0), optOutJobData: [BrokerProfileQueryData.createOptOutJobData(extractedProfileId: Int64($0), brokerId: brokerId, profileQueryId: Int64($0), preferredRunDate: .nowPlus(hours: $0))])
        }

        return mockNilPreferredRunDateQueryData + mockPastQueryData + mockFutureQueryData
    }()

    lazy var mockScanQueryData: [BrokerProfileQueryData] = {
        let mockNilPreferredRunDateQueryData = Array(1...10).map { _ in
            BrokerProfileQueryData.mock(preferredRunDate: nil)
        }
        let mockPastQueryData = Array(1...10).map {
            BrokerProfileQueryData.mock(preferredRunDate: .nowMinus(hours: $0))
        }
        let mockFutureQueryData = Array(1...10).map {
            BrokerProfileQueryData.mock(preferredRunDate: .nowPlus(hours: $0))
        }

        return mockNilPreferredRunDateQueryData + mockPastQueryData + mockFutureQueryData
    }()

    func testWhenFilteringOptOutOperationData_thenAllButFuturePreferredRunDateIsReturned() {
        let operationData1 = MockDataBrokerOperation.filterAndSortOperationsData(brokerProfileQueriesData: mockOptOutQueryData, operationType: .optOut, priorityDate: nil)
        let operationData2 = MockDataBrokerOperation.filterAndSortOperationsData(brokerProfileQueriesData: mockOptOutQueryData, operationType: .optOut, priorityDate: .now)
        let operationData3 = MockDataBrokerOperation.filterAndSortOperationsData(brokerProfileQueriesData: mockOptOutQueryData, operationType: .optOut, priorityDate: .distantPast)
        let operationData4 = MockDataBrokerOperation.filterAndSortOperationsData(brokerProfileQueriesData: mockOptOutQueryData, operationType: .optOut, priorityDate: .distantFuture)

        XCTAssertEqual(operationData1.count, 30) // all jobs
        XCTAssertEqual(operationData2.count, 20) // nil preferred run date + past jobs
        XCTAssertEqual(operationData3.count, 10) // nil preferred run date jobs
        XCTAssertEqual(operationData4.count, 30) // all jobs
    }

    func testWhenFilteringScanOperationData_thenPreferredRunDatePriorToPriorityDateIsReturned() {
        let operationData1 = MockDataBrokerOperation.filterAndSortOperationsData(brokerProfileQueriesData: mockScanQueryData, operationType: .scheduledScan, priorityDate: nil)
        let operationData2 = MockDataBrokerOperation.filterAndSortOperationsData(brokerProfileQueriesData: mockScanQueryData, operationType: .manualScan, priorityDate: .now)
        let operationData3 = MockDataBrokerOperation.filterAndSortOperationsData(brokerProfileQueriesData: mockScanQueryData, operationType: .scheduledScan, priorityDate: .distantPast)
        let operationData4 = MockDataBrokerOperation.filterAndSortOperationsData(brokerProfileQueriesData: mockScanQueryData, operationType: .manualScan, priorityDate: .distantFuture)

        XCTAssertEqual(operationData1.count, 30) // all jobs
        XCTAssertEqual(operationData2.count, 10) // past jobs
        XCTAssertEqual(operationData3.count, 0) // no jobs
        XCTAssertEqual(operationData4.count, 20) // past + future jobs
    }

    func testFilteringAllOperationData() {
        let operationData1 = MockDataBrokerOperation.filterAndSortOperationsData(brokerProfileQueriesData: mockOptOutQueryData, operationType: .all, priorityDate: nil)
        let operationData2 = MockDataBrokerOperation.filterAndSortOperationsData(brokerProfileQueriesData: mockOptOutQueryData, operationType: .all, priorityDate: .now)
        let operationData3 = MockDataBrokerOperation.filterAndSortOperationsData(brokerProfileQueriesData: mockOptOutQueryData, operationType: .all, priorityDate: .distantPast)
        let operationData4 = MockDataBrokerOperation.filterAndSortOperationsData(brokerProfileQueriesData: mockOptOutQueryData, operationType: .all, priorityDate: .distantFuture)

        XCTAssertEqual(operationData1.filter { $0 is ScanJobData }.count, 30) // all jobs
        XCTAssertEqual(operationData1.filter { $0 is OptOutJobData }.count, 30) // all jobs
        XCTAssertEqual(operationData1.count, 30+30)

        XCTAssertEqual(operationData2.filter { $0 is ScanJobData }.count, 10) // past jobs
        XCTAssertEqual(operationData2.filter { $0 is OptOutJobData }.count, 20) // nil preferred run date + past jobs
        XCTAssertEqual(operationData2.count, 10+20)

        XCTAssertEqual(operationData3.filter { $0 is ScanJobData }.count, 0) // no jobs
        XCTAssertEqual(operationData3.filter { $0 is OptOutJobData }.count, 10) // nil preferred run date jobs
        XCTAssertEqual(operationData3.count, 0+10)

        XCTAssertEqual(operationData4.filter { $0 is ScanJobData }.count, 20) // past + future jobs
        XCTAssertEqual(operationData4.filter { $0 is OptOutJobData }.count, 30) // all jobs
        XCTAssertEqual(operationData4.count, 20+30)
    }
}
