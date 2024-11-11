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

    func testThatNonSandboxLibraryDirectoryURLReturnsTheSameValueRegardlessOfSandbox() {
        let libraryURL = URL.nonSandboxLibraryDirectoryURL
        var pathComponents = libraryURL.path.components(separatedBy: "/")
        XCTAssertEqual(pathComponents.count, 4)

        pathComponents[2] = "user"

        XCTAssertEqual(pathComponents, ["", "Users", "user", "Library"])
    }

    func testThatNonSandboxApplicationSupportDirectoryURLReturnsTheSameValueRegardlessOfSandbox() {
        let libraryURL = URL.nonSandboxApplicationSupportDirectoryURL
        var pathComponents = libraryURL.path.components(separatedBy: "/")
        XCTAssertEqual(pathComponents.count, 5)

        pathComponents[2] = "user"

        XCTAssertEqual(pathComponents, ["", "Users", "user", "Library", "Application Support"])
    }

    func test_makeURL_from_addressBarString() {
        let data: [(string: String, expected: String)] = [
            ("https://duckduckgo.com/?q=search string with spaces", "https://duckduckgo.com/?q=search%20string%20with%20spaces"),
            ("define: foo", "https://duckduckgo.com/?q=define%3A%20foo"),
            ("test://hello/", "test://hello/"),
            ("localdomain", "https://duckduckgo.com/?q=localdomain"),
            ("   http://example.com\n", "http://example.com"),
            (" duckduckgo.com", "http://duckduckgo.com"),
            (" duckduckgo.c ", "https://duckduckgo.com/?q=duckduckgo.c"),
            ("localhost ", "http://localhost"),
            ("local ", "https://duckduckgo.com/?q=local"),
            ("test string with spaces", "https://duckduckgo.com/?q=test%20string%20with%20spaces"),
            ("http://💩.la:8080 ", "http://xn--ls8h.la:8080"),
            ("http:// 💩.la:8080 ", "https://duckduckgo.com/?q=http%3A%2F%2F%20%F0%9F%92%A9.la%3A8080"),
            ("https://xn--ls8h.la/path/to/resource", "https://xn--ls8h.la/path/to/resource"),
            ("1.4/3.4", "https://duckduckgo.com/?q=1.4%2F3.4"),
            ("16385-12228.72", "https://duckduckgo.com/?q=16385-12228.72"),
            ("user@localhost", "https://duckduckgo.com/?q=user%40localhost"),
            ("user@domain.com", "https://duckduckgo.com/?q=user%40domain.com"),
            ("http://user@domain.com", "http://user@domain.com"),
            ("http://user:@domain.com", "http://user:@domain.com"),
            ("http://user: @domain.com", "https://duckduckgo.com/?q=http%3A%2F%2Fuser%3A%20%40domain.com"),
            ("http://user:,,@domain.com", "http://user:,,@domain.com"),
            ("http://user:pass@domain.com", "http://user:pass@domain.com")
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

    func testWhenMakingUrlFromSuggestionPhaseContainingColon_ThenVerifyHypertextScheme() {
        let validUrl = URL.makeURL(fromSuggestionPhrase: "http://duckduckgo.com")
        XCTAssert(validUrl != nil)
        XCTAssertEqual(validUrl?.scheme, "http")

        let anotherValidUrl = URL.makeURL(fromSuggestionPhrase: "duckduckgo.com")
        XCTAssert(anotherValidUrl != nil)
        XCTAssertNotNil(validUrl?.scheme)

        let notURL = URL.makeURL(fromSuggestionPhrase: "type:pdf")
        XCTAssertNil(notURL)
    }

    func testThatEmailAddressesExtractsCommaSeparatedAddressesFromMailtoURL() throws {
        let url1 = try XCTUnwrap(URL(string: "mailto:dax@duck.com,donald@duck.com,example@duck.com"))
        XCTAssertEqual(url1.emailAddresses, ["dax@duck.com", "donald@duck.com", "example@duck.com"])

        if let url2 = URL(string: "mailto:  dax@duck.com,    donald@duck.com,  example@duck.com ") {
            XCTAssertEqual(url2.emailAddresses, ["dax@duck.com", "donald@duck.com", "example@duck.com"])
        }
    }

    func testThatEmailAddressesExtractsInvalidEmailAddresses() throws {
        // parity with Safari which also doesn't validate email addresses
        let url1 = try XCTUnwrap(URL(string: "mailto:dax@duck.com,donald,example"))
        XCTAssertEqual(url1.emailAddresses, ["dax@duck.com", "donald", "example"])

        if let url2 = URL(string: "mailto:dax@duck.com, ,,, ,, donald") {
            XCTAssertEqual(url2.emailAddresses, ["dax@duck.com", "donald"])
        }
    }

    func testWhenGetHostAndPort_WithPort_ThenHostAndPortIsReturned() throws {
        // Given
        let expected = "duckduckgo.com:1234"
        let sut = URL(string: "https://duckduckgo.com:1234")

        // When
        let result = sut?.hostAndPort()

        // Then
        XCTAssertEqual(expected, result)
    }

    func testWhenGetHostAndPort_WithoutPort_ThenHostReturned() throws {
        // Given
        let expected = "duckduckgo.com"
        let sut = URL(string: "https://duckduckgo.com")

        // When
        let result = sut?.hostAndPort()

        // Then
        XCTAssertEqual(expected, result)
    }

    func testIsChildWhenURLsSame() throws {
        let parentURL = URL(string: "https://duckduckgo.com/subscriptions")!
        let testedURL = URL(string: "https://duckduckgo.com/subscriptions")!
        XCTAssertTrue(testedURL.isChild(of: parentURL))
    }

    func testIsChildWhenTestedURLHasSubpath() throws {
        let parentURL = URL(string: "https://duckduckgo.com/subscriptions")!
        let testedURL = URL(string: "https://dax.duckduckgo.com/subscriptions/test")!
        XCTAssertTrue(testedURL.isChild(of: parentURL))
    }

    func testIsChildWhenTestedURLHasSubdomain() throws {
        let parentURL = URL(string: "https://duckduckgo.com/subscriptions")!
        let testedURL = URL(string: "https://dax.duckduckgo.com/subscriptions")!
        XCTAssertTrue(testedURL.isChild(of: parentURL))
    }

    func testIsChildWhenTestedURLHasSubdomainAndSubpath() throws {
        let parentURL = URL(string: "https://duckduckgo.com/subscriptions")!
        let testedURL = URL(string: "https://dax.duckduckgo.com/subscriptions/test")!
        XCTAssertTrue(testedURL.isChild(of: parentURL))
    }

    func testIsChildWhenTestedURLHasWWW() throws {
        let parentURL = URL(string: "https://duckduckgo.com/subscriptions")!
        let testedURL = URL(string: "https://www.duckduckgo.com/subscriptions/test/t")!
        XCTAssertTrue(testedURL.isChild(of: parentURL))
    }

    func testIsChildWhenParentHasParamThatShouldBeIgnored() throws {
        let parentURL = URL(string: "https://duckduckgo.com/subscriptions?environment=staging")!
        let testedURL = URL(string: "https://www.duckduckgo.com/subscriptions/test/t")!
        XCTAssertTrue(testedURL.isChild(of: parentURL))
    }

    func testIsChildWhenChildHasParamThatShouldBeIgnored() throws {
        let parentURL = URL(string: "https://duckduckgo.com/subscriptions")!
        let testedURL = URL(string: "https://duckduckgo.com/subscriptions?environment=staging")!
        XCTAssertTrue(testedURL.isChild(of: parentURL))
    }

    func testIsChildWhenChildHasPathAndParamThatShouldBeIgnored() throws {
        let parentURL = URL(string: "https://duckduckgo.com/subscriptions")!
        let testedURL = URL(string: "https://www.duckduckgo.com/subscriptions/test/t?environment=staging")!
        XCTAssertTrue(testedURL.isChild(of: parentURL))
    }

    func testIsChildWhenBothHaveParamThatShouldBeIgnored() throws {
        let parentURL = URL(string: "https://duckduckgo.com/subscriptions?environment=production")!
        let testedURL = URL(string: "https://www.duckduckgo.com/subscriptions/test/t?environment=staging")!
        XCTAssertTrue(testedURL.isChild(of: parentURL))
    }

    func testIsChildFailsWhenPathIsShorterSubstring() throws {
        let parentURL = URL(string: "https://duckduckgo.com/subscriptions")!
        let testedURL = URL(string: "https://duckduckgo.com/subscription")!
        XCTAssertFalse(testedURL.isChild(of: parentURL))
    }

    func testIsChildFailsWhenPathIsLonger() throws {
        let parentURL = URL(string: "https://duckduckgo.com/subscriptions")!
        let testedURL = URL(string: "https://duckduckgo.com/subscriptionszzz")!
        XCTAssertFalse(testedURL.isChild(of: parentURL))
    }

    func testIsChildFailsWhenPathIsNotComplete() throws {
        let parentURL = URL(string: "https://duckduckgo.com/subscriptions/welcome")!
        let testedURL = URL(string: "https://duckduckgo.com/subscriptions")!
        XCTAssertFalse(testedURL.isChild(of: parentURL))
    }
}
