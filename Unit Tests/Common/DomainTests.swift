//
//  DomainTests.swift
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
@testable import DuckDuckGo_Privacy_Browser

class DomainTests: XCTestCase {

    func testDomain() {
        #warning("add more tests when Punycode SpuffChecker ready")
        let testValues: [(address: String, displayName: String?)] = [
            ("https://", nil),
            ("https://duckduckgo.com", "duckduckgo.com"),
            ("https://www.duckduckgo.com/html?q=search", "duckduckgo.com"),
            ("http://xn--ls8h.la", "xn--ls8h.la"),
            ("http://xn--ls8h.la/", "xn--ls8h.la"),
            ("http://82.xn--b1aew.xn--p1ai", "82.xn--b1aew.xn--p1ai"),
            ("http://www.82.xn--b1aew.xn--p1ai", "82.xn--b1aew.xn--p1ai"),
            ("http://xn--ls8h.la:8080", "xn--ls8h.la"),
            ("http://xn--ls8h.la", "xn--ls8h.la"),
            ("https://xn--ls8h.la", "xn--ls8h.la"),
            ("https://xn--ls8h.la/", "xn--ls8h.la"),
            ("https://www.xn--ls8h.la/", "xn--ls8h.la"),
            ("https://xn--ls8h.la/path/to/resource", "xn--ls8h.la"),
            ("https://xn--ls8h.la/path/to/resource?query=true", "xn--ls8h.la"),
            ("https://xn--ls8h.la/%F0%9F%92%A9", "xn--ls8h.la")
        ]

        for (address, displayName) in testValues {
            let url = URL(string: address)!
            let urlDomain = url.domain
            let hostDomain = url.host.map(Domain.init(host:))

            XCTAssertEqual(urlDomain, hostDomain)

            XCTAssertEqual(url.host, urlDomain?.hostName, "hostName check failed for \"\(address)\"")
            XCTAssertEqual(url.host, hostDomain?.hostName, "hostName check failed for \"\(address)\"")

            XCTAssertEqual(url.host, urlDomain.map { "\($0)" }, "string convertion check failed for \"\(address)\"")
            XCTAssertEqual(url.host, hostDomain.map { "\($0)" }, "string convertion check failed for \"\(address)\"")

            XCTAssertEqual(urlDomain?.displayName, displayName, "displayName check failed for \"\(address)\"")
            XCTAssertEqual(hostDomain?.displayName, displayName, "displayName check failed for \"\(address)\"")
        }

    }

}
