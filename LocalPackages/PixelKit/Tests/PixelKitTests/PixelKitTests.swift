//
//  PixelKitTests.swift
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
@testable import PixelKit
import os.log // swiftlint:disable:this enforce_os_log_wrapper

final class PixelKitTests: XCTestCase {

    private func userDefaults() -> UserDefaults {
        UserDefaults(suiteName: "testing_\(UUID().uuidString)")!
    }

    /// Test events for convenience
    ///
    private enum TestEvent: String, PixelKitEvent {
        case testEvent
        case testEventWithoutParameters
        case dailyEvent
        case dailyEventWithoutParameters
        case dailyAndContinuousEvent
        case dailyAndContinuousEventWithoutParameters

        var name: String {
            rawValue
        }

        var parameters: [String : String]? {
            switch self {
            case .testEvent, .dailyEvent, .dailyAndContinuousEvent:
                return [
                    "eventParam1": "eventParamValue1",
                    "eventParam2": "eventParamValue2"
                ]
            case .testEventWithoutParameters, .dailyEventWithoutParameters, .dailyAndContinuousEventWithoutParameters:
                return nil
            }
        }

        var frequency: PixelKitEventFrequency {
            switch self {
            case .testEvent, .testEventWithoutParameters:
                return .standard
            case .dailyEvent, .dailyEventWithoutParameters:
                return .dailyOnly
            case .dailyAndContinuousEvent, .dailyAndContinuousEventWithoutParameters:
                return .dailyAndContinuous
            }
        }
    }

    /// Test that a dry run won't execute the fire request callback.
    ///
    func testDryRunWontExecuteCallback() async {
        let appVersion = "1.0.5"
        let headers: [String: String] = [:]
        let log = OSLog.disabled

        let pixelKit = PixelKit(dryRun: true, appVersion: appVersion, defaultHeaders: headers, log: log, dailyPixelCalendar: nil) { _, _, _, _, _, _ in

            XCTFail("This callback should not be executed when doing a dry run")
        }

        pixelKit.fire(TestEvent.testEvent)
    }

    /// Tests firing a sample pixel and ensuring that all fields are properly set in the fire request callback.
    ///
    func testFiringASamplePixel() {
        // Prepare test parameters
        let appVersion = "1.0.5"
        let headers = ["a": "2", "b": "3", "c": "2000"]
        let log = OSLog(subsystem: "TestSubsystem", category: "TestCategory")
        let event = TestEvent.testEvent
        let userDefaults = userDefaults()

        // Set expectations
        let expectedPixelName = "m_mac_\(event.name)"
        let fireCallbackCalled = expectation(description: "Expect the pixel firing callback to be called")

        // Prepare mock to validate expectations
        let pixelKit = PixelKit(dryRun: false,
                                appVersion: appVersion,
                                defaultHeaders: headers,
                                log: log,
                                dailyPixelCalendar: nil,
                                defaults: userDefaults) { firedPixelName, firedHeaders, parameters, allowedQueryReservedCharacters, callBackOnMainThread, onComplete in

            fireCallbackCalled.fulfill()

            XCTAssertEqual(expectedPixelName, firedPixelName)
            XCTAssertTrue(headers.allSatisfy({ key, value in
                firedHeaders[key] == value
            }))

            XCTAssertEqual(firedHeaders[PixelKit.Header.moreInfo], "See \(PixelKit.duckDuckGoMorePrivacyInfo)")

            XCTAssertEqual(parameters[PixelKit.Parameters.appVersion], appVersion)
            XCTAssertEqual(parameters[PixelKit.Parameters.test], PixelKit.Values.test)
        }

        // Run test
        pixelKit.fire(event)

        // Wait for expectations to be fulfilled
        wait(for: [fireCallbackCalled], timeout: 0.5)
    }

    /// We test firing a daily pixel for the first time executes the fire request callback with the right parameters
    ///
    func testFiringDailyPixelForTheFirstTime() {
        // Prepare test parameters
        let appVersion = "1.0.5"
        let headers = ["a": "2", "b": "3", "c": "2000"]
        let log = OSLog(subsystem: "TestSubsystem", category: "TestCategory")
        let event = TestEvent.dailyEvent
        let userDefaults = userDefaults()

        // Set expectations
        let expectedPixelName = "m_mac_\(event.name)_d"
        let expectedMoreInfoString = "See \(PixelKit.duckDuckGoMorePrivacyInfo)"
        let fireCallbackCalled = expectation(description: "Expect the pixel firing callback to be called")

        // Prepare mock to validate expectations
        let pixelKit = PixelKit(dryRun: false,
                                appVersion: appVersion,
                                defaultHeaders: headers,
                                log: log,
                                dailyPixelCalendar: nil,
                                defaults: userDefaults) { firedPixelName, firedHeaders, parameters, allowedQueryReservedCharacters, callBackOnMainThread, onComplete in

            fireCallbackCalled.fulfill()

            XCTAssertEqual(expectedPixelName, firedPixelName)
            XCTAssertTrue(headers.allSatisfy({ key, value in
                firedHeaders[key] == value
            }))

            XCTAssertEqual(firedHeaders[PixelKit.Header.moreInfo], expectedMoreInfoString)
            XCTAssertEqual(parameters[PixelKit.Parameters.appVersion], appVersion)
            XCTAssertEqual(parameters[PixelKit.Parameters.test], PixelKit.Values.test)
        }

        // Run test
        pixelKit.fire(event)

        // Wait for expectations to be fulfilled
        wait(for: [fireCallbackCalled], timeout: 0.5)
    }

    /// We test firing a daily pixel a second time does not execute the fire request callback.
    ///
    func testDailyPixelFrequency() {
        // Prepare test parameters
        let appVersion = "1.0.5"
        let headers = ["a": "2", "b": "3", "c": "2000"]
        let log = OSLog(subsystem: "TestSubsystem", category: "TestCategory")
        let event = TestEvent.dailyEvent
        let userDefaults = userDefaults()

        // Set expectations
        let expectedPixelName = "m_mac_\(event.name)_d"
        let expectedMoreInfoString = "See \(PixelKit.duckDuckGoMorePrivacyInfo)"
        let fireCallbackCalled = expectation(description: "Expect the pixel firing callback to be called")
        fireCallbackCalled.expectedFulfillmentCount = 1
        fireCallbackCalled.assertForOverFulfill = true

        // Prepare mock to validate expectations
        let pixelKit = PixelKit(dryRun: false,
                                appVersion: appVersion,
                                defaultHeaders: headers,
                                log: log,
                                dailyPixelCalendar: nil,
                                defaults: userDefaults) { firedPixelName, firedHeaders, parameters, allowedQueryReservedCharacters, callBackOnMainThread, onComplete in

            fireCallbackCalled.fulfill()

            XCTAssertEqual(expectedPixelName, firedPixelName)
            XCTAssertTrue(headers.allSatisfy({ key, value in
                firedHeaders[key] == value
            }))

            XCTAssertEqual(firedHeaders[PixelKit.Header.moreInfo], expectedMoreInfoString)
            XCTAssertEqual(parameters[PixelKit.Parameters.appVersion], appVersion)
            XCTAssertEqual(parameters[PixelKit.Parameters.test], PixelKit.Values.test)
        }

        // Run test
        pixelKit.fire(event)
        pixelKit.fire(event)

        // Wait for expectations to be fulfilled
        wait(for: [fireCallbackCalled], timeout: 0.5)
    }
}
