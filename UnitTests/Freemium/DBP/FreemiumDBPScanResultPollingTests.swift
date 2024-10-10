//
//  FreemiumDBPScanResultPollingTests.swift
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
@testable import DuckDuckGo_Privacy_Browser
@testable import DataBrokerProtection
import Common
import Freemium

final class FreemiumDBPScanResultPollingTests: XCTestCase {

    private var sut: FreemiumDBPScanResultPolling!
    private var mockFreemiumDBPUserStateManager: MockFreemiumDBPUserStateManager!
    private var mockNotificationCenter: MockNotificationCenter!
    private var mockDataManager: MockDataBrokerProtectionDataManager!
    private let key = "macos.browser.freemium.dbp.first.profile.saved.timestamp"

    override func setUpWithError() throws {
        mockFreemiumDBPUserStateManager = MockFreemiumDBPUserStateManager()
        mockNotificationCenter = MockNotificationCenter()
        mockDataManager = MockDataBrokerProtectionDataManager()
    }

    func testWhenResultsAlreadyPosted_thenNoPollingOrObserving() {
        // Given
        mockFreemiumDBPUserStateManager.didPostResultsNotification = true
        let sut = DefaultFreemiumDBPScanResultPolling(
            dataManager: mockDataManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager,
            notificationCenter: mockNotificationCenter
        )

        // When
        sut.startPollingOrObserving()

        // Then
        XCTAssertFalse(mockDataManager.didCallMatchesFoundCount)
        XCTAssertFalse(mockNotificationCenter.didCallAddObserver)
        XCTAssertNil(sut.timer)
    }

    func testWhenFirstProfileIsAlreadySaved_thenPollingStartsImmediately() {
        // Given
        mockFreemiumDBPUserStateManager.firstProfileSavedTimestamp = Date()
        let sut = DefaultFreemiumDBPScanResultPolling(
            dataManager: mockDataManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager,
            notificationCenter: mockNotificationCenter
        )

        // When
        sut.startPollingOrObserving()

        // Then
        XCTAssertTrue(mockDataManager.didCallMatchesFoundCount)
        XCTAssertFalse(mockNotificationCenter.didCallAddObserver)
        XCTAssertNotNil(sut.timer)
    }

    func testWhenNoProfileIsSaved_thenObserveForNotification_andDontStartTimer() {
        // Given
        let sut = DefaultFreemiumDBPScanResultPolling(
            dataManager: mockDataManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager,
            notificationCenter: mockNotificationCenter
        )

        // When
        sut.startPollingOrObserving()

        // Then
        XCTAssertFalse(mockDataManager.didCallMatchesFoundCount)
        XCTAssertTrue(mockNotificationCenter.didCallAddObserver)
        XCTAssertNil(sut.timer)
    }

    func testWhenIsNotifiedOfFirstProfileSaved_thenPollingStarts() {
        // Given
        let sut = DefaultFreemiumDBPScanResultPolling(
            dataManager: mockDataManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager,
            notificationCenter: mockNotificationCenter
        )

        // When
        sut.startPollingOrObserving()
        mockNotificationCenter.post(name: .pirProfileSaved, object: nil)

        // Then
        XCTAssertNotNil(mockFreemiumDBPUserStateManager.firstProfileSavedTimestamp)
        XCTAssertTrue(mockNotificationCenter.didCallAddObserver)
        XCTAssertFalse(mockDataManager.didCallMatchesFoundCount)
        XCTAssertNotNil(sut.timer)
    }

    func testWhenResultsFoundWithinDuration_thenResultsNotificationPosted() {
        // Given
        mockDataManager.matchesFoundCountValue = (3, 2)
        mockFreemiumDBPUserStateManager.firstProfileSavedTimestamp = Date.nowMinus(hours: 12)
        let sut = DefaultFreemiumDBPScanResultPolling(
            dataManager: mockDataManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager,
            notificationCenter: mockNotificationCenter
        )

        // When
        sut.startPollingOrObserving()

        // Then
        XCTAssertFalse(mockNotificationCenter.didCallAddObserver)
        XCTAssertTrue(mockDataManager.didCallMatchesFoundCount)
        XCTAssertEqual(mockNotificationCenter.lastPostedNotification, .freemiumDBPResultPollingComplete)
        XCTAssertEqual(mockFreemiumDBPUserStateManager.firstScanResults, FreemiumDBPMatchResults(matchesCount: 3, brokerCount: 2))
        XCTAssertNil(sut.timer)
    }

    func testWhenResultsFoundAndMaxDurationExpired_thenResultsNotificationPosted() {
        // Given
        mockDataManager.matchesFoundCountValue = (4, 2)
        mockFreemiumDBPUserStateManager.firstProfileSavedTimestamp = Date.nowMinus(hours: 36)
        let sut = DefaultFreemiumDBPScanResultPolling(
            dataManager: mockDataManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager,
            notificationCenter: mockNotificationCenter
        )

        // When
        sut.startPollingOrObserving()

        // Then
        XCTAssertEqual(mockNotificationCenter.lastPostedNotification, .freemiumDBPResultPollingComplete)
        XCTAssertEqual(mockFreemiumDBPUserStateManager.firstScanResults, FreemiumDBPMatchResults(matchesCount: 4, brokerCount: 2))
        XCTAssertFalse(mockNotificationCenter.didCallAddObserver)
        XCTAssertTrue(mockDataManager.didCallMatchesFoundCount)
        XCTAssertNil(sut.timer)
    }

