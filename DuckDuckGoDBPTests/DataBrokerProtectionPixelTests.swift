//
//  DataBrokerProtectionPixelTests.swift
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

import DataBrokerProtection
import Networking
import Foundation
import PixelKit
import PixelKitTestingUtilities
import XCTest
@testable import DuckDuckGo_DBP

/// Tests to ensure that DBP pixels sent from the main app work well
///
final class DataBrokerProtectionPixelTests: XCTestCase {

    struct PixelDataStoreMock: PixelDataStore {
        func set(_ value: Int, forKey: String, completionHandler: ((Error?) -> Void)?) {
            completionHandler?(nil)
        }

        func set(_ value: String, forKey: String, completionHandler: ((Error?) -> Void)?) {
            completionHandler?(nil)
        }

        func set(_ value: Double, forKey: String, completionHandler: ((Error?) -> Void)?) {
            completionHandler?(nil)
        }

        func value(forKey key: String) -> Double? {
            nil
        }

        func value(forKey key: String) -> Int? {
            nil
        }

        func value(forKey key: String) -> String? {
            nil
        }

        func removeValue(forKey key: String, completionHandler: ((Error?) -> Void)?) {
            completionHandler?(nil)
        }
    }

    /// This method implements validation logic that can be used to test several events.
    ///
    func validatePixel(for inEvent: PixelKitEvent) {
        let inAppVersion = "1.0.1"
        let inUserAgent = "ddg_mac/\(inAppVersion) (com.duckduckgo.macos.browser.dbp.debug; macOS Version 14.0 (Build 23A344))"

        // We want to make sure the callback is executed exactly once to validate
        // all of the fire parameters
        let callbackExecuted = expectation(description: "We expect the callback to be executed once")
        callbackExecuted.expectedFulfillmentCount = 1
        callbackExecuted.assertForOverFulfill = true

        // This is annoyingly necessary to test the user agent right now
        APIRequest.Headers.setUserAgent(inUserAgent)

        let storeMock = PixelDataStoreMock()

        let pixel = Pixel(appVersion: inAppVersion, store: storeMock) { (event, parameters, _, headers, onComplete) in

            // Validate that the event is the one we expect
            XCTAssertEqual(event.name, inEvent.name)

            let pixelRequestValidator = PixelRequestValidator()
            pixelRequestValidator.validateBasicPixelParams(expectedAppVersion: inAppVersion, expectedUserAgent: inUserAgent, requestParameters: parameters, requestHeaders: headers.httpHeaders)

            if case .debug(let wrappedEvent, let error) = inEvent {
                XCTAssertEqual("m_mac_debug_\(wrappedEvent.name)", inEvent.name)

                pixelRequestValidator.validateDebugPixelParams(expectedError: error, requestParameters: parameters)
            }

            callbackExecuted.fulfill()
            onComplete(nil)
        }

        pixel.fire(inEvent, withAdditionalParameters: inEvent.parameters)

        waitForExpectations(timeout: 0.1)
    }

    func testBasicPixelValidation() {
        enum TestError: Error {
            case testError
        }

        let eventsToTest: [DataBrokerProtectionPixels] = [
            DebugEvent(event: .dataBrokerProtectionError, error: TestError.testError),
            .parentChildMatches(parent: "", child: "", value: 0),
            .optOutStart(dataBroker: "", attemptId: UUID()),
            .optOutEmailGenerate(dataBroker: "", attemptId: UUID(), duration: 0),
            .optOutCaptchaParse(dataBroker: "", attemptId: UUID(), duration: 0),
            .optOutCaptchaSend(dataBroker: "", attemptId: UUID(), duration: 0),
            .optOutCaptchaSolve(dataBroker: "", attemptId: UUID(), duration: 0),
            .optOutSubmit(dataBroker: "", attemptId: UUID(), duration: 0),
            .optOutEmailReceive(dataBroker: "", attemptId: UUID(), duration: 0),
            .optOutEmailConfirm(dataBroker: "", attemptId: UUID(), duration: 0),
            .optOutValidate(dataBroker: "", attemptId: UUID(), duration: 0),
            .optOutFinish(dataBroker: "", attemptId: UUID(), duration: 0),
            .optOutSubmitSuccess(dataBroker: "", attemptId: UUID(), duration: 0),
            .optOutSuccess(dataBroker: "", attemptId: UUID(), duration: 0),
            .optOutFailure(dataBroker: "", attemptId: UUID(), duration: 0)
        ]

        for event in eventsToTest {
            validatePixel(for: event)
        }
    }

    func testBasicPixelValidation() {
        enum TestError: Error {
            case testError
        }

        let eventsToTest: [DebugEvent] = [
            DebugEvent(event: DataBrokerProtectionPixels.error(error: TestError.error, dataBroker: ""))
        ]

        for event in eventsToTest {
            validatePixel(for: event)
        }
    }
}
