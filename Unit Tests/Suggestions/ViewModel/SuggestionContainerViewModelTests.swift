//
//  SuggestionContainerViewModelTests.swift
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

final class SuggestionContainerViewModelTests: XCTestCase {

    var cancellables = Set<AnyCancellable>()
    
    func testWhenNoSuggestionsThenNumberOfSuggestionsIs0() {
        let suggestionList = SuggestionContainer()
        let suggestionListViewModel = SuggestionContainerViewModel(suggestionList: suggestionList)
        
        XCTAssertEqual(suggestionListViewModel.numberOfSuggestions, 0)
    }
    
    func testWhenSelectionIndexIsNilThenSelectedSuggestionViewModelIsNil() {
        let suggestionList = SuggestionContainer()
        let suggestionListViewModel = SuggestionContainerViewModel(suggestionList: suggestionList)
        
        XCTAssertNil(suggestionListViewModel.selectionIndex)
        XCTAssertNil(suggestionListViewModel.selectedSuggestionViewModel)
    }
    
    func testWhenSuggestionIsSelectedThenSelectedSuggestionViewModelMatchSuggestions() {
        let suggestionListViewModel = SuggestionContainerViewModel.aSuggestionListViewModel

        let index = 0
        suggestionListViewModel.select(at: index)

        let selectedSuggestionViewModelExpectation = expectation(description: "Selected suggestion view model expectation")

        suggestionListViewModel.$selectedSuggestionViewModel.debounce(for: 0.1, scheduler: RunLoop.main).sink { selectedSuggestionViewModel in
            XCTAssertEqual(suggestionListViewModel.suggestionList.suggestions?[index], selectedSuggestionViewModel?.suggestion)
            selectedSuggestionViewModelExpectation.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testWhenSelectCalledWithIndexOutOfBoundsThenSelectedSuggestionViewModelIsNil() {
        let suggestionList = SuggestionContainer()
        let suggestionListViewModel = SuggestionContainerViewModel(suggestionList: suggestionList)
        
        suggestionListViewModel.select(at: 0)

        let selectedSuggestionViewModelExpectation = expectation(description: "Selected suggestion view model expectation")

        suggestionListViewModel.$selectedSuggestionViewModel.debounce(for: 0.1, scheduler: RunLoop.main).sink { selectedSuggestionViewModel in
            XCTAssertNil(suggestionListViewModel.selectionIndex)
            XCTAssertNil(selectedSuggestionViewModel)
            selectedSuggestionViewModelExpectation.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testWhenClearSelectionIsCalledThenNoSuggestonIsSeleted() {
        let suggestionListViewModel = SuggestionContainerViewModel.aSuggestionListViewModel

        suggestionListViewModel.select(at: 0)

        suggestionListViewModel.clearSelection()

        let selectedSuggestionViewModelExpectation2 = expectation(description: "Selected suggestion view model expectation")

        suggestionListViewModel.$selectedSuggestionViewModel.debounce(for: 0.1, scheduler: RunLoop.main).sink { selectedSuggestionViewModel in
            XCTAssertNil(suggestionListViewModel.selectionIndex)
            XCTAssertNil(suggestionListViewModel.selectedSuggestionViewModel)
            selectedSuggestionViewModelExpectation2.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testSelectNextIfPossible() {
        let suggestionListViewModel = SuggestionContainerViewModel.aSuggestionListViewModel
        
        suggestionListViewModel.selectNextIfPossible()
        XCTAssertEqual(suggestionListViewModel.selectionIndex, 0)
        
        suggestionListViewModel.selectNextIfPossible()
        XCTAssertEqual(suggestionListViewModel.selectionIndex, 1)
        
        let lastIndex = suggestionListViewModel.numberOfSuggestions - 1
        suggestionListViewModel.select(at: lastIndex)
        XCTAssertEqual(suggestionListViewModel.selectionIndex, lastIndex)
        
        suggestionListViewModel.selectNextIfPossible()
        XCTAssertNil(suggestionListViewModel.selectionIndex)
    }
    
    func testSelectPreviousIfPossible() {
        let suggestionListViewModel = SuggestionContainerViewModel.aSuggestionListViewModel
        
        suggestionListViewModel.selectPreviousIfPossible()
        XCTAssertEqual(suggestionListViewModel.selectionIndex, suggestionListViewModel.numberOfSuggestions - 1)
        
        suggestionListViewModel.selectPreviousIfPossible()
        XCTAssertEqual(suggestionListViewModel.selectionIndex, suggestionListViewModel.numberOfSuggestions - 2)
        
        let firstIndex = 0
        suggestionListViewModel.select(at: firstIndex)
        XCTAssertEqual(suggestionListViewModel.selectionIndex, firstIndex)
        
        suggestionListViewModel.selectPreviousIfPossible()
        XCTAssertNil(suggestionListViewModel.selectionIndex)
    }

}

extension SuggestionContainerViewModel {
    
    static var aSuggestionListViewModel: SuggestionContainerViewModel {
        let suggestionsAPIMock = SuggestionsAPIMock()
        let suggestionList = SuggestionContainer(suggestionsAPI: suggestionsAPIMock)
        let suggestionListViewModel = SuggestionContainerViewModel(suggestionList: suggestionList)

        let suggestionsAPIResult = RemoteSuggestionsAPIResult.aSuggestionsAPIResult
        suggestionsAPIMock.suggestionsAPIResult = suggestionsAPIResult

        let query = "query"
        suggestionList.getSuggestions(for: query)
        
        return suggestionListViewModel
    }
    
}
