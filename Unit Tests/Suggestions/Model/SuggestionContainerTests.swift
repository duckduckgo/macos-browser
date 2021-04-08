//
//  SuggestionContainerTests.swift
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
import BrowserServicesKit
@testable import DuckDuckGo_Privacy_Browser

final class SuggestionContainerTests: XCTestCase {

    func testWhenGetSuggestionsIsCalled_ThenContainerAsksAndHoldsSuggestionsFromLoader() {
        let suggestionLoadingMock = SuggestionLoadingMock()
        let suggestionContainer = SuggestionContainer(suggestionLoading: suggestionLoadingMock,
                                              bookmarkManager: LocalBookmarkManager.shared)

        suggestionContainer.getSuggestions(for: "test")

        let suggestions = [
            Suggestion.website(url: URL.duckDuckGo),
            Suggestion.website(url: URL.duckDuckGoAutocomplete)
        ]
        suggestionLoadingMock.completion?(suggestions, nil)

        XCTAssert(suggestionLoadingMock.getSuggestionsCalled)
        XCTAssertEqual(suggestionContainer.suggestions, suggestions)
    }

    func testWhenStopGettingSuggestionsIsCalled_ThenNoSuggestionsArePublished() {
        let suggestionLoadingMock = SuggestionLoadingMock()
        let suggestionContainer = SuggestionContainer(suggestionLoading: suggestionLoadingMock,
                                              bookmarkManager: LocalBookmarkManager.shared)

        suggestionContainer.getSuggestions(for: "test")
        suggestionContainer.stopGettingSuggestions()

        let suggestions = [ Suggestion.website(url: URL.duckDuckGo) ]
        suggestionLoadingMock.completion?(suggestions, nil)

        XCTAssert(suggestionLoadingMock.getSuggestionsCalled)
        XCTAssertNil(suggestionContainer.suggestions)
    }

}
