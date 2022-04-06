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
        let data: [(string: String, expected: String)] = [
            ("https://duckduckgo.com/?q=search string with spaces", "https://duckduckgo.com/?q=search%20string%20with%20spaces"),
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

    func testWhenPunycodeUrlIsCalledOnEmptyStringThenUrlIsNotReturned() {
        XCTAssertNil(URL(trimmedAddressBarString: "")?.absoluteString)
    }

    func testWhenPunycodeUrlIsCalledOnQueryThenUrlIsNotReturned() {
        XCTAssertNil(URL(trimmedAddressBarString: " ")?.absoluteString)
    }

    func testWhenPunycodeUrlIsCalledOnQueryWithSpaceThenUrlIsNotReturned() {
        XCTAssertNil(URL(trimmedAddressBarString: "https://www.duckduckgo .com/html?q=search")?.absoluteString)
        XCTAssertNil(URL(trimmedAddressBarString: "https://www.duckduckgo.com/html?q =search")?.absoluteString)
    }

    func testWhenPunycodeUrlIsCalledOnLocalHostnameThenUrlIsNotReturned() {
        XCTAssertNil(URL(trimmedAddressBarString: "💩")?.absoluteString)
    }

    func testWhenDefineSearchRequestIsMadeItIsNotInterpretedAsLocalURL() {
        XCTAssertNil(URL(trimmedAddressBarString: "define:300/spartans")?.absoluteString)
    }

    func testAddressBarURLParsing() {
        let addresses = [
            "user@somehost.local:9091/index.html",
            "user@localhost:5000",
            "user:password@localhost:5000",
            "localhost",
            "localhost:5000",
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

        for address in addresses {
            let url = URL(trimmedAddressBarString: address)
            var expectedString = address
            let expectedScheme = address.split(separator: "/").first.flatMap {
                $0.hasSuffix(":") ? String($0).drop(suffix: ":") : nil
            }?.lowercased() ?? "http"
            if !address.hasPrefix(expectedScheme) {
                expectedString = expectedScheme + "://" + address
            }
            XCTAssertEqual(url?.scheme, expectedScheme)
            XCTAssertEqual(url?.absoluteString, expectedString)
        }
    }

    func testWhenPunycodeUrlIsCalledWithEncodedUrlsThenUrlIsReturned() {
        XCTAssertEqual("http://xn--ls8h.la", "💩.la".decodedURL?.absoluteString)
        XCTAssertEqual("http://xn--ls8h.la/", "💩.la/".decodedURL?.absoluteString)
        XCTAssertEqual("http://82.xn--b1aew.xn--p1ai", "82.мвд.рф".decodedURL?.absoluteString)
        XCTAssertEqual("http://xn--ls8h.la:8080", "http://💩.la:8080".decodedURL?.absoluteString)
        XCTAssertEqual("http://xn--ls8h.la", "http://💩.la".decodedURL?.absoluteString)
        XCTAssertEqual("https://xn--ls8h.la", "https://💩.la".decodedURL?.absoluteString)
        XCTAssertEqual("https://xn--ls8h.la/", "https://💩.la/".decodedURL?.absoluteString)
        XCTAssertEqual("https://xn--ls8h.la/path/to/resource", "https://💩.la/path/to/resource".decodedURL?.absoluteString)
        XCTAssertEqual("https://xn--ls8h.la/path/to/resource?query=true", "https://💩.la/path/to/resource?query=true".decodedURL?.absoluteString)
        XCTAssertEqual("https://xn--ls8h.la/%F0%9F%92%A9", "https://💩.la/💩".decodedURL?.absoluteString)
    }

}

private extension String {
    var decodedURL: URL? {
        URL(trimmedAddressBarString: self)
    }
}
