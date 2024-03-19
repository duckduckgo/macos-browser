//
//  DataBrokerProtectionFeatureTests.swift
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
@testable import DataBrokerProtection

final class DataBrokerProtectionFeatureTests: XCTestCase {

    let mockCSSDelegate = MockCSSCommunicationDelegate()

    override func setUp() {
        mockCSSDelegate.reset()
    }

    func testWhenParseActionCompletedFailsOnParsing_thenDelegateSendsBackTheCorrectError() async {
        let params = ["result": "something"]
        let sut = DataBrokerProtectionFeature(delegate: mockCSSDelegate)

        await sut.parseActionCompleted(params: params)

        XCTAssertEqual(mockCSSDelegate.lastError as? DataBrokerProtectionError, DataBrokerProtectionError.parsingErrorObjectFailed)
    }

    func testWhenErrorIsParsed_thenDelegateSendsBackActionFailedError() async {
        let params = ["result": ["error": ["actionID": "someActionID", "message": "some message"]]]
        let sut = DataBrokerProtectionFeature(delegate: mockCSSDelegate)

        await sut.parseActionCompleted(params: params)

        XCTAssertEqual(mockCSSDelegate.lastError as? DataBrokerProtectionError, DataBrokerProtectionError.actionFailed(actionID: "someActionID", message: "some message"))
    }

    func testWhenNavigateActionIsParsed_thenDelegateSendsBackURL() async {
        let params = ["result": ["success": ["actionID": "1", "actionType": "navigate", "response": ["url": "www.duckduckgo.com"]] as [String: Any]]]
        let sut = DataBrokerProtectionFeature(delegate: mockCSSDelegate)

        await sut.parseActionCompleted(params: params)

        XCTAssertNil(mockCSSDelegate.lastError)
        XCTAssertEqual(mockCSSDelegate.url?.absoluteString, "www.duckduckgo.com")
    }

    func testWhenExtractActionIsParsed_thenDelegateSendsExtractedProfiles() async {
        let profiles = NSArray(objects: ["name": "John"], ["name": "Ben"])
        let params = ["result": ["success": ["actionID": "1", "actionType": "extract", "response": profiles] as [String: Any]]]
        let sut = DataBrokerProtectionFeature(delegate: mockCSSDelegate)

        await sut.parseActionCompleted(params: params)

        XCTAssertNil(mockCSSDelegate.lastError)
        XCTAssertNotNil(mockCSSDelegate.profiles)
        XCTAssertEqual(mockCSSDelegate.profiles?.count, 2)
    }

    func testWhenUnknownActionIsParsed_thenDelegateSendsParsingError() async {
        let params = ["result": ["success": ["actionID": "1", "actionType": "unknown"] as [String: Any]]]
        let sut = DataBrokerProtectionFeature(delegate: mockCSSDelegate)

        await sut.parseActionCompleted(params: params)

        XCTAssertEqual(mockCSSDelegate.lastError as? DataBrokerProtectionError, DataBrokerProtectionError.parsingErrorObjectFailed)
    }

    func testWhenClickActionIsParsed_thenDelegateSendsSuccessWithCorrectActionId() async {
        let params = ["result": ["success": ["actionID": "click", "actionType": "click"] as [String: Any]]]
        let sut = DataBrokerProtectionFeature(delegate: mockCSSDelegate)

        await sut.parseActionCompleted(params: params)

        XCTAssertEqual(mockCSSDelegate.successActionId, "click")
    }

    func testWhenExpectationActionIsParsed_thenDelegateSendsSuccessWithCorrectActionId() async {
        let params = ["result": ["success": ["actionID": "expectation", "actionType": "expectation"] as [String: Any]]]
        let sut = DataBrokerProtectionFeature(delegate: mockCSSDelegate)

        await sut.parseActionCompleted(params: params)

        XCTAssertEqual(mockCSSDelegate.successActionId, "expectation")
    }

    func testWhenGetCaptchaInfoIsParsed_thenTheCorrectCaptchaInfoIsParsed() async {
        let params = ["result": ["success": ["actionID": "getCaptchaInfo", "actionType": "getCaptchaInfo", "response": ["siteKey": "1234", "url": "www.test.com", "type": "g-captcha"]] as [String: Any]]]
        let sut = DataBrokerProtectionFeature(delegate: mockCSSDelegate)

        await sut.parseActionCompleted(params: params)

        XCTAssertEqual(mockCSSDelegate.captchaInfo?.siteKey, "1234")
        XCTAssertEqual(mockCSSDelegate.captchaInfo?.url, "www.test.com")
        XCTAssertEqual(mockCSSDelegate.captchaInfo?.type, "g-captcha")
    }
}

final class MockCSSCommunicationDelegate: CCFCommunicationDelegate {
    var lastError: Error?
    var profiles: [ExtractedProfile]?
    var url: URL?
    var captchaInfo: GetCaptchaInfoResponse?
    var solveCaptchaResponse: SolveCaptchaResponse?
    var successActionId: String?

    func loadURL(url: URL) {
        self.url = url
    }

    func extractedProfiles(profiles: [ExtractedProfile], meta: [String: Any]?) async {
        self.profiles = profiles
    }

    func success(actionId: String, actionType: ActionType) {
        self.successActionId = actionId
    }

    func captchaInformation(captchaInfo: GetCaptchaInfoResponse) {
        self.captchaInfo = captchaInfo
    }

    func onError(error: Error) {
        self.lastError = error
    }

    func solveCaptcha(with response: SolveCaptchaResponse) async {
        self.solveCaptchaResponse = response
    }

    func reset() {
        lastError = nil
        profiles = nil
        url = nil
        successActionId = nil
        captchaInfo = nil
        solveCaptchaResponse = nil
    }
}
