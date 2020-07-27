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

class SuggestionViewModelTests: XCTestCase {

    func testWhenSuggestionIsPhraseThenAttributedStringIsTheSame() {
        let phrase = "phrase"
        let suggestion = Suggestion.phrase(phrase: phrase)
        let suggestionViewModel = SuggestionViewModel(suggestion: suggestion)
        
        XCTAssertEqual(phrase, suggestionViewModel.attributedString.string)
    }
    
    func testWhenSuggestionIsWebsiteWithoutTitleThenAttributedStringIsURLWithoutScheme() {
        let urlString = "https://spreadprivacy.com"
        let url = URL(string: urlString)!
        let suggestion = Suggestion.website(url: url, title: nil)
        let suggestionViewModel = SuggestionViewModel(suggestion: suggestion)
        
        XCTAssert(suggestionViewModel.attributedString.string.hasSuffix("spreadprivacy.com"))
        XCTAssert(!suggestionViewModel.attributedString.string.hasPrefix("https://"))
    }
    
    func testWhenSuggestionIsWebsiteWithTitleThenAttributedStringIsTitleAndURLWithoutScheme() {
        let urlString = "https://spreadprivacy.com"
        let url = URL(string: urlString)!
        let title = "Privacy"
        let suggestion = Suggestion.website(url: url, title: title)
        let suggestionViewModel = SuggestionViewModel(suggestion: suggestion)
        
        XCTAssert(suggestionViewModel.attributedString.string.hasSuffix("spreadprivacy.com"))
        XCTAssert(suggestionViewModel.attributedString.string.hasPrefix(title))
    }

}
