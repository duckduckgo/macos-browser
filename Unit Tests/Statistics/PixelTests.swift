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

import XCTest
import OHHTTPStubs
import OHHTTPStubsSwift
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

    // Temporarily disabled, as this test gets caught in the Run Loop extension:
    func testWhenTimedPixelFiredThenCorrectDurationIsSet() {
        let expectation = XCTestExpectation()

        let date: CFTimeInterval = 0
        let now: CFTimeInterval = 1

        stub(condition: { request -> Bool in
            if let url = request.url {
                XCTAssertEqual("1.0", url.getParameter(named: "duration"))
                return true
            }

            XCTFail("Did not find duration param")
            return true
        }, response: { _ -> HTTPStubsResponse in
            expectation.fulfill()
            return HTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
        })

        let store = PixelStoreMock()
        let pixel = TimedPixel(.burn(repetition: .init(key: "fire", store: store)), time: date)

        pixel.fire(now)

        wait(for: [expectation], timeout: 1.0)
    }
    
    func testWhenPixelFiredThenAPIHeadersAreAdded() {
        let expectation = XCTestExpectation()

        stub(condition: hasHeaderNamed(userAgentName, value: testAgent)) { _ -> HTTPStubsResponse in
            expectation.fulfill()
            return HTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
        }

        var headers = APIHeaders().defaultHeaders
        headers[userAgentName] = testAgent

        Pixel.shared!.fire(pixelNamed: "test", withHeaders: headers)

        wait(for: [expectation], timeout: 1.0)

    }

    func testWhenPixelIsFiredWithAdditionalParametersThenParametersAdded() {
        let expectation = XCTestExpectation()
        let params = ["param1": "value1", "param2": "value2"]

        stub(condition: isHost(host) && isPath("/t/m_mac_crash")) { request -> HTTPStubsResponse in
            XCTAssertEqual("value1", request.url?.getParameter(named: "param1"))
            XCTAssertEqual("value2", request.url?.getParameter(named: "param2"))
            expectation.fulfill()
            return HTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
        }

        Pixel.fire(.crash, withAdditionalParameters: params)

        wait(for: [expectation], timeout: 1.0)
    }

    func testWhenErrorPixelIsFiredThenParametersAdded() {
        let expectation = XCTestExpectation()
        let error = NSError(domain: "TestErrorDomain", code: 42, userInfo: nil)

        stub(condition: isHost(host) && isPath("/t/m_mac_debug_url")) { request -> HTTPStubsResponse in
            XCTAssertEqual("TestErrorDomain", request.url?.getParameter(named: "d"))
            XCTAssertEqual("42", request.url?.getParameter(named: "e"))
            expectation.fulfill()
            return HTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
        }

        Pixel.fire(.debug(event: Pixel.Event.Debug.appOpenURLFailed, error: error))

        wait(for: [expectation], timeout: 1.0)
    }

    func testWhenErrorPixelIsFiredAdditionalParametersThenParametersMerged() {
        let expectation = XCTestExpectation()
        let params = ["param1": "value1", "d": "TheMainQuestion"]
        let error = NSError(domain: "TestErrorDomain", code: 42, userInfo: ["key": 41])

        stub(condition: isHost(host) && isPath("/t/ml_mac_app-launch_as-default_app-launch")) { request -> HTTPStubsResponse in
            XCTAssertEqual("TheMainQuestion", request.url?.getParameter(named: "d"))
            XCTAssertEqual("42", request.url?.getParameter(named: "e"))
            XCTAssertEqual("value1", request.url?.getParameter(named: "param1"))
            XCTAssertEqual("value2", request.url?.getParameter(named: "param2"))
            expectation.fulfill()
            return HTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
        }

        Pixel.fire(.debug(event: Pixel.Event.Debug.appOpenURLFailed, error: error), withAdditionalParameters: params)

    }

    func testWhenPixelFiresSuccessfullyThenCompletesWithNoError() {
        let expectation = XCTestExpectation()

        stub(condition: isHost(host)) { _ -> HTTPStubsResponse in
            return HTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
        }

        Pixel.shared!.fire(pixelNamed: "test") { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testWhenPixelFiresUnsuccessfullyThenCompletesWithError() {
        let expectation = XCTestExpectation()

        stub(condition: isHost(host)) { _ -> HTTPStubsResponse in
            return HTTPStubsResponse(data: Data(), statusCode: 404, headers: nil)
        }

        Pixel.shared!.fire(pixelNamed: "test") { error in
            XCTAssertNotNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

}
