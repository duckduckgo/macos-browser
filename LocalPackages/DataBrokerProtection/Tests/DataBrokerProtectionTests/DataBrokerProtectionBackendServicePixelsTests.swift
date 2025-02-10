//
//  DataBrokerProtectionBackendServicePixelsTests.swift
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

final class DataBrokerProtectionBackendServicePixelsTests: XCTestCase {
    let mockHandler = MockDataBrokerProtectionPixelsHandler()
    var settings: DataBrokerProtectionSettings!

    override func setUpWithError() throws {
        let suiteName = "com.dbp.tests.\(UUID().uuidString)"
        let defaults =  UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        settings = DataBrokerProtectionSettings(defaults: defaults)
    }

    override func tearDownWithError() throws {
        mockHandler.clear()
        settings = nil
    }

    func testSendHTTPErrorOnStagingAndNotWaitlist_thenValidatePixelSent() {
        settings.selectedEnvironment = .staging

        let backendPixel = DefaultDataBrokerProtectionBackendServicePixels(pixelHandler: mockHandler,
                                                                           settings: settings)

        backendPixel.fireGenerateEmailHTTPError(statusCode: 200)
        let lastPixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.last

        XCTAssertNotNil(lastPixel)
        XCTAssertEqual(lastPixel?.params?[DataBrokerProtectionPixels.Consts.httpCode], "200", "Incorrect statusCode")
        XCTAssertEqual(lastPixel?.params?[DataBrokerProtectionPixels.Consts.environmentKey], "staging", "Incorrect environment")
        XCTAssertEqual(lastPixel?.params?[DataBrokerProtectionPixels.Consts.wasOnWaitlist], "false", "should be true")
    }

    func testSendHTTPErrorOnProductionAndWaitlist_thenValidatePixelSent() {
        settings.selectedEnvironment = .production
        let backendPixel = DefaultDataBrokerProtectionBackendServicePixels(pixelHandler: mockHandler,
                                                                           settings: settings)

        backendPixel.fireGenerateEmailHTTPError(statusCode: 123)
        let lastPixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.last

        XCTAssertNotNil(lastPixel)
        XCTAssertEqual(lastPixel?.params?[DataBrokerProtectionPixels.Consts.httpCode], "123", "Incorrect statusCode")
        XCTAssertEqual(lastPixel?.params?[DataBrokerProtectionPixels.Consts.environmentKey], "production", "Incorrect environment")
    }

    func testSendEmptyAccessTokenOnProductionAndWaitlistFromEmailCallsite_thenValidatePixelSent() {
        settings.selectedEnvironment = .production
        let backendPixel = DefaultDataBrokerProtectionBackendServicePixels(pixelHandler: mockHandler,
                                                                           settings: settings)

        backendPixel.fireEmptyAccessToken(callSite: .getEmail)

        let lastPixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.last

        XCTAssertNotNil(lastPixel)
        XCTAssertEqual(lastPixel?.params?[DataBrokerProtectionPixels.Consts.environmentKey], "production", "Incorrect environment")
        XCTAssertEqual(lastPixel?.params?[DataBrokerProtectionPixels.Consts.backendServiceCallSite], "getEmail", "Should be getEmail")

    }

    func testSendEmptyAccessTokenOnStagingAndNotOnWaitlistFromCaptchaCallsite_thenValidatePixelSent() {
        settings.selectedEnvironment = .staging

        let backendPixel = DefaultDataBrokerProtectionBackendServicePixels(pixelHandler: mockHandler,
                                                                           settings: settings)

        backendPixel.fireEmptyAccessToken(callSite: .submitCaptchaInformationRequest)

        let lastPixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.last

        XCTAssertNotNil(lastPixel)
        XCTAssertEqual(lastPixel?.params?[DataBrokerProtectionPixels.Consts.environmentKey], "staging", "Incorrect environment")
        XCTAssertEqual(lastPixel?.params?[DataBrokerProtectionPixels.Consts.wasOnWaitlist], "false", "should be false")
        XCTAssertEqual(lastPixel?.params?[DataBrokerProtectionPixels.Consts.backendServiceCallSite], "submitCaptchaInformationRequest", "Should be getEmail")

    }

}
