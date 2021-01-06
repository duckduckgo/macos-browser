//
//  SuggestionsTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

class SuggestionsTests: XCTestCase {

    func testWhenQueryIsEmptyThenSuggestionsAreNil() {
        let suggestionsAPIMock = SuggestionsAPIMock()
        let suggestions = Suggestions(suggestionsAPI: suggestionsAPIMock)

        let query = ""
        suggestions.getSuggestions(for: query)

        XCTAssertNil(suggestions.items)
    }

    func testWhenQueryIsNotEmptyThenAPIResultAreLoaded() {
        let suggestionsAPIMock = SuggestionsAPIMock()
        let suggestions = Suggestions(suggestionsAPI: suggestionsAPIMock)

        let suggestionsAPIResult = SuggestionsAPIResult.aSuggestionsAPIResult
        suggestionsAPIMock.suggestionsAPIResult = suggestionsAPIResult

        let query = "test"
        suggestions.getSuggestions(for: query)

        XCTAssertTrue(suggestions.items?.count == suggestionsAPIResult.items.count)
    }

}

extension SuggestionsAPIResult {

    static var aSuggestionsAPIResult: SuggestionsAPIResult {
        let phrase1 = "phrase"
        let value1 = "value1"
        let phrase2 = "phrase"
        let value2 = "value2"

        let json = """
        [ { "\(phrase1)": "\(value1)" }, { "\(phrase2)": "\(value2)" } ]
        """
        let data = json.data(using: .utf8)!

        // swiftlint:disable force_try
        return try! JSONDecoder().decode(SuggestionsAPIResult.self, from: data)
        // swiftlint:enable force_try
    }

}
