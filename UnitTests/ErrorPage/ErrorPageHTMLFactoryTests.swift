//
//  ErrorPageHTMLFactoryTests.swift
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

import Foundation
import XCTest
import PhishingDetection
import SpecialErrorPages
@testable import DuckDuckGo_Privacy_Browser

class ErrorPageHTMLFactoryTests: XCTestCase {
    func testPhishingErrorTemplate() {
        let error = PhishingDetectionError.detected
        let url = URL(string: "https://example.com")!
        let html = ErrorPageHTMLFactory.html(for: error, url: url)

        XCTAssertNotNil(html)
        XCTAssertTrue(html.contains("Phishing")) // Check if the HTML contains "Phishing"
    }

    func testDefaultErrorTemplate() {
        let error = NSError(domain: "TestDomain", code: 999, userInfo: nil)
        let url = URL(string: "https://example.com")!
        let html = ErrorPageHTMLFactory.html(for: error, url: url, header: "Custom Header")

        XCTAssertNotNil(html)
        XCTAssertTrue(html.contains("Custom Header")) // Check if the custom header is included in the HTML
    }

    func testDefaultErrorTemplate_WhenNetworkTimeoutError() {
        let networkTimeoutError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        let url = URL(string: "https://example.com")!
        let html = ErrorPageHTMLFactory.html(for: networkTimeoutError, url: url)

        XCTAssertNotNil(html)
        XCTAssertTrue(html.contains("NSURLErrorDomain")) // Check if the domain is included in the HTML
    }

}
