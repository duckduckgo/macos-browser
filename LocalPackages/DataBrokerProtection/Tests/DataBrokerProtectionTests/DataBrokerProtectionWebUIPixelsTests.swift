//
//  DataBrokerProtectionWebUIPixelsTests.swift
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
import Foundation
@testable import DataBrokerProtection

final class DataBrokerProtectionWebUIPixelsTests: XCTestCase {

    let handler = MockDataBrokerProtectionPixelsHandler()

    override func tearDown() {
        handler.clear()
    }

    func testWhenURLErrorIsHttp_thenCorrectPixelIsFired() {
        let sut = DataBrokerProtectionWebUIPixels(pixelHandler: handler)

        sut.firePixel(for: NSError(domain: NSURLErrorDomain, code: 404))

        let lastPixelFired = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!

        XCTAssertEqual(
            lastPixelFired.params!["error_category"],
            "httpError-404"
        )
    }

    func testWhenURLErrorIsNotHttp_thenCorrectPixelIsFired() {
        let sut = DataBrokerProtectionWebUIPixels(pixelHandler: handler)

        sut.firePixel(for: NSError(domain: NSURLErrorDomain, code: 100))

        let lastPixelFired = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!

        XCTAssertEqual(
            lastPixelFired.params!["error_category"],
            "other-100"
        )
    }

    func testWhenErrorIsNotURL_thenCorrectPixelIsFired() {
        let sut = DataBrokerProtectionWebUIPixels(pixelHandler: handler)

        sut.firePixel(for: NSError(domain: NSCocoaErrorDomain, code: 500))

        let lastPixelFired = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!

        XCTAssertEqual(
            lastPixelFired.params!["error_category"],
            "other-500"
        )
    }

    func testWhenSelectedURLisCustomAndLoading_thenStagingParamIsSent() {
        let sut = DataBrokerProtectionWebUIPixels(pixelHandler: handler)

        sut.firePixel(for: .custom, type: .loading)

        let lastPixelFired = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!

        XCTAssertEqual(
            lastPixelFired.name,
            DataBrokerProtectionPixels.webUILoadingStarted(environment: "staging").name
        )
        XCTAssertEqual(
            lastPixelFired.params!["environment"],
            "staging"
        )
    }

    func testWhenSelectedURLisProductionAndLoading_thenProductionParamIsSent() {
        let sut = DataBrokerProtectionWebUIPixels(pixelHandler: handler)

        sut.firePixel(for: .production, type: .loading)

        let lastPixelFired = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!

        XCTAssertEqual(
            lastPixelFired.name,
            DataBrokerProtectionPixels.webUILoadingStarted(environment: "staging").name
        )
        XCTAssertEqual(
            lastPixelFired.params!["environment"],
            "production"
        )
    }

    func testWhenSelectedURLisCustomAndSuccess_thenStagingParamIsSent() {
        let sut = DataBrokerProtectionWebUIPixels(pixelHandler: handler)

        sut.firePixel(for: .custom, type: .success)

        let lastPixelFired = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!

        XCTAssertEqual(
            lastPixelFired.name,
            DataBrokerProtectionPixels.webUILoadingSuccess(environment: "staging").name
        )
        XCTAssertEqual(
            lastPixelFired.params!["environment"],
            "staging"
        )
    }

    func testWhenSelectedURLisProductionAndSuccess_thenProductionParamIsSent() {
        let sut = DataBrokerProtectionWebUIPixels(pixelHandler: handler)

        sut.firePixel(for: .production, type: .success)

        let lastPixelFired = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!

        XCTAssertEqual(
            lastPixelFired.name,
            DataBrokerProtectionPixels.webUILoadingSuccess(environment: "staging").name
        )
        XCTAssertEqual(
            lastPixelFired.params!["environment"],
            "production"
        )
    }

    func testWhenHTTPPixelIsFired_weDoNotFireAnotherPixelRightAway() {
        let sut = DataBrokerProtectionWebUIPixels(pixelHandler: handler)

        sut.firePixel(for: NSError(domain: NSURLErrorDomain, code: 404))
        sut.firePixel(for: NSError(domain: NSCocoaErrorDomain, code: 500))

        let httpPixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!

        XCTAssertEqual(
            httpPixel.params!["error_category"],
            "httpError-404"
        )
        XCTAssertEqual(MockDataBrokerProtectionPixelsHandler.lastPixelsFired.count, 1) // We only fire one pixel
    }

    func testWhenHTTPPixelIsFired_weFireTheNextErrorPixelOnTheSecondTry() {
        let sut = DataBrokerProtectionWebUIPixels(pixelHandler: handler)

        sut.firePixel(for: NSError(domain: NSURLErrorDomain, code: 404))
        sut.firePixel(for: NSError(domain: NSCocoaErrorDomain, code: 500))
        sut.firePixel(for: NSError(domain: NSCocoaErrorDomain, code: 500))

        let httpPixel = MockDataBrokerProtectionPixelsHandler.lastPixelsFired.first!

        XCTAssertEqual(
            httpPixel.params!["error_category"],
            "httpError-404"
        )
        XCTAssertEqual(MockDataBrokerProtectionPixelsHandler.lastPixelsFired.count, 2) // We fire the HTTP pixel and the second cocoa error pixel
    }
}
