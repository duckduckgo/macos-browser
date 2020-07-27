//
//  SuggestionsViewModelTests.swift
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

class SuggestionsViewModelTests: XCTestCase {
    
    func testWhenNoSuggestionsThenNumberOfSuggestionsIs0() {
        let suggestions = Suggestions()
        let suggestionsViewModel = SuggestionsViewModel(suggestions: suggestions)
        
        XCTAssertEqual(suggestionsViewModel.numberOfSuggestions, 0)
    }
    
    func testWhenSuggestionsAreFetchedThenNumberOfSuggestionsIsSumOfAll() {
        let suggestionsViewModel = SuggestionsViewModel.aSuggestionsViewModel
        
        XCTAssertEqual(suggestionsViewModel.numberOfSuggestions,
                       suggestionsViewModel.suggestions.items.local!.count +
                        suggestionsViewModel.suggestions.items.remote!.count)
    }
    
    func testWhenSelectionIndexIsNilThenSelectedSuggestionViewModelIsNil() {
        let suggestions = Suggestions()
        let suggestionsViewModel = SuggestionsViewModel(suggestions: suggestions)
        
        XCTAssertNil(suggestionsViewModel.selectionIndex)
        XCTAssertNil(suggestionsViewModel.selectedSuggestionViewModel)
    }
    
    func testWhenSuggestionIsSelectedThenSelectedSuggestionViewModelMatchSuggestions() {
        let suggestionsViewModel = SuggestionsViewModel.aSuggestionsViewModel
    
        let index = 0
        suggestionsViewModel.select(at: index)
        
        XCTAssertEqual(suggestionsViewModel.suggestions.items.remote?[index], suggestionsViewModel.selectedSuggestionViewModel?.suggestion)
    }
    
    func testWhenSelectCalledWithIndexOutOfBoundsThenSelectedSuggestionViewModelIsNil() {
        let suggestions = Suggestions()
        let suggestionsViewModel = SuggestionsViewModel(suggestions: suggestions)
        
        suggestionsViewModel.select(at: 0)
        
        XCTAssertNil(suggestionsViewModel.selectionIndex)
        XCTAssertNil(suggestionsViewModel.selectedSuggestionViewModel)
    }
    
    func testWhenClearSelectionIsCalledThenNoSuggestonIsSeleted() {
        let suggestionsViewModel = SuggestionsViewModel.aSuggestionsViewModel
        
        suggestionsViewModel.select(at: 0)
        
        XCTAssertNotNil(suggestionsViewModel.selectionIndex)
        XCTAssertNotNil(suggestionsViewModel.selectedSuggestionViewModel)
        
        suggestionsViewModel.clearSelection()
        
        XCTAssertNil(suggestionsViewModel.selectionIndex)
        XCTAssertNil(suggestionsViewModel.selectedSuggestionViewModel)
    }
    
    func testSelectNextIfPossible() {
        let suggestionsViewModel = SuggestionsViewModel.aSuggestionsViewModel
        
        suggestionsViewModel.selectNextIfPossible()
        XCTAssertEqual(suggestionsViewModel.selectionIndex, 0)
        
        suggestionsViewModel.selectNextIfPossible()
        XCTAssertEqual(suggestionsViewModel.selectionIndex, 1)
        
        let lastIndex = suggestionsViewModel.numberOfSuggestions - 1
        suggestionsViewModel.select(at: lastIndex)
        XCTAssertEqual(suggestionsViewModel.selectionIndex, lastIndex)
        
        suggestionsViewModel.selectNextIfPossible()
        XCTAssertNil(suggestionsViewModel.selectionIndex)
    }
    
    func testSelectPreviousIfPossible() {
        let suggestionsViewModel = SuggestionsViewModel.aSuggestionsViewModel
        
        suggestionsViewModel.selectPreviousIfPossible()
        XCTAssertEqual(suggestionsViewModel.selectionIndex, suggestionsViewModel.numberOfSuggestions - 1)
        
        suggestionsViewModel.selectPreviousIfPossible()
        XCTAssertEqual(suggestionsViewModel.selectionIndex, suggestionsViewModel.numberOfSuggestions - 2)
        
        let firstIndex = 0
        suggestionsViewModel.select(at: firstIndex)
        XCTAssertEqual(suggestionsViewModel.selectionIndex, firstIndex)
        
        suggestionsViewModel.selectPreviousIfPossible()
        XCTAssertNil(suggestionsViewModel.selectionIndex)
    }

}

extension SuggestionsViewModel {
    
    static var aSuggestionsViewModel: SuggestionsViewModel {
        let suggestionsAPIMock = SuggestionsAPIMock()
        let historyStoreMock = HistoryStoreMock()
        let suggestions = Suggestions(suggestionsAPI: suggestionsAPIMock, historyStore: historyStoreMock)
        let suggestionsViewModel = SuggestionsViewModel(suggestions: suggestions)

        let suggestionsAPIResult = SuggestionsAPIResult.aSuggestionsAPIResult
        suggestionsAPIMock.suggestionsAPIResult = suggestionsAPIResult
        let websiteVisits = WebsiteVisit.aWebsiteVisits
        historyStoreMock.websiteVisits = websiteVisits

        let query = "query"
        suggestions.getSuggestions(for: query)
        
        return suggestionsViewModel
    }
    
}
