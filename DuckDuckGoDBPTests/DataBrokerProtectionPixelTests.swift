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

    /// This method implements basic validation logic that can be used to test several events.
    ///
    func basicPixelValidation(for event: Pixel.Event) {
        let inAppVersion = "1.0.1"
        let inEvent: Pixel.Event = .optOutStart
        let inUserAgent = "ddg_mac/\(inAppVersion) (com.duckduckgo.macos.browser.dbp.debug"

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
            XCTAssertEqual(event, inEvent)

            PixelRequestValidator().validateBasicTestPixelRequest(inAppVersion: inAppVersion, inUserAgent: inUserAgent, requestParameters: parameters, requestHeaders: headers.httpHeaders)

            callbackExecuted.fulfill()
            onComplete(nil)
        }

        pixel.fire(inEvent, withAdditionalParameters: inEvent.parameters)

        waitForExpectations(timeout: 0.1)
    }

    func testBasicPixelValidation() {
        let eventsToTest: [Pixel.Event] = [
            .parentChildMatches,
            .optOutStart,
            .optOutEmailGenerate,
            .optOutCaptchaParse,
            .optOutCaptchaSend,
            .optOutCaptchaSolve,
            .optOutSubmit,
            .optOutEmailReceive,
            .optOutEmailConfirm,
            .optOutValidate,
            .optOutFinish,
            .optOutSubmitSuccess,
            .optOutSuccess,
            .optOutFailure
        ]

        for event in eventsToTest {
            basicPixelValidation(for: event)
        }
    }
}
