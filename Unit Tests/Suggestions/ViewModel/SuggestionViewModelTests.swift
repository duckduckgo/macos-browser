//
//  SuggestionViewModelTests.swift
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

final class SuggestionViewModelTests: XCTestCase {

    func testWhenSuggestionIsPhraseThenStringIsTheSame() {
        let phrase = "phrase"
        let suggestion = Suggestion.phrase(phrase: phrase)
        let suggestionViewModel = SuggestionViewModel(suggestion: suggestion, userStringValue: "")
        
        XCTAssertEqual(phrase, suggestionViewModel.string)
    }
    
    func testWhenSuggestionIsWebsiteThenStringIsUrlStringWithoutSchemeAndWWW() {
        let urlString = "https://spreadprivacy.com"
        let url = URL(string: urlString)!
        let suggestion = Suggestion.website(url: url)
        let suggestionViewModel = SuggestionViewModel(suggestion: suggestion, userStringValue: "")
        
        XCTAssert(suggestionViewModel.string.hasSuffix("spreadprivacy.com"))
        XCTAssert(!suggestionViewModel.string.hasPrefix("https://"))
    }
    
    func testWhenSuggestionIsWebsiteWithTitleThenStringIsTitleAndURLWithoutScheme() {
        let urlString = "https://spreadprivacy.com"
        let url = URL(string: urlString)!
        let suggestion = Suggestion.website(url: url)
        let suggestionViewModel = SuggestionViewModel(suggestion: suggestion, userStringValue: "")

        XCTAssertEqual(suggestionViewModel.string, "spreadprivacy.com")
    }

}
