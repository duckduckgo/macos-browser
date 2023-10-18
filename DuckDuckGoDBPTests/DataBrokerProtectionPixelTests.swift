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

    // swiftlint:disable:next cyclomatic_complexity
    func mapToPixelEvent(_ dbpPixel: DataBrokerProtectionPixels) -> Pixel.Event {
        switch dbpPixel {
        case .error(let error, _):
            return .debug(event: .dataBrokerProtectionError, error: error)
        case .parentChildMatches:
            return .parentChildMatches
        case .optOutStart:
            return .optOutStart
        case .optOutEmailGenerate:
            return .optOutEmailGenerate
        case .optOutCaptchaParse:
            return .optOutCaptchaParse
        case .optOutCaptchaSend:
            return .optOutCaptchaSend
        case .optOutCaptchaSolve:
            return .optOutCaptchaSolve
        case .optOutSubmit:
            return .optOutSubmit
        case .optOutEmailReceive:
            return .optOutEmailReceive
        case .optOutEmailConfirm:
            return .optOutEmailConfirm
        case .optOutValidate:
            return .optOutValidate
        case .optOutFinish:
            return .optOutFinish
        case .optOutSubmitSuccess:
            return .optOutSubmitSuccess
        case .optOutSuccess:
            return .optOutSuccess
        case .optOutFailure:
            return .optOutFailure
        }
    }

    /// This method implements validation logic that can be used to test several events.
    ///
    func validatePixel(for dbpEvent: DataBrokerProtectionPixels) {
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

        let inEvent = mapToPixelEvent(dbpEvent)

        let pixel = Pixel(appVersion: inAppVersion, store: storeMock) { (event, parameters, _, headers, onComplete) in

            // Validate that the event is the one we expect
            XCTAssertEqual(event, inEvent)

            // Validate that the basic params are present
            let pixelRequestValidator = PixelRequestValidator()
            pixelRequestValidator.validateBasicPixelParams(expectedAppVersion: inAppVersion, expectedUserAgent: inUserAgent, requestParameters: parameters, requestHeaders: headers.httpHeaders)

            // Validate that the debug params are present
            if case .debug(let wrappedEvent, let error) = inEvent {
                XCTAssertEqual("m_mac_debug_\(wrappedEvent.name)", inEvent.name)

                pixelRequestValidator.validateDebugPixelParams(expectedError: error, requestParameters: parameters)
            }

            // Validate that the dbp-specific params are present in the fire event parameters
            XCTAssertTrue(
                dbpEvent.params.allSatisfy({ key, value in
                    parameters[key] == value
                }))

            callbackExecuted.fulfill()
            onComplete(nil)
        }

        pixel.fire(inEvent, withAdditionalParameters: dbpEvent.params)

        waitForExpectations(timeout: 0.1)
    }

    func testBasicPixelValidation() {
        let inDataBroker = "inDataBroker"

        let eventsToTest: [DataBrokerProtectionPixels] = [
            .error(error: DataBrokerProtectionError.cancelled, dataBroker: inDataBroker),
            .parentChildMatches(parent: "a", child: "b", value: 5),
            .optOutStart(dataBroker: "a", attemptId: UUID()),
            .optOutEmailGenerate(dataBroker: "a", attemptId: UUID(), duration: 5),
            .optOutCaptchaParse(dataBroker: "a", attemptId: UUID(), duration: 5),
            .optOutCaptchaSend(dataBroker: "a", attemptId: UUID(), duration: 5),
            .optOutCaptchaSolve(dataBroker: "a", attemptId: UUID(), duration: 5),
            .optOutSubmit(dataBroker: "a", attemptId: UUID(), duration: 5),
            .optOutEmailReceive(dataBroker: "a", attemptId: UUID(), duration: 5),
            .optOutEmailConfirm(dataBroker: "a", attemptId: UUID(), duration: 5),
            .optOutValidate(dataBroker: "a", attemptId: UUID(), duration: 5),
            .optOutFinish(dataBroker: "a", attemptId: UUID(), duration: 5),
            .optOutSubmitSuccess(dataBroker: "a", attemptId: UUID(), duration: 5),
            .optOutSuccess(dataBroker: "a", attemptId: UUID(), duration: 5),
            .optOutFailure(dataBroker: "a", attemptId: UUID(), duration: 5)
        ]

        for event in eventsToTest {
            validatePixel(for: event)
        }
    }
}
