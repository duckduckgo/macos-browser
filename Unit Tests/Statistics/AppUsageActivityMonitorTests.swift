//
//  AppUsageActivityMonitorTests.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import Foundation
import XCTest
import Carbon
@testable import DuckDuckGo_Privacy_Browser

class AppUsageActivityMonitorTests: XCTestCase {

    var now: TimeInterval!
    var openWindowsAndTabs: [Int]!

    var callback: ((Double) -> Void)!

    var pixelDataStore: PixelDataStore!

    var wasActive = false

    override func setUp() {
        now = 0
        pixelDataStore = PixelStoreMock()

        wasActive = NSApp.isActive
        NSApp.setValue(true, forKey: "isActive")

        DependencyInjection.register(&Tab.Dependencies.faviconManagement, value: FaviconManagerMock())
    }

    override func tearDown() {
        pixelDataStore = nil
        openWindowsAndTabs = nil
        callback = nil
        NSApp.setValue(wasActive, forKey: "isActive")
    }

    func sendKeyEvent() {
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
                                     timestamp: Date().timeIntervalSinceReferenceDate, windowNumber: 0,
                                     context: nil, characters: "x", charactersIgnoringModifiers: "",
                                     isARepeat: false, keyCode: UInt16(kVK_ANSI_X))!
        NSApp.sendEvent(event)
    }

    // MARK: - Tests

    func testActivityMonitorEventsAreThrottled() {
        pixelDataStore = PixelStoreMock()
        let mon = AppUsageActivityMonitor(delegate: self, dateProvider: self.now, storage: pixelDataStore,
                                          throttle: 0.05, maxIdleTime: 10.0, threshold: 5.0)

        let e = expectation(description: "activity received")

        callback = { avgTabCount in
            XCTAssertEqual(avgTabCount, 0)
            e.fulfill()
        }

        now = 5
        openWindowsAndTabs = []
        sendKeyEvent()
        sendKeyEvent()
        sendKeyEvent()
        sendKeyEvent()
        sendKeyEvent()

        withExtendedLifetime(mon) {
            waitForExpectations(timeout: 1)
        }
    }

    func testWhenActivityMonitorReachesThresholdThenActivityCallbackIsFired() {
        let mon = AppUsageActivityMonitor(delegate: self, dateProvider: self.now, storage: pixelDataStore,
                                          throttle: 0.0, maxIdleTime: 10.0, threshold: 5.0)

        let e = expectation(description: "activity received")

        callback = { avgTabCount in
            XCTAssertEqual(avgTabCount, 4)
            e.fulfill()
        }

        now = Date().timeIntervalSinceReferenceDate
        openWindowsAndTabs = [2, 3, 1]
        sendKeyEvent()
        now += 5.0
        openWindowsAndTabs = [1, 1]
        sendKeyEvent()

        withExtendedLifetime(mon) {
            waitForExpectations(timeout: 1)
        }
    }

    func testWhenAppIsInactiveActivityIsNotTracked() {
        let mon = AppUsageActivityMonitor(delegate: self, dateProvider: self.now, storage: pixelDataStore,
                                          throttle: 0.0, maxIdleTime: 10.0, threshold: 5.0)

        callback = { _ in
            XCTFail("Should not fire when App is not active")
        }

        NSApp.setValue(false, forKey: "isActive")
        now = Date().timeIntervalSinceReferenceDate

        sendKeyEvent()
        now += 5.0
        sendKeyEvent()

        withExtendedLifetime(mon) {}
    }

    func testWhenAppIsRestartedThenActivityMonitorUsageTimeIsSaved() {
        var mon = AppUsageActivityMonitor(delegate: self, dateProvider: self.now, storage: pixelDataStore,
                                          throttle: 0.0, maxIdleTime: 10.0, threshold: 5.0)

        let e = expectation(description: "activity received")

        callback = { avgTabCount in
            XCTAssertEqual(avgTabCount, 4)
            e.fulfill()
        }

        now = Date().timeIntervalSinceReferenceDate
        openWindowsAndTabs = [2, 3, 1]
        sendKeyEvent()

        mon = AppUsageActivityMonitor(delegate: self, dateProvider: self.now, storage: pixelDataStore,
                                      throttle: 0.0, maxIdleTime: 10.0, threshold: 5.0)

        now += 5.0
        openWindowsAndTabs = [1, 1]
        sendKeyEvent()

        withExtendedLifetime(mon) {
            waitForExpectations(timeout: 1)
        }
    }

    func testWhenAppIsIdleForIdleTimeThenActivityIsNotRegistered() {
        let mon = AppUsageActivityMonitor(delegate: self, dateProvider: self.now, storage: pixelDataStore,
                                          throttle: 0.0, maxIdleTime: 10.0, threshold: 5.0)

        callback = { _ in
            XCTFail("Activity should not be registered for idle time")
        }

        now = Date().timeIntervalSinceReferenceDate
        openWindowsAndTabs = []
        sendKeyEvent()

        now += 11.0
        sendKeyEvent()

        now += 11.0
        sendKeyEvent()

        let e = expectation(description: "activity received")
        callback = { _ in
            e.fulfill()
        }
        now += 5.0
        sendKeyEvent()

        withExtendedLifetime(mon) {
            waitForExpectations(timeout: 1)
        }
    }

    func testWhenActiveUsageIsRegisteredNextEventsDoNotFireCallback() {
        let mon = AppUsageActivityMonitor(delegate: self, dateProvider: self.now, storage: pixelDataStore,
                                          throttle: 0.0, maxIdleTime: 10.0, threshold: 5.0)

        var e = expectation(description: "activity received")
        callback = { _ in
            e.fulfill()
        }

        now = Date().timeIntervalSinceReferenceDate
        openWindowsAndTabs = []
        sendKeyEvent()

        for _ in 0..<3 {
            now += 2.0
            sendKeyEvent()
        }

        waitForExpectations(timeout: 1)

        // should not fire anymore today
        for _ in 0..<15 {
            now += 2.0
            sendKeyEvent()
        }

        // should fire the next day
        e = expectation(description: "activity received")

        now += 3600 * 24
        for _ in 0..<4 {
            sendKeyEvent()
            now += 2.0
        }

        withExtendedLifetime(mon) {
            waitForExpectations(timeout: 1)
        }
    }

    func testWhenAppIsUsedNextDayThenMetricsAreReset() {
        let mon = AppUsageActivityMonitor(delegate: self, dateProvider: self.now, storage: pixelDataStore,
                                          throttle: 0.0, maxIdleTime: 10.0, threshold: 5.0)

        callback = { _ in
            XCTFail("Activity should not be registered before reaching threshold")
        }

        now = Date().timeIntervalSinceReferenceDate
        openWindowsAndTabs = [1, 1]
        sendKeyEvent()

        for _ in 0..<3 {
            now += 1.0
            sendKeyEvent()
        }

        let e = expectation(description: "activity received next day")
        callback = { avgTabsCount in
            XCTAssertEqual(avgTabsCount, 4)
            e.fulfill()
        }

        openWindowsAndTabs = [2, 2]
        now += 3600 * 24
        sendKeyEvent()
        now += 5
        sendKeyEvent()

        withExtendedLifetime(mon) {
            waitForExpectations(timeout: 1)
        }
    }
}

extension AppUsageActivityMonitorTests: AppUsageActivityMonitorDelegate {

    func countOpenWindowsAndTabs() -> [Int] {
        return self.openWindowsAndTabs
    }

    func activeUsageTimeHasReachedThreshold(avgTabCount: Double) {
        self.callback(avgTabCount)
    }

}
