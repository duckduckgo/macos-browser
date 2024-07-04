//
//  URLTokenValidatorTests.swift
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
@testable import DuckDuckGo_Privacy_Browser

class URLTokenValidatorTests: XCTestCase {

    var validator: URLTokenValidator!

    override func setUp() {
        super.setUp()
        validator = URLTokenValidator.shared
    }

    override func tearDown() {
        validator = nil
        super.tearDown()
    }

    func testGenerateToken() {
        let url = URL(string: "https://example.com/")!
        let token = validator.generateToken(for: url)

        XCTAssertNotNil(token, "Token should not be nil")
        XCTAssertTrue(token.contains(":"), "Token should contain a colon separating the signature and timestamp")
    }

    func testValidateToken() {
        let url = URL(string: "https://example.com/")!
        let token = validator.generateToken(for: url)

        let isValid = validator.validateToken(token, for: url)
        XCTAssertTrue(isValid, "Token should be valid for the given URL")
    }

    func testValidateTokenWithInvalidURL() {
        let url = URL(string: "https://example.com/some-page")!
        let token = validator.generateToken(for: url)

        let invalidURL = URL(string: "https://example.com/other-page")!
        let isValid = validator.validateToken(token, for: invalidURL)
        XCTAssertFalse(isValid, "Token should not be valid for a different URL")
    }

    func testValidateTokenWithGarbageData() {
        let url = URL(string: "https://example.com/special-page")!
        let garbageToken = "Dxa0cx+a51qfucPFMxqIbAiuQHFJx/2TYseu73ww"

        let isValid = validator.validateToken(garbageToken, for: url)
        XCTAssertFalse(isValid, "Token should not be valid for the given URL when the token is garbage data")
    }

    func testValidateTokenWithExpiredTimestamp() {
        let url = URL(string: "https://example.com/")!
        let token = validator.generateToken(for: url)

        // Simulate an expired token by manipulating the timestamp
        let components = token.split(separator: ":")
        guard components.count == 2, let timestampString = components.last else {
            XCTFail("Token format is invalid")
            return
        }

        let expiredTimestamp = String(Int(timestampString)! - Int(validator.timeWindow) - 1)
        let expiredToken = "\(components.first!):\(expiredTimestamp)"

        let isValid = validator.validateToken(expiredToken, for: url)
        XCTAssertFalse(isValid, "Token should not be valid if the timestamp is expired")
    }
}