    func testWhenNoResultsFoundAndMaxDurationExpired_thenResultsNotificationPosted() {
        // Given
        mockDataManager.matchesFoundCountValue = (0, 0)
        mockFreemiumDBPUserStateManager.firstProfileSavedTimestamp = Date.nowMinus(hours: 36)
        let sut = DefaultFreemiumDBPScanResultPolling(
            dataManager: mockDataManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager,
            notificationCenter: mockNotificationCenter
        )

        // When
        sut.startPollingOrObserving()

        // Then
        XCTAssertEqual(mockNotificationCenter.lastPostedNotification, .freemiumDBPResultPollingComplete)
        XCTAssertEqual(mockFreemiumDBPUserStateManager.firstScanResults, FreemiumDBPMatchResults(matchesCount: 0, brokerCount: 0))
        XCTAssertFalse(mockNotificationCenter.didCallAddObserver)
        XCTAssertTrue(mockDataManager.didCallMatchesFoundCount)
        XCTAssertNil(sut.timer)
    }

    func testWhenPollingIsDeinitialized_thenTimerIsInvalidated() {
        // Given
        var sut: DefaultFreemiumDBPScanResultPolling? = DefaultFreemiumDBPScanResultPolling(
            dataManager: mockDataManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager,
            notificationCenter: mockNotificationCenter
        )
        sut?.startPollingOrObserving()

        // When
        sut = nil

        // Then
        XCTAssertNil(sut?.timer)
    }

    func testWhenTimerAlreadyExists_thenSecondTimerIsNotCreated() {
        // Given
        let sut = DefaultFreemiumDBPScanResultPolling(
            dataManager: mockDataManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager,
            notificationCenter: mockNotificationCenter
        )
        sut.startPollingOrObserving()
        let existingTimer = sut.timer

        // When
        sut.startPollingOrObserving()

        // Then
        XCTAssertEqual(sut.timer, existingTimer)
    }

    func testWhenDataManagerThrowsError_thenPollingContinuesGracefully() {
        // Given
        mockDataManager.matchesFoundCountValue = (0, 0)
        mockDataManager.didCallMatchesFoundCount = false
        mockFreemiumDBPUserStateManager.firstProfileSavedTimestamp = Date.nowMinus(hours: 1)

        let sut = DefaultFreemiumDBPScanResultPolling(
            dataManager: mockDataManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager,
            notificationCenter: mockNotificationCenter
        )

        // When
        sut.startPollingOrObserving()

        XCTAssertNoThrow(try mockDataManager.matchesFoundAndBrokersCount())

        // Then
        XCTAssertFalse(mockNotificationCenter.didCallPostNotification)
        XCTAssertTrue(mockDataManager.didCallMatchesFoundCount)
    }

    func testWhenProfileSavedButNoResultsBeforeMaxDuration_thenNoResultsNotificationNotPosted() {
        // Given
        mockDataManager.matchesFoundCountValue = (0, 0)
        mockFreemiumDBPUserStateManager.firstProfileSavedTimestamp = Date.nowMinus(hours: 12)

        let sut = DefaultFreemiumDBPScanResultPolling(
            dataManager: mockDataManager,
            freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager,
            notificationCenter: mockNotificationCenter
        )

        // When
        sut.startPollingOrObserving()

        // Then
        XCTAssertFalse(mockNotificationCenter.didCallPostNotification)
        XCTAssertTrue(mockDataManager.didCallMatchesFoundCount)
        XCTAssertNotNil(sut.timer)
    }
}

private extension Date {
    private static func nowMinusHour(_ hour: Int) -> Date? {
        let calendar = Calendar.current
        return calendar.date(byAdding: .hour, value: -hour, to: Date())
    }
}

final class MockNotificationCenter: NotificationCenter {

    var didCallAddObserver = false
    var didCallPostNotification = false
    var lastPostedNotification: Notification.Name?

    override func addObserver(forName name: NSNotification.Name?, object obj: Any?, queue: OperationQueue?, using block: @escaping (Notification) -> Void) -> any NSObjectProtocol {
        didCallAddObserver = true
        return super.addObserver(forName: name, object: obj, queue: queue, using: block)
    }

    override func post(name aName: NSNotification.Name, object anObject: Any?) {
        didCallPostNotification = true
        lastPostedNotification = aName
        super.post(name: aName, object: nil)
    }
}

private final class MockDataBrokerProtectionDataManager: DataBrokerProtectionDataManaging {

    var didCallMatchesFoundCount = false
    var matchesFoundCountValue = (0, 0)

    var cache = InMemoryDataCache()
    var delegate: DataBrokerProtection.DataBrokerProtectionDataManagerDelegate?

    init(database: DataBrokerProtectionRepository? = nil,
         profileSavedNotifier: DBPProfileSavedNotifier? = nil,
         pixelHandler: EventMapping<DataBrokerProtection.DataBrokerProtectionPixels>,
         fakeBrokerFlag: DataBrokerProtection.DataBrokerDebugFlag) {
    }

    init() {}

    func saveProfile(_ profile: DataBrokerProtection.DataBrokerProtectionProfile) async throws { }

    func fetchProfile() throws -> DataBrokerProtection.DataBrokerProtectionProfile? { nil }

    func prepareProfileCache() throws { }

    func fetchBrokerProfileQueryData(ignoresCache: Bool) throws -> [DataBrokerProtection.BrokerProfileQueryData] { [] }

    func prepareBrokerProfileQueryDataCache() throws {}

    func hasMatches() throws -> Bool { true }

    func matchesFoundAndBrokersCount() throws -> (matchCount: Int, brokerCount: Int) {
        didCallMatchesFoundCount = true
        return matchesFoundCountValue
    }

    func profileQueriesCount() throws -> Int { 0 }
}
