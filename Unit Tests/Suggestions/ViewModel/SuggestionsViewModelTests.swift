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
import Combine
@testable import DuckDuckGo_Privacy_Browser

final class SuggestionsViewModelTests: XCTestCase {

    var cancellables = Set<AnyCancellable>()
    
    func testWhenNoSuggestionsThenNumberOfSuggestionsIs0() {
        let suggestions = Suggestions()
        let suggestionsViewModel = SuggestionsViewModel(suggestions: suggestions)
        
        XCTAssertEqual(suggestionsViewModel.numberOfSuggestions, 0)
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

        let selectedSuggestionViewModelExpectation = expectation(description: "Selected suggestion view model expectation")

        suggestionsViewModel.$selectedSuggestionViewModel.debounce(for: 0.1, scheduler: RunLoop.main).sink { selectedSuggestionViewModel in
            XCTAssertEqual(suggestionsViewModel.suggestions.items?[index], selectedSuggestionViewModel?.suggestion)
            selectedSuggestionViewModelExpectation.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testWhenSelectCalledWithIndexOutOfBoundsThenSelectedSuggestionViewModelIsNil() {
        let suggestions = Suggestions()
        let suggestionsViewModel = SuggestionsViewModel(suggestions: suggestions)
        
        suggestionsViewModel.select(at: 0)

        let selectedSuggestionViewModelExpectation = expectation(description: "Selected suggestion view model expectation")

        suggestionsViewModel.$selectedSuggestionViewModel.debounce(for: 0.1, scheduler: RunLoop.main).sink { selectedSuggestionViewModel in
            XCTAssertNil(suggestionsViewModel.selectionIndex)
            XCTAssertNil(selectedSuggestionViewModel)
            selectedSuggestionViewModelExpectation.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testWhenClearSelectionIsCalledThenNoSuggestonIsSeleted() {
        let suggestionsViewModel = SuggestionsViewModel.aSuggestionsViewModel

        suggestionsViewModel.select(at: 0)

        suggestionsViewModel.clearSelection()

        let selectedSuggestionViewModelExpectation2 = expectation(description: "Selected suggestion view model expectation")

        suggestionsViewModel.$selectedSuggestionViewModel.debounce(for: 0.1, scheduler: RunLoop.main).sink { selectedSuggestionViewModel in
            XCTAssertNil(suggestionsViewModel.selectionIndex)
            XCTAssertNil(suggestionsViewModel.selectedSuggestionViewModel)
            selectedSuggestionViewModelExpectation2.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
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
        let suggestions = Suggestions(suggestionsAPI: suggestionsAPIMock)
        let suggestionsViewModel = SuggestionsViewModel(suggestions: suggestions)

        let suggestionsAPIResult = SuggestionsAPIResult.aSuggestionsAPIResult
        suggestionsAPIMock.suggestionsAPIResult = suggestionsAPIResult

        let query = "query"
        suggestions.getSuggestions(for: query)
        
        return suggestionsViewModel
    }
    
}
