//
//  StatisticsLoaderTests.swift
//
//  Copyright © 2017 DuckDuckGo. All rights reserved.
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
import OHHTTPStubs
import OHHTTPStubsSwift
import PixelExperimentKit
@testable import PixelKit
@testable import DuckDuckGo_Privacy_Browser

class StatisticsLoaderTests: XCTestCase {

    private var mockAttributionsPixelHandler: MockAttributionsPixelHandler!
    private var mockStatisticsStore: StatisticsStore!
    private var testee: StatisticsLoader!
    private var fireAppRetentionExperimentPixelsCalled = false
    private var fireSearchExperimentPixelsCalled = false
    let pixelKit = PixelKit(dryRun: true,
                            appVersion: "1.0.0",
                            defaultHeaders: [:],
                            defaults: UserDefaults(),
                            fireRequest: { _, _, _, _, _, _ in })

    override func setUp() {
        PixelKit.setSharedForTesting(pixelKit: pixelKit)

        mockAttributionsPixelHandler = MockAttributionsPixelHandler()
        mockStatisticsStore = MockStatisticsStore()
        testee = StatisticsLoader(statisticsStore: mockStatisticsStore,
                                  attributionPixelHandler: mockAttributionsPixelHandler,
                                  fireAppRetentionExperimentPixels: { self.fireAppRetentionExperimentPixelsCalled = true },
                                  fireSearchExperimentPixels: { self.fireSearchExperimentPixelsCalled = true })
    }

    override func tearDown() {
        PixelKit.tearDown()
        HTTPStubs.removeAllStubs()
        mockStatisticsStore = nil
        mockAttributionsPixelHandler = nil
        testee = nil
        fireAppRetentionExperimentPixelsCalled = false
        fireSearchExperimentPixelsCalled = false
        super.tearDown()
    }

