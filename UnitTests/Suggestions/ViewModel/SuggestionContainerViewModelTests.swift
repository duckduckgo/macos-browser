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
import BrowserServicesKit
@testable import DuckDuckGo_Privacy_Browser

final class SuggestionContainerViewModelTests: XCTestCase {

    var cancellables = Set<AnyCancellable>()

    func testWhenSelectionIndexIsNilThenSelectedSuggestionViewModelIsNil() {
        let suggestionContainer = SuggestionContainer()
        let suggestionContainerViewModel = SuggestionContainerViewModel(suggestionContainer: suggestionContainer)

        XCTAssertNil(suggestionContainerViewModel.selectionIndex)
        XCTAssertNil(suggestionContainerViewModel.selectedSuggestionViewModel)
    }

    func testWhenSuggestionIsSelectedThenSelectedSuggestionViewModelMatchSuggestions() {
        let suggestionContainerViewModel = SuggestionContainerViewModel.aSuggestionContainerViewModel

        let index = 0

        let selectedSuggestionViewModelExpectation = expectation(description: "Selected suggestion view model expectation")
        suggestionContainerViewModel.$selectedSuggestionViewModel.sink { selectedSuggestionViewModel in
            if let selectedSuggestionViewModel = selectedSuggestionViewModel {
                XCTAssertEqual(suggestionContainerViewModel.suggestionContainer.result?.all[index], selectedSuggestionViewModel.suggestion)
                selectedSuggestionViewModelExpectation.fulfill()
            }
        } .store(in: &cancellables)

        suggestionContainerViewModel.select(at: index)
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenSelectCalledWithIndexOutOfBoundsThenSelectedSuggestionViewModelIsNil() {
        let suggestionContainer = SuggestionContainer()
        let suggestionListViewModel = SuggestionContainerViewModel(suggestionContainer: suggestionContainer)

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
        let suggestionListViewModel = SuggestionContainerViewModel.aSuggestionContainerViewModel

        suggestionListViewModel.select(at: 0)

        suggestionListViewModel.clearSelection()

        let selectedSuggestionViewModelExpectation2 = expectation(description: "Selected suggestion view model expectation")

        suggestionListViewModel.$selectedSuggestionViewModel.debounce(for: 0.1, scheduler: RunLoop.main).sink { _ in
            XCTAssertNil(suggestionListViewModel.selectionIndex)
            XCTAssertNil(suggestionListViewModel.selectedSuggestionViewModel)
            selectedSuggestionViewModelExpectation2.fulfill()
        } .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testSelectNextIfPossible() {
        let suggestionListViewModel = SuggestionContainerViewModel.aSuggestionContainerViewModel

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
        let suggestionListViewModel = SuggestionContainerViewModel.aSuggestionContainerViewModel

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

    static var aSuggestionContainerViewModel: SuggestionContainerViewModel {
        let suggestionLoadingMock = SuggestionLoadingMock()
        let historyCoordinatingMock = HistoryCoordinatingMock()
        let suggestionContainer = SuggestionContainer(suggestionLoading: suggestionLoadingMock,
                                                      historyCoordinating: historyCoordinatingMock,
                                                      bookmarkManager: LocalBookmarkManager.shared)
        let suggestionContainerViewModel = SuggestionContainerViewModel(suggestionContainer: suggestionContainer)

        suggestionContainer.getSuggestions(for: "Test")
        suggestionLoadingMock.completion?(SuggestionResult.aSuggestionResult, nil )

        while suggestionContainer.result == nil {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }

        return suggestionContainerViewModel
    }

    convenience init(suggestionContainer: SuggestionContainer) {
        self.init(isHomePage: false, isDisposable: false, suggestionContainer: suggestionContainer)
    }

}

extension SuggestionResult {

    static var aSuggestionResult: SuggestionResult {
        let topHits = [
            Suggestion.website(url: URL.duckDuckGo),
            Suggestion.website(url: URL.duckDuckGoAutocomplete)
        ]
        return SuggestionResult(topHits: topHits,
                                duckduckgoSuggestions: [],
                                historyAndBookmarks: [])
    }

}
