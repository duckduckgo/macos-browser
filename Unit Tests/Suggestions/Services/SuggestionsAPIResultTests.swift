//
//  SuggestionsAPIResultTests.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

final class SuggestionsAPIResultTests: XCTestCase {

    func testWhenInitializedFromEmptyThenNoItemsAreInTheResult() {
        let json = """
        []
        """
        let data = json.data(using: .utf8)!

        guard let suggestionsAPIResult = try? JSONDecoder().decode(SuggestionsAPIResult.self, from: data) else {
            XCTFail("Decoding of SuggestionsAPIResult failed")
            return
        }

        XCTAssertEqual(suggestionsAPIResult.items.count, 0)
    }

    func testWhenJSONHasValidFormatThenItemsAreInTheResult() {
        let phrase1 = "phrase"
        let value1 = "value1"
        let phrase2 = "phrase"
        let value2 = "value2"

        let json = """
        [ { "\(phrase1)": "\(value1)" }, { "\(phrase2)": "\(value2)" } ]
        """
        let data = json.data(using: .utf8)!

        guard let suggestionsAPIResult = try? JSONDecoder().decode(SuggestionsAPIResult.self, from: data) else {
            XCTFail("Decoding of SuggestionsAPIResult failed")
            return
        }

        XCTAssertEqual(suggestionsAPIResult.items.count, 2)
        XCTAssertEqual(suggestionsAPIResult.items[0][phrase1], value1)
        XCTAssertEqual(suggestionsAPIResult.items[1][phrase2], value2)
    }

    func testWhenJSONHasInvalidFormatThenDecodingFails() {
        let json = """
        { "phrase": "value1" }, { "phrase": "value2" }
        """
        let data = json.data(using: .utf8)!

        let suggestionsAPIResult = try? JSONDecoder().decode(SuggestionsAPIResult.self, from: data)
        if suggestionsAPIResult != nil {
            XCTFail("Decoding should fail")
            return
        }

        XCTAssert(true)
    }

}
