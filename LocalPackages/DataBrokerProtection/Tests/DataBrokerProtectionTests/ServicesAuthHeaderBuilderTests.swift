//
//  ServicesAuthHeaderBuilderTests.swift
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
@testable import DataBrokerProtection

final class ServicesAuthHeaderBuilderTests: XCTestCase {

    func testValidToken() {
        let builder = ServicesAuthHeaderBuilder()
        let result = builder.getAuthHeader("validToken123")
        XCTAssertEqual(result, "bearer validToken123")
    }

    func testNilToken() {
        let builder = ServicesAuthHeaderBuilder()
        let result = builder.getAuthHeader(nil)
        XCTAssertNil(result)
    }

    func testEmptyToken() {
        let builder = ServicesAuthHeaderBuilder()
        let result = builder.getAuthHeader("")
        XCTAssertNil(result)
    }

    func testTokenWithSpaces() {
        let builder = ServicesAuthHeaderBuilder()
        let result = builder.getAuthHeader("  tokenWithSpaces  ")
        XCTAssertEqual(result, "bearer   tokenWithSpaces  ")
    }

    func testTokenWithSpecialCharacters() {
        let builder = ServicesAuthHeaderBuilder()
        let result = builder.getAuthHeader("token@123!#")
        XCTAssertEqual(result, "bearer token@123!#")
    }

    func testLongToken() {
        let builder = ServicesAuthHeaderBuilder()
        let result = builder.getAuthHeader("averylongtokenthatneedstobeincludedintheheader")
        XCTAssertEqual(result, "bearer averylongtokenthatneedstobeincludedintheheader")
    }

    func testTokenWithLeadingBearer() {
        let builder = ServicesAuthHeaderBuilder()
        let result = builder.getAuthHeader("bearer token123")
        XCTAssertEqual(result, "bearer bearer token123")
    }

    func testTokenWithLeadingBearerUppercase() {
        let builder = ServicesAuthHeaderBuilder()
        let result = builder.getAuthHeader("Bearer token456")
        XCTAssertEqual(result, "bearer Bearer token456")
    }

}
