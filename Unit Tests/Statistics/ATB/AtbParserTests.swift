//
//  AtbParserTests.swift
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

class AtbParserTests: XCTestCase {

    private var testee = AtbParser()
    private var data = """
        {
            "version": "v77-5",
            "updateVersion": "v20-1"
        }
    """.data(using: .utf8)!

    func testWhenDataEmptyThenInvalidJsonErrorThrown() {
        XCTAssertThrowsError(try testee.convert(fromJsonData: Data()), "")
    }

    func testWhenJsonInvalidThenInvalidJsonErrorThrown() {
        XCTAssertThrowsError(try testee.convert(fromJsonData: "{[}".data(using: .utf16)!), "")
    }

    func testWhenJsonValidThenResultContainsAtb() throws {
        let validJson = data
        let result = try testee.convert(fromJsonData: validJson)
        XCTAssertEqual(result.version, "v77-5")
        XCTAssertEqual(result.updateVersion, "v20-1")
    }

}
