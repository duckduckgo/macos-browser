//
//  String+PunycodeTests.swift
//  DuckDuckGo
//
//  Copyright © 2017 DuckDuckGo. All rights reserved.
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

class StringPunycodeTests: XCTestCase {

    func testWhenPunycodeUrlIsCalledOnEmptyStringThenUrlIsNotReturned() {
        XCTAssertNil("".punycodedUrl?.absoluteString)
    }

    func testWhenPunycodeUrlIsCalledOnQueryThenUrlIsNotReturned() {
        XCTAssertNil(" ".punycodedUrl?.absoluteString)
    }

    func testWhenPunycodeUrlIsCalledOnQueryWithSpaceThenUrlIsNotReturned() {
        XCTAssertNil("https://www.duckduckgo .com/html?q=search".punycodedUrl?.absoluteString)
    }

    func testWhenPunycodeUrlIsCalledOnLocalHostnameThenUrlIsNotReturned() {
        XCTAssertNil("💩".punycodedUrl?.absoluteString)
    }

    func testWhenPunycodeUrlSinglePeriodIsLastThenUrlIsNotReturned() {
        XCTAssertNil("duckduckgo.".punycodedUrl?.absoluteString)
    }

    func testWhenPunycodeUrlIsCalledWithSimpleUrlsThenUrlIsReturned() {
        let addresses = [
            "https://",
            "http://duckduckgo.com",
            "https://duckduckgo.com",
            "https://duckduckgo.com/",
            "duckduckgo.com",
            "duckduckgo.com/html?q=search",
            "www.duckduckgo.com",
            "https://www.duckduckgo.com/html?q=search",
            "https://www.duckduckgo.com/html/?q=search",
            "ftp://www.duckduckgo.com",
            "file:///users/user/Documents/afile"
        ]

        for var address in addresses {
            let url = address.punycodedUrl
            let expectedScheme = address.split(separator: "/").first.flatMap {
                $0.hasSuffix(":") ? String($0).drop(suffix: ":") : nil
            } ?? "http"
            if !address.hasPrefix(expectedScheme) {
                address = expectedScheme + "://" + address
            }
            XCTAssertEqual(url?.scheme, expectedScheme)
            XCTAssertEqual(url?.absoluteString, address)
        }
    }

    func testWhenPunycodeUrlIsCalledWithEncodedUrlsThenUrlIsReturned() {
        XCTAssertEqual("http://xn--ls8h.la", "💩.la".punycodedUrl?.absoluteString)
        XCTAssertEqual("http://xn--ls8h.la/", "💩.la/".punycodedUrl?.absoluteString)
        XCTAssertEqual("http://82.xn--b1aew.xn--p1ai", "82.мвд.рф".punycodedUrl?.absoluteString)
        XCTAssertEqual("http://xn--ls8h.la:8080", "http://💩.la:8080".punycodedUrl?.absoluteString)
        XCTAssertEqual("http://xn--ls8h.la", "http://💩.la".punycodedUrl?.absoluteString)
        XCTAssertEqual("https://xn--ls8h.la", "https://💩.la".punycodedUrl?.absoluteString)
        XCTAssertEqual("https://xn--ls8h.la/", "https://💩.la/".punycodedUrl?.absoluteString)
        XCTAssertEqual("https://xn--ls8h.la/path/to/resource", "https://💩.la/path/to/resource".punycodedUrl?.absoluteString)
        XCTAssertEqual("https://xn--ls8h.la/path/to/resource?query=true", "https://💩.la/path/to/resource?query=true".punycodedUrl?.absoluteString)
        XCTAssertEqual("https://xn--ls8h.la/%F0%9F%92%A9", "https://💩.la/💩".punycodedUrl?.absoluteString)
    }

}