    func testWhenSearchRefreshHasSuccessfulUpdateAtbRequestThenSearchRetentionAtbUpdated() {

        mockStatisticsStore.atb = "atb"
        mockStatisticsStore.searchRetentionAtb = "retentionatb"
        mockStatisticsStore.variant = "test"
        loadSuccessfulUpdateAtbStub()

        let expect = expectation(description: "Successful atb updates retention store")
        testee.refreshSearchRetentionAtb {
            XCTAssertEqual(self.mockStatisticsStore.atb, "v20-1")
            XCTAssertEqual(self.mockStatisticsStore.searchRetentionAtb, "v77-5")
            XCTAssertNil(self.mockStatisticsStore.variant)
            expect.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenAppRefreshHasSuccessfulUpdateAtbRequestThenAppRetentionAtbUpdated() {

        mockStatisticsStore.atb = "atb"
        mockStatisticsStore.appRetentionAtb = "retentionatb"
        loadSuccessfulUpdateAtbStub()

        let expect = expectation(description: "Successful atb updates retention store")
        testee.refreshAppRetentionAtb {
            XCTAssertEqual(self.mockStatisticsStore.atb, "v20-1")
            XCTAssertEqual(self.mockStatisticsStore.appRetentionAtb, "v77-5")
            expect.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenLoadHasSuccessfulAtbAndExtiRequestsThenStoreUpdatedWithVariant() {

        loadSuccessfulAtbStub()
        loadSuccessfulExiStub()

        let expect = expectation(description: "Successful atb and exti updates store")
        testee.load {
            XCTAssertTrue(self.mockStatisticsStore.hasInstallStatistics)
            XCTAssertEqual(self.mockStatisticsStore.atb, "v77-5")
            expect.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenLoadHasUnsuccessfulAtbThenStoreNotUpdated() {

        loadUnsuccessfulAtbStub()
        loadSuccessfulExiStub()

        let expect = expectation(description: "Unsuccessful atb does not update store")
        testee.load {
            XCTAssertFalse(self.mockStatisticsStore.hasInstallStatistics)
            XCTAssertNil(self.mockStatisticsStore.atb)
            expect.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenLoadHasUnsuccessfulExtiThenStoreNotUpdated() {

        loadSuccessfulAtbStub()
        loadUnsuccessfulExiStub()

        let expect = expectation(description: "Unsuccessful exti does not update store")
        testee.load {
            XCTAssertFalse(self.mockStatisticsStore.hasInstallStatistics)
            XCTAssertNil(self.mockStatisticsStore.atb)
            expect.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenSearchRefreshHasSuccessfulAtbRequestThenSearchRetentionAtbUpdated() {

        mockStatisticsStore.atb = "atb"
        mockStatisticsStore.searchRetentionAtb = "retentionatb"
        loadSuccessfulAtbStub()

        let expect = expectation(description: "Successful atb updates retention store")
        testee.refreshSearchRetentionAtb {
            XCTAssertEqual(self.mockStatisticsStore.atb, "atb")
            XCTAssertEqual(self.mockStatisticsStore.searchRetentionAtb, "v77-5")
            expect.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenAppRefreshHasSuccessfulAtbRequestThenAppRetentionAtbUpdated() {

        mockStatisticsStore.atb = "atb"
        mockStatisticsStore.appRetentionAtb = "retentionatb"
        loadSuccessfulAtbStub()

        let expect = expectation(description: "Successful atb updates retention store")
        testee.refreshAppRetentionAtb {
            XCTAssertEqual(self.mockStatisticsStore.atb, "atb")
            XCTAssertEqual(self.mockStatisticsStore.appRetentionAtb, "v77-5")
            expect.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenSearchRefreshHasUnsuccessfulAtbRequestThenSearchRetentionAtbNotUpdated() {
        mockStatisticsStore.atb = "atb"
        mockStatisticsStore.searchRetentionAtb = "retentionAtb"
        loadUnsuccessfulAtbStub()

        let expect = expectation(description: "Unsuccessful atb does not update store")
        testee.refreshSearchRetentionAtb {
            XCTAssertEqual(self.mockStatisticsStore.atb, "atb")
            XCTAssertEqual(self.mockStatisticsStore.searchRetentionAtb, "retentionAtb")
            expect.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenAppRefreshHasUnsuccessfulAtbRequestThenSearchRetentionAtbNotUpdated() {
        mockStatisticsStore.atb = "atb"
        mockStatisticsStore.appRetentionAtb = "retentionAtb"
        loadUnsuccessfulAtbStub()

        let expect = expectation(description: "Unsuccessful atb does not update store")
        testee.refreshAppRetentionAtb {
            XCTAssertEqual(self.mockStatisticsStore.atb, "atb")
            XCTAssertEqual(self.mockStatisticsStore.appRetentionAtb, "retentionAtb")
            expect.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenSearchRefreshCompletesThenLastAppRetentionRequestDateNotUpdated() {
        mockStatisticsStore.atb = "atb"
        mockStatisticsStore.appRetentionAtb = "retentionAtb"
        mockStatisticsStore.searchRetentionAtb = "retentionAtb"
        loadSuccessfulAtbStub()
        XCTAssertFalse(self.mockStatisticsStore.isAppRetentionFiredToday)

        let expect = expectation(description: "Search retention atb does not update lastAppRetentionRequestDate")
        testee.refreshSearchRetentionAtb {
            XCTAssertNil(self.mockStatisticsStore.lastAppRetentionRequestDate)
            XCTAssertFalse(self.mockStatisticsStore.isAppRetentionFiredToday)
            expect.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenAppRefreshCompletesThenLastAppRetentionRequestDateUpdated() {
        mockStatisticsStore.atb = "atb"
        mockStatisticsStore.appRetentionAtb = "retentionAtb"
        mockStatisticsStore.searchRetentionAtb = "retentionAtb"
        loadSuccessfulAtbStub()
        XCTAssertFalse(self.mockStatisticsStore.isAppRetentionFiredToday)

        let expect = expectation(description: "App retention atb updates lastAppRetentionRequestDate")
        testee.refreshAppRetentionAtb {
            XCTAssertNotNil(self.mockStatisticsStore.lastAppRetentionRequestDate)
            XCTAssertTrue(self.mockStatisticsStore.isAppRetentionFiredToday)
            expect.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenAppRefreshFailsThenLastAppRetentionRequestDateNotUpdated() {
        mockStatisticsStore.atb = "atb"
        mockStatisticsStore.appRetentionAtb = "retentionAtb"
        mockStatisticsStore.searchRetentionAtb = "retentionAtb"
        loadUnsuccessfulAtbStub()
        XCTAssertFalse(self.mockStatisticsStore.isAppRetentionFiredToday)

        let expect = expectation(description: "Unsuccessful App retention atb does not update lastAppRetentionRequestDate")
        testee.refreshAppRetentionAtb {
            XCTAssertNil(self.mockStatisticsStore.lastAppRetentionRequestDate)
            XCTAssertFalse(self.mockStatisticsStore.isAppRetentionFiredToday)
            expect.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenRefreshRetentionAtbIsPerformedForSearchThenSearchRetentionAtbRequested() {
        mockStatisticsStore.appRetentionAtb = "appRetentionAtb"
        mockStatisticsStore.searchRetentionAtb = "searchRetentionAtb"
        loadSuccessfulUpdateAtbStub()

        let expect = expectation(description: "Search retention ATB requested")
        testee.refreshRetentionAtb(isSearch: true) {
            XCTAssertEqual(self.mockStatisticsStore.atb, "v20-1")
            XCTAssertEqual(self.mockStatisticsStore.searchRetentionAtb, "v77-5")
            XCTAssertTrue(self.fireSearchExperimentPixelsCalled)
            expect.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    // Disabled, app retention ATB is not currently used
    func testWhenRefreshRetentionAtbIsPerformedForNavigationThenAppRetentionAtbRequested() {
        mockStatisticsStore.atb = "atb"
        mockStatisticsStore.appRetentionAtb = "appRetentionAtb"
        mockStatisticsStore.searchRetentionAtb = "searchRetentionAtb"
        loadSuccessfulUpdateAtbStub()

        let expect = expectation(description: "App retention ATB requested")
        testee.refreshRetentionAtb(isSearch: false) {
            XCTAssertEqual(self.mockStatisticsStore.atb, "v20-1")
            XCTAssertEqual(self.mockStatisticsStore.appRetentionAtb, "v77-5")
            XCTAssertEqual(self.mockStatisticsStore.searchRetentionAtb, "searchRetentionAtb")
            XCTAssertTrue(self.mockStatisticsStore.isAppRetentionFiredToday)
            XCTAssertTrue(self.fireAppRetentionExperimentPixelsCalled)
            XCTAssertFalse(self.fireSearchExperimentPixelsCalled)
            expect.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenRefreshRetentionAtbIsPerformedTwiceADayThenAppRetentionAtbNotRequested() {
        mockStatisticsStore.atb = "atb"
        mockStatisticsStore.appRetentionAtb = "appRetentionAtb"
        mockStatisticsStore.searchRetentionAtb = "searchRetentionAtb"
        mockStatisticsStore.lastAppRetentionRequestDate = Date()
        loadSuccessfulUpdateAtbStub()

        let expect = expectation(description: "App retention ATB not requested")
        testee.refreshRetentionAtb(isSearch: false) {
            XCTAssertEqual(self.mockStatisticsStore.atb, "atb")
            XCTAssertEqual(self.mockStatisticsStore.appRetentionAtb, "appRetentionAtb")
            XCTAssertEqual(self.mockStatisticsStore.searchRetentionAtb, "searchRetentionAtb")
            XCTAssertTrue(self.mockStatisticsStore.isAppRetentionFiredToday)
            XCTAssertTrue(self.fireAppRetentionExperimentPixelsCalled)
            XCTAssertFalse(self.fireSearchExperimentPixelsCalled)
            expect.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenRefreshRetentionAtbIsPerformedForNonSearchAndNoInstallStatisticsExistThenAtbRequested() {
        loadSuccessfulUpdateAtbStub()

        let expect = expectation(description: "App retention ATB requested")
        testee.refreshRetentionAtb(isSearch: false) {
            XCTAssertEqual(self.mockStatisticsStore.atb, "v20-1")
            XCTAssertEqual(self.mockStatisticsStore.appRetentionAtb, "v77-5")
            XCTAssertNil(self.mockStatisticsStore.searchRetentionAtb)
            XCTAssertTrue(self.mockStatisticsStore.isAppRetentionFiredToday)
            XCTAssertTrue(self.fireAppRetentionExperimentPixelsCalled)
            XCTAssertFalse(self.fireSearchExperimentPixelsCalled)
            expect.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenLoadHasSuccessfulAtbThenAttributionPixelShouldFire() {
        // GIVEN
        loadSuccessfulAtbStub()
        let expect = expectation(description: #function)
        XCTAssertFalse(mockAttributionsPixelHandler.didCallFireInstallationAttributionPixel)

        // WHEN
        testee.load {
            expect.fulfill()
        }

        // THEN
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertTrue(mockAttributionsPixelHandler.didCallFireInstallationAttributionPixel)
    }

    func testWhenLoadHasUnsuccessfulAtbThenAttributionPixelShouldNotFire() {
        // GIVEN
        loadUnsuccessfulAtbStub()
        let expect = expectation(description: #function)
        XCTAssertFalse(mockAttributionsPixelHandler.didCallFireInstallationAttributionPixel)

        testee.load {
            expect.fulfill()
        }

        // THEN
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertFalse(mockAttributionsPixelHandler.didCallFireInstallationAttributionPixel)
    }

    func testWhenLoadHasSuccessfulAtbSubsequentlyThenAttributionPixelShouldNotFire() {
        // GIVEN
        loadSuccessfulAtbStub()
        let firstATBCallExpectation = XCTestExpectation(description: "First ATB call")
        let secondATBCallExpectation = XCTestExpectation(description: "Second ATB call")
        testee.load { firstATBCallExpectation.fulfill() }
        wait(for: [firstATBCallExpectation], timeout: 1.0)
        XCTAssertTrue(mockAttributionsPixelHandler.didCallFireInstallationAttributionPixel)
        XCTAssertEqual(mockAttributionsPixelHandler.fireInstallationAttributionPixelCount, 1)

        // WHEN
        testee.load { secondATBCallExpectation.fulfill() }

        // THEN
        wait(for: [secondATBCallExpectation], timeout: 1.0)
        XCTAssertEqual(mockAttributionsPixelHandler.fireInstallationAttributionPixelCount, 1)
    }

    func loadSuccessfulAtbStub() {
        stub(condition: isHost(URL.initialAtb.host!)) { _ in
            let path = OHPathForFile("atb.json", type(of: self))!
            return fixture(filePath: path, status: 200, headers: nil)
        }
    }

    func loadSuccessfulUpdateAtbStub() {
        stub(condition: isHost(URL.initialAtb.host!)) { _ in
            let path = OHPathForFile("atb-with-update.json", type(of: self))!
            return fixture(filePath: path, status: 200, headers: nil)
        }
    }

    func loadUnsuccessfulAtbStub() {
        stub(condition: isHost(URL.initialAtb.host!)) { _ in
            let path = OHPathForFile("invalid.json", type(of: self))!
            return fixture(filePath: path, status: 400, headers: nil)
        }
    }

    func loadSuccessfulExiStub() {
        stub(condition: isPath(URL.exti(forAtb: "").path)) { _ -> HTTPStubsResponse in
            let path = OHPathForFile("empty", type(of: self))!
            return fixture(filePath: path, status: 200, headers: nil)
        }
    }

    func loadUnsuccessfulExiStub() {
        stub(condition: isPath(URL.exti(forAtb: "").path)) { _ -> HTTPStubsResponse in
            let path = OHPathForFile("empty", type(of: self))!
            return fixture(filePath: path, status: 400, headers: nil)
        }
    }

}
