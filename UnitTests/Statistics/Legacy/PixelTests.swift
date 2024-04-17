//
//  PixelTests.swift
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

import Common
import Networking
import OHHTTPStubs
import OHHTTPStubsSwift
import PixelKit
import XCTest

@testable import DuckDuckGo_Privacy_Browser

class PixelTests: XCTestCase {

    let host = "improving.duckduckgo.com"
    let testAgent = "Test Agent"
    let userAgentName = "User-Agent"

    override func setUp() {
        Pixel.setUp()
    }

    override func tearDown() {
        HTTPStubs.removeAllStubs()
        Pixel.tearDown()
        super.tearDown()
    }

    func testWhenPixelFiredThenAPIHeadersAreAdded() {
        let expectation = expectation(description: "request sent")

        stub(condition: hasHeaderNamed(userAgentName, value: testAgent)) { _ -> HTTPStubsResponse in
            expectation.fulfill()
            return HTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
        }

        let headers = APIRequest.Headers(userAgent: testAgent)
        Pixel.shared!.fire(.serp, withHeaders: headers)

        waitForExpectations(timeout: 1.0)
    }

    func testWhenPixelIsFiredWithAdditionalParametersThenParametersAdded() {
        let expectation = expectation(description: "request sent")
        let params = ["param1": "value1", "param2": "value2"]

        stub(condition: isHost(host) && isPath("/t/m_mac_crash")) { request -> HTTPStubsResponse in
            XCTAssertEqual("value1", request.url?.getParameter(named: "param1"))
            XCTAssertEqual("value2", request.url?.getParameter(named: "param2"))
            expectation.fulfill()
            return HTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
        }

        PixelKit.fire(GeneralPixel.crash, withAdditionalParameters: params)

        waitForExpectations(timeout: 1.0)
    }

    func testWhenErrorPixelIsFiredThenParametersAdded() {
        let expectation = expectation(description: "request sent")
        let error = NSError(domain: "TestErrorDomain", code: 42, userInfo: nil)

        stub(condition: isHost(host) && isPath("/t/m_mac_debug_url")) { request -> HTTPStubsResponse in
            XCTAssertEqual("TestErrorDomain", request.url?.getParameter(named: "d"))
            XCTAssertEqual("42", request.url?.getParameter(named: "e"))
            expectation.fulfill()
            return HTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
        }

        PixelKit.fire(DebugEvent( GeneralPixel.appOpenURLFailed, error: error))

        waitForExpectations(timeout: 1.0)
    }

    func testWhenErrorPixelIsFiredAdditionalParametersThenParametersMerged() {
        let expectation = expectation(description: "request sent")
        let params = ["param1": "value1", "d": "TheMainQuestion"]
        let error = NSError(domain: "TestErrorDomain", code: 42, userInfo: ["key": 41])

        stub(condition: isHost(host) && isPath("/t/m_mac_debug_url")) { request -> HTTPStubsResponse in
            var parameters = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.reduce(into: [:]) { $0[$1.name] = $1.value ?? "" }
            parameters[PixelKit.Parameters.test] = nil

            XCTAssertEqual(parameters, [
                "appVersion": AppVersion.shared.versionNumber,
                "d": "TheMainQuestion",
                "e": "42",
                "param1": "value1",
            ])

            expectation.fulfill()
            return HTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
        }

        PixelKit.fire(DebugEvent( GeneralPixel.appOpenURLFailed, error: error), withAdditionalParameters: params)

        waitForExpectations(timeout: 1.0)
    }

    func testWhenPixelFiresSuccessfullyThenCompletesWithNoError() {
        let eRequestSent = expectation(description: "request sent")
        let expectation = expectation(description: "callback received")

        stub(condition: isHost(host)) { _ -> HTTPStubsResponse in
            eRequestSent.fulfill()
            return HTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
        }

        Pixel.shared!.fire(.serp) { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testWhenPixelFiresUnsuccessfullyThenCompletesWithError() {
        let eRequestSent = expectation(description: "request sent")
        let expectation = expectation(description: "error received")

        stub(condition: isHost(host)) { _ -> HTTPStubsResponse in
            eRequestSent.fulfill()
            return HTTPStubsResponse(data: Data(), statusCode: 404, headers: nil)
        }

        Pixel.shared!.fire(.serp) { error in
            XCTAssertNotNil(error)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

}
