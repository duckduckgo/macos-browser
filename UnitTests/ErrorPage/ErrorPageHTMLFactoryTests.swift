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
@testable import DuckDuckGo_Privacy_Browser

class ErrorPageHTMLFactoryTests: XCTestCase {
    func testSSLErrorTemplate() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorServerCertificateUntrusted, userInfo: nil)
        let url = URL(string: "https://example.com")!
        let template = ErrorPageHTMLFactory.makeTemplate(for: error, url: url, errorCode: 123)

        XCTAssertNotNil(template)
        XCTAssertTrue(template is SSLErrorPageHTMLTemplate)
        XCTAssertEqual((template as? SSLErrorPageHTMLTemplate)?.domain, "example.com")
        XCTAssertEqual((template as? SSLErrorPageHTMLTemplate)?.errorCode, 123)
    }

    func testPhishingErrorTemplate() {
        let error = PhishingDetectionError.detected
        let url = URL(string: "https://example.com")!
        let template = ErrorPageHTMLFactory.makeTemplate(for: error, url: url)
        
        XCTAssertNotNil(template)
        XCTAssertTrue(template is PhishingErrorPageHTMLTemplate)
        let htmlTemplate = template!.makeHTMLFromTemplate()
        XCTAssertTrue(htmlTemplate.contains("Phishing"))
    }

    func testDefaultErrorTemplate() {
        let error = NSError(domain: "TestDomain", code: 999, userInfo: nil)
        let url = URL(string: "https://example.com")!
        let template = ErrorPageHTMLFactory.makeTemplate(for: error, url: url, header: "Custom Header")

        XCTAssertNotNil(template)
        XCTAssertTrue(template is ErrorPageHTMLTemplate)
        XCTAssertEqual((template as? ErrorPageHTMLTemplate)?.header, "Custom Header")
    }

    func testDefaultErrorTemplate_WhenNetworkTimeoutError() {
        let networkTimeoutError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        let url = URL(string: "https://example.com")!
        let template = ErrorPageHTMLFactory.makeTemplate(for: networkTimeoutError, url: url)

        XCTAssertNotNil(template)
        XCTAssertTrue(template is ErrorPageHTMLTemplate)
        let htmlTemplate = template!.makeHTMLFromTemplate()
        XCTAssertTrue(htmlTemplate.contains("NSURLErrorDomain"))
    }
}
