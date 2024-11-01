//
//  MismatchCalculatorUseCaseTests.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import Foundation
@testable import DataBrokerProtection

final class MismatchCalculatorUseCaseTests: XCTestCase {

    private let database = MockDatabase()
    private let pixelHandler = MockDataBrokerProtectionPixelsHandler()

    override func tearDown() {
        pixelHandler.clear()
    }

    func testWhenParentHasMoreMatches_thenParentSiteHasMoreMatchesPixelIsFired() {
        let parentHistoryEvents: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 2))
        ]
        let childHistoryEvents: [HistoryEvent] = [
            .init(brokerId: 2, profileQueryId: 1, type: .noMatchFound)
        ]
        database.brokerProfileQueryDataToReturn = [
            .mockParentWith(historyEvents: parentHistoryEvents),
            .mockChildtWith(historyEvents: childHistoryEvents)
        ]
        let sut = DefaultMismatchCalculator(
            database: database,
            pixelHandler: pixelHandler
        )

        sut.calculateMismatches()

        let lastPixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!
        let pixelName = DataBrokerProtectionPixels.parentChildMatches(parent: "", child: "", value: 0).name
        XCTAssertEqual(lastPixel.name, pixelName)
        XCTAssertEqual(Int((lastPixel.params?["value"])!),
                       MismatchValues.parentSiteHasMoreMatches.rawValue)
    }

    func testWhenChildHasMoreMatches_thenChildSiteHasMoreMatchesPixelIsFired() {
        let parentHistoryEvents: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 1))
        ]
        let childHistoryEvents: [HistoryEvent] = [
            .init(brokerId: 2, profileQueryId: 1, type: .matchesFound(count: 4))
        ]
        database.brokerProfileQueryDataToReturn = [
            .mockParentWith(historyEvents: parentHistoryEvents),
            .mockChildtWith(historyEvents: childHistoryEvents)
        ]
        let sut = DefaultMismatchCalculator(
            database: database,
            pixelHandler: pixelHandler
        )

        sut.calculateMismatches()

        let lastPixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!
        let pixelName = DataBrokerProtectionPixels.parentChildMatches(parent: "", child: "", value: 0).name
        XCTAssertEqual(lastPixel.name, pixelName)
        XCTAssertEqual(Int((lastPixel.params?["value"])!),
                       MismatchValues.childSiteHasMoreMatches.rawValue)
    }

    func testWhenBrokersHaveNoMatches_thenNoMismatchesPixelIsFired() {
        let parentHistoryEvents: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .noMatchFound)
        ]
        let childHistoryEvents: [HistoryEvent] = [
            .init(brokerId: 2, profileQueryId: 1, type: .noMatchFound)
        ]
        database.brokerProfileQueryDataToReturn = [
            .mockParentWith(historyEvents: parentHistoryEvents),
            .mockChildtWith(historyEvents: childHistoryEvents)
        ]
        let sut = DefaultMismatchCalculator(
            database: database,
            pixelHandler: pixelHandler
        )

        sut.calculateMismatches()

        let lastPixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!
        let pixelName = DataBrokerProtectionPixels.parentChildMatches(parent: "", child: "", value: 0).name
        XCTAssertEqual(lastPixel.name, pixelName)
        XCTAssertEqual(Int((lastPixel.params?["value"])!),
                       MismatchValues.noMismatch.rawValue)
    }

    func testWhenBrokersHaveSameMatches_thenNoMismatchesPixelIsFired() {
        let parentHistoryEvents: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 2))
        ]
        let childHistoryEvents: [HistoryEvent] = [
            .init(brokerId: 2, profileQueryId: 1, type: .matchesFound(count: 2))
        ]
        database.brokerProfileQueryDataToReturn = [
            .mockParentWith(historyEvents: parentHistoryEvents),
            .mockChildtWith(historyEvents: childHistoryEvents)
        ]
        let sut = DefaultMismatchCalculator(
            database: database,
            pixelHandler: pixelHandler
        )

        sut.calculateMismatches()

        let lastPixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!
        let pixelName = DataBrokerProtectionPixels.parentChildMatches(parent: "", child: "", value: 0).name
        XCTAssertEqual(lastPixel.name, pixelName)
        XCTAssertEqual(Int((lastPixel.params?["value"])!),
                       MismatchValues.noMismatch.rawValue)
    }

    func testWhenParentBrokerHasNoChildren_thenNothingIsFired() {
        let parentHistoryEvents: [HistoryEvent] = [
            .init(brokerId: 1, profileQueryId: 1, type: .matchesFound(count: 2))
        ]
        database.brokerProfileQueryDataToReturn = [
            .mockParentWith(historyEvents: parentHistoryEvents)
        ]
        let sut = DefaultMismatchCalculator(
            database: database,
            pixelHandler: pixelHandler
        )

        sut.calculateMismatches()

        XCTAssertTrue(MockDataBrokerProtectionPixelsHandler.lastPixelsFired.isEmpty)
    }
}

extension BrokerProfileQueryData {
    static func mockParentWith(historyEvents: [HistoryEvent]) -> BrokerProfileQueryData {
        BrokerProfileQueryData(
            dataBroker: DataBroker(
                name: "parent",
                url: "parent.com",
                steps: [Step](),
                version: "1.0.0",
                schedulingConfig: DataBrokerScheduleConfig.mock,
                optOutUrl: ""
            ),
            profileQuery: ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", birthYear: 50),
            scanJobData: ScanJobData(brokerId: 1, profileQueryId: 1, historyEvents: historyEvents)
        )
    }

    static func mockChildtWith(historyEvents: [HistoryEvent]) -> BrokerProfileQueryData {
        BrokerProfileQueryData(
            dataBroker: DataBroker(
                name: "child",
                url: "child.com",
                steps: [Step](),
                version: "1.0.0",
                schedulingConfig: DataBrokerScheduleConfig.mock,
                parent: "parent.com",
                optOutUrl: ""
            ),
            profileQuery: ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", birthYear: 50),
            scanJobData: ScanJobData(brokerId: 2, profileQueryId: 1, historyEvents: historyEvents)
        )
    }
}
