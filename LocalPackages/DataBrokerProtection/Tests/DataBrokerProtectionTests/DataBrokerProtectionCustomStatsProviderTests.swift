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

    func testWhenTwoBrokers_andOneBrokerHasOneMatchFromOneProfile_thenCustomStatsAreCorrect() throws {
        // Given
        let queryData = queryDataTwoBrokersOneBroker100PercentSuccess
        let startDate = Date.nowMinus(hours: 28)
        let endDate = Date.nowMinus(hours: 24)
        let expected = CustomDataBrokerStat(dataBrokerName: "CustomStats Broker 2", optoutSubmitSuccessRate: 1.0)

        // When
        let result = sut.customDataBrokerStats(startDate: startDate, endDate: endDate, andQueryData: queryData)

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
        let queryData = queryDataManyBrokersOneBroker50PercentSuccess
        let startDate = Date.nowMinus(hours: 48)
        let endDate = Date.nowMinus(hours: 24)
        let expected = CustomDataBrokerStat(dataBrokerName: "CustomStats Broker 1", optoutSubmitSuccessRate: 0.50)

        // When
        let result = sut.customDataBrokerStats(startDate: startDate, endDate: endDate, andQueryData: queryData)

        // Then
        let brokerOneResult = result.customDataBrokerStats.first { $0.dataBrokerName == "CustomStats Broker 1" }!
        let brokersWithZeroSuccess = result.customDataBrokerStats.filter { $0.optoutSubmitSuccessRate == 0.0 }
        XCTAssert(result.customDataBrokerStats.count == 4)
        XCTAssert(brokersWithZeroSuccess.count == 3)
        XCTAssertEqual(result.customGlobalStat.optoutSubmitSuccessRate, 0.2)
        XCTAssertEqual(expected, brokerOneResult)
    }
}

private extension Date {
    static func nowMinus(hours: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: -hours, to: Date())!
    }
}

private extension DataBrokerProtectionCustomStatsProviderTests {

    var queryDataTwoBrokersOneBroker100PercentSuccess: [BrokerProfileQueryData] {

        let scanEventsOne = events(brokerId: 1,
                                profileQueryId: 1,
                                type: .matchesFound(count: 1),
                                dates: [.nowMinus(hours: 23), .nowMinus(hours: 26), .nowMinus(hours: 2)])

        let scanEventsTwo = events(brokerId: 2,
                                profileQueryId: 1,
                                type: .matchesFound(count: 1),
                                dates: [.nowMinus(hours: 23), .nowMinus(hours: 26), .nowMinus(hours: 2)])

        let optOutEvents = events(brokerId: 2,
                                profileQueryId: 1,
                                type: .optOutRequested,
                                dates: [.nowMinus(hours: 3)])

        return [
            queryData(brokerId: 1,
                         brokerName: "CustomStats Broker 1",
                         scanEvents: scanEventsOne,
                         optOutEvents: []),
            queryData(brokerId: 2,
                         brokerName: "CustomStats Broker 2",
                         scanEvents: scanEventsTwo,
                         optOutEvents: optOutEvents)
        ]
    }

    var queryDataManyBrokersOneBroker50PercentSuccess: [BrokerProfileQueryData] {

        let scanEventsOneProfileOne = events(brokerId: 1,
                                profileQueryId: 1,
                                type: .matchesFound(count: 1),
                                dates: [.nowMinus(hours: 23), .nowMinus(hours: 26), .nowMinus(hours: 2)])

        let scanEventsOneProfileTwo = events(brokerId: 1,
                                profileQueryId: 2,
                                type: .matchesFound(count: 1),
                                dates: [.nowMinus(hours: 23), .nowMinus(hours: 26), .nowMinus(hours: 2)])

        let scanEventsTwo = events(brokerId: 2,
                                profileQueryId: 1,
                                type: .matchesFound(count: 1),
                                dates: [.nowMinus(hours: 23), .nowMinus(hours: 26), .nowMinus(hours: 2)])

        let scanEventsThree = events(brokerId: 3,
                                profileQueryId: 1,
                                type: .matchesFound(count: 1),
                                dates: [.nowMinus(hours: 23), .nowMinus(hours: 26), .nowMinus(hours: 2)])

        let scanEventsFour = events(brokerId: 4,
                                profileQueryId: 1,
                                type: .matchesFound(count: 1),
                                dates: [.nowMinus(hours: 23), .nowMinus(hours: 26), .nowMinus(hours: 2)])

        let optOutEvents = events(brokerId: 1,
                                profileQueryId: 1,
                                type: .optOutRequested,
                                dates: [.nowMinus(hours: 3)])

        return [
            queryData(brokerId: 1,
                         brokerName: "CustomStats Broker 1",
                         scanEvents: scanEventsOneProfileOne + scanEventsOneProfileTwo,
                         optOutEvents: optOutEvents),
            queryData(brokerId: 2,
                         brokerName: "CustomStats Broker 2",
                         scanEvents: scanEventsTwo,
                         optOutEvents: []),
            queryData(brokerId: 3,
                         brokerName: "CustomStats Broker 3",
                         scanEvents: scanEventsThree,
                         optOutEvents: []),
            queryData(brokerId: 4,
                         brokerName: "CustomStats Broker 4",
                         scanEvents: scanEventsFour,
                         optOutEvents: []),

        ]
    }

    func queryData(brokerId: Int64, brokerName: String, scanEvents: [HistoryEvent], optOutEvents: [HistoryEvent]) -> BrokerProfileQueryData {
        let dataBroker = DataBroker(id: brokerId, name: brokerName, url: "", steps: [], version: "", schedulingConfig: .mock, mirrorSites: [])

        let profileQuery = ProfileQuery(id: 1, firstName: "John", lastName: "Doe", city: "Miami", state: "FL", birthYear: 50, deprecated: false)
        let scanJobData = ScanJobData(brokerId: 1,
                                      profileQueryId: 1,
                                      preferredRunDate: nil,
                                      historyEvents: scanEvents,
                                      lastRunDate: nil)
        let optOutJobData = OptOutJobData(brokerId: 1, profileQueryId: 1, historyEvents: optOutEvents, extractedProfile: ExtractedProfile())
        return BrokerProfileQueryData(dataBroker: dataBroker,
                                       profileQuery: profileQuery,
                                       scanJobData: scanJobData,
                                       optOutJobData: [optOutJobData])
    }

    func events(brokerId: Int64, profileQueryId: Int64, type: HistoryEvent.EventType, dates: [Date]) -> [HistoryEvent] {
        var result: [HistoryEvent] = []
        for date in dates {
            result.append(HistoryEvent(brokerId: brokerId,
                                       profileQueryId: profileQueryId,
                                       type: type,
                                       date: date))
        }
        return result
    }
}
