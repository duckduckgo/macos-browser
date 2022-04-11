//
//  URLExtensionTests.swift
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
import Combine
@testable import DuckDuckGo_Privacy_Browser

final class URLExtensionTests: XCTestCase {

    func test_external_urls_are_valid() {
        XCTAssertTrue("mailto://user@host.tld".url!.isValid)
        XCTAssertTrue("sms://+44776424232323".url!.isValid)
        XCTAssertTrue("ftp://example.com".url!.isValid)
    }

    func test_navigational_urls_are_valid() {
        XCTAssertTrue("http://example.com".url!.isValid)
        XCTAssertTrue("https://example.com".url!.isValid)
        XCTAssertTrue("http://localhost".url!.isValid)
        // XCTAssertTrue("http://localdomain".url!.isValid) // local domain URLs are not supported at this time
    }

    func test_when_no_scheme_in_string_url_has_scheme() {
        XCTAssertEqual("duckduckgo.com".url!.absoluteString, "http://duckduckgo.com")
        XCTAssertEqual("example.com".url!.absoluteString, "http://example.com")
        XCTAssertEqual("localhost".url!.absoluteString, "http://localhost")
    }

    func test_makeURL_from_addressBarString() {
        #warning("fix spaces in search query")
//            ("https://duckduckgo.com/?q=search string with spaces", "https://duckduckgo.com/?q=search%20string%20with%20spaces")
        let data: [(string: String, expected: String)] = [
            ("   http://example.com\n", "http://example.com"),
            (" duckduckgo.com", "http://duckduckgo.com"),
            (" duckduckgo.c ", "https://duckduckgo.com/?q=duckduckgo.c"),
            ("localhost ", "http://localhost"),
            ("local ", "https://duckduckgo.com/?q=local"),
            ("test string with spaces", "https://duckduckgo.com/?q=test%20string%20with%20spaces"),
            ("http://💩.la:8080 ", "http://xn--ls8h.la:8080"),
            ("http:// 💩.la:8080 ", "https://duckduckgo.com/?q=http%3A%2F%2F%20%F0%9F%92%A9.la%3A8080"),
            ("https://xn--ls8h.la/path/to/resource", "https://xn--ls8h.la/path/to/resource")
        ]

        for (string, expected) in data {
            let url = URL.makeURL(from: string)!
            XCTAssertEqual(expected, url.absoluteString)
        }
    }

    func test_sanitizedForQuarantine() {
        let data: [(string: String, expected: String?)] = [
            ("file:///local/file/name", nil),
            ("http://example.com", "http://example.com"),
            ("https://duckduckgo.com", "https://duckduckgo.com"),
            ("data://asdfgb", nil),
            ("localhost", "localhost"),
            ("blob://afasdg", nil),
            ("http://user:pass@duckduckgo.com", "http://duckduckgo.com"),
            ("https://user:pass@duckduckgo.com", "https://duckduckgo.com"),
            ("https://user:pass@releases.usercontent.com/asdfg?arg=AWS4-HMAC&Credential=AKIA",
             "https://releases.usercontent.com/asdfg?arg=AWS4-HMAC&Credential=AKIA"),
            ("ftp://user:pass@duckduckgo.com", "ftp://duckduckgo.com")
        ]

        for (string, expected) in data {
            let url = URL(string: string)!.sanitizedForQuarantine()
            XCTAssertEqual(url?.absoluteString, expected, string)
        }
    }

    func testWhenOneSlashIsMissingAfterHypertextScheme_ThenItShouldBeAdded() {
        let data: [(string: String, expected: String?)] = [
            ("http:/duckduckgo.com", "http://duckduckgo.com"),
            ("http://duckduckgo.com", "http://duckduckgo.com"),
            ("https:/duckduckgo.com", "https://duckduckgo.com"),
            ("https://duckduckgo.com", "https://duckduckgo.com"),
            ("file:/Users/user/file.txt", "file:/Users/user/file.txt"),
            ("file://domain/file.txt", "file://domain/file.txt"),
            ("file:///Users/user/file.txt", "file:///Users/user/file.txt")
        ]

        for (string, expected) in data {
            let url = URL.makeURL(from: string)
            XCTAssertEqual(url?.absoluteString, expected)
        }
    }

}
