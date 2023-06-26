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

    func testWhenParseActionCompletedFailsOnParsing_thenDelegateSendsBackTheCorrectError() {
        let params = ["result": "something"]
        let sut = DataBrokerProtectionFeature(delegate: mockCSSDelegate)

        sut.parseActionCompleted(params: params)

        XCTAssertEqual(mockCSSDelegate.lastError, .parsingErrorObjectFailed)
    }

    func testWhenErrorIsParsed_thenDelegateSendsBackActionFailedError() {
        let params = ["result": ["error": ["actionID": "someActionID", "message": "some message"]]]
        let sut = DataBrokerProtectionFeature(delegate: mockCSSDelegate)

        sut.parseActionCompleted(params: params)

        XCTAssertEqual(mockCSSDelegate.lastError, .actionFailed(actionID: "someActionID", message: "some message"))
    }

    func testWhenNavigateActionIsParsed_thenDelegateSendsBackURL() {
        let params = ["result": ["success": ["actionID": "1", "actionType": "navigate", "response": ["url": "www.duckduckgo.com"]] as [String: Any]]]
        let sut = DataBrokerProtectionFeature(delegate: mockCSSDelegate)

        sut.parseActionCompleted(params: params)

        XCTAssertNil(mockCSSDelegate.lastError)
        XCTAssertEqual(mockCSSDelegate.url?.absoluteString, "www.duckduckgo.com")
    }

    func testWhenExtractActionIsParsed_thenDelegateSendsExtractedProfiles() {
        let profiles = NSArray(objects: ["name": "John"], ["name": "Ben"])
        let params = ["result": ["success": ["actionID": "1", "actionType": "extract", "response": profiles] as [String: Any]]]
        let sut = DataBrokerProtectionFeature(delegate: mockCSSDelegate)

        sut.parseActionCompleted(params: params)

        XCTAssertNil(mockCSSDelegate.lastError)
        XCTAssertNotNil(mockCSSDelegate.profiles)
        XCTAssertEqual(mockCSSDelegate.profiles?.count, 2)
    }

    func testWhenUnknownActionIsParsed_thenDelegateSendsParsingError() {
        let params = ["result": ["success": ["actionID": "1", "actionType": "unknown"] as [String: Any]]]
        let sut = DataBrokerProtectionFeature(delegate: mockCSSDelegate)

        sut.parseActionCompleted(params: params)

        XCTAssertEqual(mockCSSDelegate.lastError, .parsingErrorObjectFailed)
    }

    func testWhenClickActionIsParsed_thenDelegateSendsSuccessWithCorrectActionId() {
        let params = ["result": ["success": ["actionID": "click", "actionType": "click"] as [String: Any]]]
        let sut = DataBrokerProtectionFeature(delegate: mockCSSDelegate)

        sut.parseActionCompleted(params: params)

        XCTAssertEqual(mockCSSDelegate.successActionId, "click")
    }

    func testWhenExpectationActionIsParsed_thenDelegateSendsSuccessWithCorrectActionId() {
        let params = ["result": ["success": ["actionID": "expectation", "actionType": "expectation"] as [String: Any]]]
        let sut = DataBrokerProtectionFeature(delegate: mockCSSDelegate)

        sut.parseActionCompleted(params: params)

        XCTAssertEqual(mockCSSDelegate.successActionId, "expectation")
    }
}

final class MockCSSCommunicationDelegate: CSSCommunicationDelegate {
    var lastError: DataBrokerProtectionError?
    var profiles: [ExtractedProfile]?
    var url: URL?
    var successActionId: String?

    func loadURL(url: URL) {
        self.url = url
    }

    func extractedProfiles(profiles: [ExtractedProfile]) {
        self.profiles = profiles
    }

    func success(actionId: String) {
        self.successActionId = actionId
    }

    func onError(error: DataBrokerProtectionError) {
        self.lastError = error
    }

    func reset() {
        lastError = nil
        profiles = nil
        url = nil
        successActionId = nil
    }
}
