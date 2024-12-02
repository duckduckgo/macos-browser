//
//  DataBrokerProtectionCustomStatsProviderTests.swift
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

final class DataBrokerProtectionCustomStatsProviderTests: XCTestCase {

    private var sut = DefaultDataBrokerProtectionCustomOptOutStatsProvider()

    func testWhenNoBrokers() throws {
        // Given
        let queryData: [BrokerProfileQueryData] = []
        let startDate = Date.nowMinus(hours: 48)
        let endDate = Date.nowMinus(hours: 24)
        let expectedAggregateStat = CustomAggregateBrokersStat(optoutSubmitSuccessRate: 0.0)

        // When
        let result = sut.customOptOutStats(startDate: startDate, endDate: endDate, andQueryData: queryData)

        // Then
        XCTAssert(result.customIndividualDataBrokerStat.isEmpty)
        XCTAssertEqual(result.customAggregateBrokersStat, expectedAggregateStat)
    }

    func testWithOneBrokerWithMultipleMatchesAndOptOuts() throws {
        // Given
        let queryData = BrokerProfileQueryData.queryDataWithMultipleSuccessfulOptOutRequestsIn24Hours
        let startDate = Date.nowMinus(hours: 26)
        let endDate = Date.nowMinus(hours: 24)
        let expected = CustomIndividualDataBrokerStat(dataBrokerName: "Test broker", optoutSubmitSuccessRate: 1.0)

        // When
        let result = sut.customOptOutStats(startDate: startDate, endDate: endDate, andQueryData: queryData)

        // Then
        XCTAssertEqual(result.customIndividualDataBrokerStat.count, 1)
        let brokerResult = result.customIndividualDataBrokerStat.first!
        XCTAssertEqual(brokerResult, expected)
        XCTAssertEqual(result.customAggregateBrokersStat.optoutSubmitSuccessRate, 1.0)
    }

    func testWithTwoBrokersEachWith50PercentSuccessRate() throws {
        // Given
        let queryData = BrokerProfileQueryData.queryDataTwoBrokers50PercentSuccessEach
        let startDate = Date.nowMinus(hours: 26)
        let endDate = Date.nowMinus(hours: 24)
        let expectedGlobalRate = 0.5

        // When
        let result = sut.customOptOutStats(startDate: startDate, endDate: endDate, andQueryData: queryData)

        // Then
        XCTAssertEqual(result.customIndividualDataBrokerStat.count, 2)
        XCTAssertEqual(result.customAggregateBrokersStat.optoutSubmitSuccessRate, expectedGlobalRate)
        XCTAssertEqual(result.customIndividualDataBrokerStat[0].optoutSubmitSuccessRate, 0.5)
        XCTAssertEqual(result.customIndividualDataBrokerStat[1].optoutSubmitSuccessRate, 0.5)
    }

    func testWithNoBrokers() throws {
        // Given
        let queryData: [BrokerProfileQueryData] = []
        let startDate = Date.nowMinus(hours: 26)
        let endDate = Date.nowMinus(hours: 24)

        // When
        let result = sut.customOptOutStats(startDate: startDate, endDate: endDate, andQueryData: queryData)

        // Then
        XCTAssertTrue(result.customIndividualDataBrokerStat.isEmpty)
        XCTAssertEqual(result.customAggregateBrokersStat.optoutSubmitSuccessRate, 0.0)
    }

    func testWithOneBrokerNoOptOutsWithinDateRange() throws {
        // Given
        let queryData = BrokerProfileQueryData.queryDataWithNoOptOutsInDateRange
        let startDate = Date.nowMinus(hours: 26)
        let endDate = Date.nowMinus(hours: 24)

        // When
        let result = sut.customOptOutStats(startDate: startDate, endDate: endDate, andQueryData: queryData)

        // Then
        XCTAssertTrue(result.customIndividualDataBrokerStat.isEmpty)
        XCTAssertEqual(result.customAggregateBrokersStat.optoutSubmitSuccessRate, 0.0)
    }

    func testWithMultipleBrokersVaryingSuccessRates() throws {
        // Given
        let queryData = BrokerProfileQueryData.queryDataMultipleBrokersVaryingSuccessRates
        let startDate = Date.nowMinus(hours: 26)
        let endDate = Date.nowMinus(hours: 24)

        // When
        let result = sut.customOptOutStats(startDate: startDate, endDate: endDate, andQueryData: queryData)

        // Then
        XCTAssertEqual(result.customIndividualDataBrokerStat.count, 3)
        let sortedBrokerStats = result.customIndividualDataBrokerStat.sorted { $0.optoutSubmitSuccessRate < $1.optoutSubmitSuccessRate }
        XCTAssertEqual(sortedBrokerStats[0].optoutSubmitSuccessRate, 0.5)
        XCTAssertEqual(sortedBrokerStats[1].optoutSubmitSuccessRate, 0.75)
        XCTAssertEqual(sortedBrokerStats[2].optoutSubmitSuccessRate, 1.0)
        XCTAssertEqual(result.customAggregateBrokersStat.optoutSubmitSuccessRate, 0.71)
    }

    func testWithStartDateLaterThanEndDate() throws {
        // Given
        let queryData = BrokerProfileQueryData.queryDataTwoBrokers50PercentSuccessEach
        let startDate = Date.nowMinus(hours: 24)
        let endDate = Date.nowMinus(hours: 26)

        // When
        let result = sut.customOptOutStats(startDate: startDate, endDate: endDate, andQueryData: queryData)

        // Then
        XCTAssertTrue(result.customIndividualDataBrokerStat.isEmpty)
        XCTAssertEqual(result.customAggregateBrokersStat.optoutSubmitSuccessRate, 0.0)
    }
}
