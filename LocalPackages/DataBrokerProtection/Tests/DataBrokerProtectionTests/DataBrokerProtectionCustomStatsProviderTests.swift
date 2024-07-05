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

    private var sut = DefaultDataBrokerProtectionCustomStatsProvider()

    func testWhenNoBrokers_thenCustomStatsAreEmpty() throws {
        // Given
        let queryData: [BrokerProfileQueryData] = []
        let startDate = Date.nowMinus(hours: 48)
        let endDate = Date.nowMinus(hours: 24)
        let expectedGlobalStat = CustomGlobalStat(optoutSubmitSuccessRate: 0.0)

        // When
        let result = sut.customStats(startDate: startDate, endDate: endDate, andQueryData: queryData)

        // Then
        XCTAssert(result.customDataBrokerStats.isEmpty)
        XCTAssertEqual(result.customGlobalStat, expectedGlobalStat)
    }

    func testWhenOneBrokerWithMultipleMatchesAndOptOuts_thenCustomStatsAreCorrect() throws {
        // Given
        let queryData = BrokerProfileQueryData.queryDataOneBrokerMultipleMatchesAndOptOuts
        let startDate = Date.nowMinus(hours: 72)
        let endDate = Date.nowMinus(hours: 24)
        let expected = CustomDataBrokerStat(dataBrokerName: "CustomStats Broker 1", optoutSubmitSuccessRate: 0.67)

        // When
        let result = sut.customStats(startDate: startDate, endDate: endDate, andQueryData: queryData)

        // Then
        let brokerOneResult = result.customDataBrokerStats.first { $0.dataBrokerName == "CustomStats Broker 1" }!
        XCTAssertEqual(result.customDataBrokerStats.count, 1)
        XCTAssertEqual(result.customGlobalStat.optoutSubmitSuccessRate, 0.67)
        XCTAssertEqual(expected, brokerOneResult)
    }

    func testWhenTwoBrokers_andOneBrokerHasOneMatchFromOneProfile_thenCustomStatsAreCorrect() throws {
        // Given
        let queryData = BrokerProfileQueryData.queryDataTwoBrokersOneBroker100PercentSuccess
        let startDate = Date.nowMinus(hours: 28)
        let endDate = Date.nowMinus(hours: 24)
        let expected = CustomDataBrokerStat(dataBrokerName: "CustomStats Broker 2", optoutSubmitSuccessRate: 1.0)

        // When
        let result = sut.customStats(startDate: startDate, endDate: endDate, andQueryData: queryData)

        // Then
        let brokerOneResult = result.customDataBrokerStats.first { $0.dataBrokerName == "CustomStats Broker 2" }!
        let brokersWithZeroSuccess = result.customDataBrokerStats.filter { $0.optoutSubmitSuccessRate == 0.0 }
        XCTAssert(result.customDataBrokerStats.count == 2)
        XCTAssert(brokersWithZeroSuccess.count == 1)
        XCTAssertEqual(result.customGlobalStat.optoutSubmitSuccessRate, 0.5)
        XCTAssertEqual(expected, brokerOneResult)
    }

    func testWhenManyBrokers_andOneBrokerHasOneMatchFromTwoProfiles_thenCustomStatsAreCorrect() throws {
        // Given
        let queryData = BrokerProfileQueryData.queryDataManyBrokersOneBroker50PercentSuccess
        let startDate = Date.nowMinus(hours: 48)
        let endDate = Date.nowMinus(hours: 24)
        let expected = CustomDataBrokerStat(dataBrokerName: "CustomStats Broker 1", optoutSubmitSuccessRate: 0.50)

        // When
        let result = sut.customStats(startDate: startDate, endDate: endDate, andQueryData: queryData)

        // Then
        let brokerOneResult = result.customDataBrokerStats.first { $0.dataBrokerName == "CustomStats Broker 1" }!
        let brokersWithZeroSuccess = result.customDataBrokerStats.filter { $0.optoutSubmitSuccessRate == 0.0 }
        XCTAssert(result.customDataBrokerStats.count == 4)
        XCTAssert(brokersWithZeroSuccess.count == 3)
        XCTAssertEqual(result.customGlobalStat.optoutSubmitSuccessRate, 0.2)
        XCTAssertEqual(expected, brokerOneResult)
    }

    func testWhenSomeBrokersHaveNoMatches_thenTheyAreExcludedFromStats() throws {
        // Given
        let queryData = BrokerProfileQueryData.queryDataTwoBrokersOneWithNoMatches
        let startDate = Date.nowMinus(hours: 28)
        let endDate = Date.nowMinus(hours: 24)
        let expected = CustomDataBrokerStat(dataBrokerName: "CustomStats Broker 1", optoutSubmitSuccessRate: 1.0)

        // When
        let result = sut.customStats(startDate: startDate, endDate: endDate, andQueryData: queryData)

        // Then
        XCTAssert(result.customDataBrokerStats.count == 1)
        XCTAssertEqual(result.customGlobalStat.optoutSubmitSuccessRate, 1)
        XCTAssertEqual(expected, result.customDataBrokerStats.first!)
    }

    func testWhenBrokersWithOverlappingDateRanges_thenCustomStatsAreCorrect() throws {
        // Given
        let queryData = BrokerProfileQueryData.queryDataOverlappingDateRanges
        let startDate = Date.nowMinus(hours: 48)
        let endDate = Date.nowMinus(hours: 24)
        let expectedBroker1 = CustomDataBrokerStat(dataBrokerName: "CustomStats Broker 1", optoutSubmitSuccessRate: 0.5)
        let expectedBroker2 = CustomDataBrokerStat(dataBrokerName: "CustomStats Broker 2", optoutSubmitSuccessRate: 1.0)

        // When
        let result = sut.customStats(startDate: startDate, endDate: endDate, andQueryData: queryData)

        // Then
        let brokerOneResult = result.customDataBrokerStats.first { $0.dataBrokerName == "CustomStats Broker 1" }!
        let brokerTwoResult = result.customDataBrokerStats.first { $0.dataBrokerName == "CustomStats Broker 2" }!
        XCTAssertEqual(result.customDataBrokerStats.count, 2)
        XCTAssertEqual(result.customGlobalStat.optoutSubmitSuccessRate, 0.75)
        XCTAssertEqual(expectedBroker1, brokerOneResult)
        XCTAssertEqual(expectedBroker2, brokerTwoResult)
    }
}
