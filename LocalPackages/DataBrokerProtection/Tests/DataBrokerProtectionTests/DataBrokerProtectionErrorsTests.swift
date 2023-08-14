//
//  DataBrokerProtectionErrorsTests.swift
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

final class DataBrokerProtectionErrorsTests: XCTestCase {

    func testWhenParsingErrorFails_thenCorrectErrorIsReturned() {
        let params = ["something": "unknown"]

        let result = DataBrokerProtectionError.parse(params: params)

        XCTAssertEqual(result, .parsingErrorObjectFailed)
    }

    func testWhenErrorIsUnknown_thenCorrectErrorIsReturned() {
        let params = ["error": "unknown"]

        let result = DataBrokerProtectionError.parse(params: params)

        XCTAssertEqual(result, .unknown("unknown"))
    }

    func testWhenErrorisNoActionFound_thenCorrectErrorIsReturned() {
        let params = ["error": "No action found."]

        let result = DataBrokerProtectionError.parse(params: params)

        XCTAssertEqual(result, .noActionFound)
    }
}
