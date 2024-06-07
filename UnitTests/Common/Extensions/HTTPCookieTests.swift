//
//  HTTPCookieTests.swift
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
@testable import DuckDuckGo_Privacy_Browser

class HTTPCookieTests: XCTestCase {

    func testCookieBelongsToETLDPlus1Domain() {
        // Case 1: Cookie domain and eTLD+1 domain are the same
        var cookieProperties: [HTTPCookiePropertyKey: Any] = [
            .domain: "example.com",
            .path: "/",
            .name: "TestCookie",
            .value: "TestValue"
        ]
        var cookie = HTTPCookie(properties: cookieProperties)!
        XCTAssertTrue(cookie.belongsTo("example.com"))

        // Case 2: Cookie domain is a subdomain of the eTLD+1 domain
        cookieProperties[.domain] = "sub.example.com"
        cookie = HTTPCookie(properties: cookieProperties)!
        XCTAssertTrue(cookie.belongsTo("example.com"))

        // Case 3: Cookie domain is not a subdomain of the eTLD+1 domain
        cookieProperties[.domain] = "sub.other.com"
        cookie = HTTPCookie(properties: cookieProperties)!
        XCTAssertFalse(cookie.belongsTo("example.com"))

        // Edge Case 1: eTLD+1 domain is a substring of the cookie domain, but the cookie domain is not a subdomain
        cookieProperties[.domain] = "example.com.fake.com"
        cookie = HTTPCookie(properties: cookieProperties)!
        XCTAssertFalse(cookie.belongsTo("example.com"))

        // Edge Case 2: eTLD+1 domain and cookie domain are in different case
        cookieProperties[.domain] = "EXAMPLE.COM"
        cookie = HTTPCookie(properties: cookieProperties)!
        XCTAssertTrue(cookie.belongsTo("example.com"))

        // Edge Case 3: Empty domain
        cookieProperties[.domain] = ""
        cookie = HTTPCookie(properties: cookieProperties)!
        XCTAssertFalse(cookie.belongsTo("example.com"))

        // Edge Case 4: Numeric domains
        cookieProperties[.domain] = "123.456"
        cookie = HTTPCookie(properties: cookieProperties)!
        XCTAssertTrue(cookie.belongsTo("123.456"))
    }

}
