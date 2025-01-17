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
import Suggestions
@testable import DuckDuckGo_Privacy_Browser

final class SuggestionContainerViewModelTests: XCTestCase {

    var suggestionLoadingMock: SuggestionLoadingMock!
    var historyCoordinatingMock: HistoryCoordinatingMock!
    var suggestionContainer: SuggestionContainer!
    var suggestionContainerViewModel: SuggestionContainerViewModel!

    var cancellables = Set<AnyCancellable>()

    override func setUp() {
        SearchPreferences.shared.showAutocompleteSuggestions = true
        suggestionLoadingMock = SuggestionLoadingMock()
        historyCoordinatingMock = HistoryCoordinatingMock()
        suggestionContainer = SuggestionContainer(openTabsProvider: { [] },
                                                  suggestionLoading: suggestionLoadingMock,
                                                  historyCoordinating: historyCoordinatingMock,
                                                  bookmarkManager: LocalBookmarkManager.shared,
                                                  burnerMode: .regular)
        suggestionContainerViewModel = SuggestionContainerViewModel(suggestionContainer: suggestionContainer)
    }

    override func tearDown() {
        suggestionLoadingMock = nil
        historyCoordinatingMock = nil
        suggestionContainer = nil
        suggestionContainerViewModel = nil
        cancellables.removeAll()
    }

    private func waitForMainQueueToFlush(for timeout: TimeInterval) {
        let e = expectation(description: "Main Queue flushed")
        DispatchQueue.main.async {
            e.fulfill()
        }
        wait(for: [e], timeout: timeout)
    }

    // MARK: - Tests

    @MainActor
    func testWhenSelectionIndexIsNilThenSelectedSuggestionViewModelIsNil() {
        let suggestionContainer = SuggestionContainer(burnerMode: .regular)
        let suggestionContainerViewModel = SuggestionContainerViewModel(suggestionContainer: suggestionContainer)

        XCTAssertNil(suggestionContainerViewModel.selectionIndex)
        XCTAssertNil(suggestionContainerViewModel.selectedSuggestionViewModel)
    }

    func testWhenSuggestionIsSelectedThenSelectedSuggestionViewModelMatchesSuggestion() {
        suggestionContainer.getSuggestions(for: "Test")
        suggestionLoadingMock.completion?(SuggestionResult.aSuggestionResult, nil )

        let index = 0

        let selectedSuggestionViewModelExpectation = expectation(description: "Selected suggestion view model expectation")
        suggestionContainerViewModel.$selectedSuggestionViewModel
            .dropFirst()
            .sink { [unowned self] selectedSuggestionViewModel in
                XCTAssertNotNil(selectedSuggestionViewModel)
                XCTAssertEqual(suggestionContainerViewModel.suggestionContainer.result?.all[index], selectedSuggestionViewModel?.suggestion)
                selectedSuggestionViewModelExpectation.fulfill()
            }
            .store(in: &cancellables)

        suggestionContainerViewModel.select(at: index)
        waitForExpectations(timeout: 0, handler: nil)
    }

    @MainActor
    func testWhenSelectCalledWithIndexOutOfBoundsThenSelectedSuggestionViewModelIsNil() {
        let suggestionContainer = SuggestionContainer(burnerMode: .regular)
        let suggestionListViewModel = SuggestionContainerViewModel(suggestionContainer: suggestionContainer)

        suggestionListViewModel.select(at: 0)

        let selectedSuggestionViewModelExpectation = expectation(description: "Selected suggestion view model expectation")

        suggestionListViewModel.$selectedSuggestionViewModel
            .debounce(for: 0.1, scheduler: RunLoop.main)
            .sink { selectedSuggestionViewModel in
                XCTAssertNil(suggestionListViewModel.selectionIndex)
                XCTAssertNil(selectedSuggestionViewModel)
                selectedSuggestionViewModelExpectation.fulfill()
            }
            .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenClearSelectionIsCalledThenNoSuggestonIsSeleted() {
        suggestionContainer.getSuggestions(for: "Test")
        suggestionLoadingMock.completion?(SuggestionResult.aSuggestionResult, nil )

        suggestionContainerViewModel.select(at: 0)

        suggestionContainerViewModel.clearSelection()

        let selectedSuggestionViewModelExpectation2 = expectation(description: "Selected suggestion view model expectation")

        suggestionContainerViewModel.$selectedSuggestionViewModel
            .debounce(for: 0.1, scheduler: RunLoop.main)
            .sink { [unowned self] _ in
                XCTAssertNil(suggestionContainerViewModel.selectionIndex)
                XCTAssertNil(suggestionContainerViewModel.selectedSuggestionViewModel)
                selectedSuggestionViewModelExpectation2.fulfill()
            }
            .store(in: &cancellables)
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testSelectNextIfPossible() {
        suggestionContainer.getSuggestions(for: "Test")
        suggestionLoadingMock.completion?(SuggestionResult.aSuggestionResult, nil )

        suggestionContainerViewModel.selectNextIfPossible()
        XCTAssertEqual(suggestionContainerViewModel.selectionIndex, 0)

        suggestionContainerViewModel.selectNextIfPossible()
        XCTAssertEqual(suggestionContainerViewModel.selectionIndex, 1)

        let lastIndex = suggestionContainerViewModel.numberOfSuggestions - 1
        suggestionContainerViewModel.select(at: lastIndex)
        XCTAssertEqual(suggestionContainerViewModel.selectionIndex, lastIndex)

        suggestionContainerViewModel.selectNextIfPossible()
        XCTAssertNil(suggestionContainerViewModel.selectionIndex)
    }

    func testSelectPreviousIfPossible() {
        suggestionContainer.getSuggestions(for: "Test")
        suggestionLoadingMock.completion?(SuggestionResult.aSuggestionResult, nil )

        suggestionContainerViewModel.selectPreviousIfPossible()
        XCTAssertEqual(suggestionContainerViewModel.selectionIndex, suggestionContainerViewModel.numberOfSuggestions - 1)

        suggestionContainerViewModel.selectPreviousIfPossible()
        XCTAssertEqual(suggestionContainerViewModel.selectionIndex, suggestionContainerViewModel.numberOfSuggestions - 2)

        let firstIndex = 0
        suggestionContainerViewModel.select(at: firstIndex)
        XCTAssertEqual(suggestionContainerViewModel.selectionIndex, firstIndex)

        suggestionContainerViewModel.selectPreviousIfPossible()
        XCTAssertNil(suggestionContainerViewModel.selectionIndex)
    }

    func testWhenUserAppendsText_suggestionsLoadingInitiatedAndTopHitIsSelected() {
        XCTAssertFalse(suggestionLoadingMock.getSuggestionsCalled)
        suggestionContainerViewModel.setUserStringValue("duck", userAppendedStringToTheEnd: true)
        XCTAssertTrue(suggestionLoadingMock.getSuggestionsCalled)

        let selectedSuggestionViewModelExpectation = expectation(description: "Selected suggestion view model")
        suggestionContainerViewModel.$selectedSuggestionViewModel
            .dropFirst()
            .sink { selectedSuggestionViewModel in
                XCTAssertNotNil(selectedSuggestionViewModel)
                XCTAssertEqual(selectedSuggestionViewModel?.suggestion, SuggestionResult.aSuggestionResult.topHits.first)
                selectedSuggestionViewModelExpectation.fulfill()
            }
            .store(in: &cancellables)

        XCTAssertNotNil(suggestionLoadingMock.completion)
        suggestionLoadingMock.completion?(SuggestionResult.aSuggestionResult, nil)

        wait(for: [selectedSuggestionViewModelExpectation], timeout: 0)
    }

    func testWhenUserAppendsSpace_suggestionsLoadingInitiatedWithoutTopSuggestionSelection() {
        suggestionContainerViewModel.setUserStringValue("duck ", userAppendedStringToTheEnd: true)
        XCTAssertTrue(suggestionLoadingMock.getSuggestionsCalled)

        suggestionContainerViewModel.$selectedSuggestionViewModel
            .dropFirst()
            .sink { _ in
                XCTFail("Unexpected suggestion view model selection")
            }
            .store(in: &cancellables)

        suggestionLoadingMock.completion?(SuggestionResult.aSuggestionResult, nil)

        waitForMainQueueToFlush(for: 1)
    }

    func testWhenUserInsertsTextInTheMiddle_suggestionsLoadingInitiatedWithoutTopSuggestionSelection() {
        suggestionContainerViewModel.setUserStringValue("duck", userAppendedStringToTheEnd: false)
        XCTAssertTrue(suggestionLoadingMock.getSuggestionsCalled)

        suggestionContainerViewModel.$selectedSuggestionViewModel
            .dropFirst()
            .sink { _ in
                XCTFail("Unexpected suggestion view model selection")
            }
            .store(in: &cancellables)

        suggestionLoadingMock.completion?(SuggestionResult.aSuggestionResult, nil)

        waitForMainQueueToFlush(for: 1)
    }

    func testWhenNoTopHitsLoaded_topSuggestionIsNotSelected() {
        suggestionContainerViewModel.setUserStringValue("duck", userAppendedStringToTheEnd: true)
        XCTAssertTrue(suggestionLoadingMock.getSuggestionsCalled)

        suggestionContainerViewModel.$selectedSuggestionViewModel
            .dropFirst()
            .sink { _ in
                XCTFail("Unexpected suggestion view model selection")
            }
            .store(in: &cancellables)

        suggestionLoadingMock.completion?(SuggestionResult.noTopHitsResult, nil)

        waitForMainQueueToFlush(for: 1)
    }

    func testWhenSuggestionsLoadedAfterUserModifiesText_oldSuggestionsAreNotSelected() {
        suggestionContainerViewModel.setUserStringValue("duc", userAppendedStringToTheEnd: true)
        XCTAssertTrue(suggestionLoadingMock.getSuggestionsCalled)
        suggestionLoadingMock.getSuggestionsCalled = false

        suggestionContainerViewModel.setUserStringValue("duce", userAppendedStringToTheEnd: true)
        XCTAssertTrue(suggestionLoadingMock.getSuggestionsCalled)

        suggestionContainerViewModel.$selectedSuggestionViewModel
            .dropFirst()
            .sink { _ in
                XCTFail("Unexpected suggestion view model selection")
            }
            .store(in: &cancellables)

        suggestionLoadingMock.completion?(SuggestionResult.noTopHitsResult, nil)

        waitForMainQueueToFlush(for: 1)
    }

    func testWhenOldSuggestionsLoadedAfterUserContinuesTypingText_topHitSuggestionsIsSelectedWithCorrectUserEnteredText() {
        suggestionContainerViewModel.setUserStringValue("duc", userAppendedStringToTheEnd: true)
        XCTAssertTrue(suggestionLoadingMock.getSuggestionsCalled)
        suggestionLoadingMock.getSuggestionsCalled = false

        suggestionContainerViewModel.setUserStringValue("duck", userAppendedStringToTheEnd: true)
        XCTAssertTrue(suggestionLoadingMock.getSuggestionsCalled)

        let selectedSuggestionViewModelExpectation = expectation(description: "Selected suggestion view model")
        suggestionContainerViewModel.$selectedSuggestionViewModel
            .dropFirst()
            .sink { selectedSuggestionViewModel in
                XCTAssertNotNil(selectedSuggestionViewModel)
                XCTAssertEqual(selectedSuggestionViewModel?.suggestion, SuggestionResult.aSuggestionResult.topHits.first)
                XCTAssertEqual(selectedSuggestionViewModel?.userStringValue, "duck")
                selectedSuggestionViewModelExpectation.fulfill()
            }
            .store(in: &cancellables)

        XCTAssertNotNil(suggestionLoadingMock.completion)
        suggestionLoadingMock.completion?(SuggestionResult.aSuggestionResult, nil)

        wait(for: [selectedSuggestionViewModelExpectation], timeout: 0)
    }

    func testWhenUserClearsText_suggestionsLoadingIsCancelled() {
        suggestionContainerViewModel.setUserStringValue("duck", userAppendedStringToTheEnd: true)
        XCTAssertTrue(suggestionLoadingMock.getSuggestionsCalled)
        suggestionLoadingMock.getSuggestionsCalled = false

        suggestionContainerViewModel.setUserStringValue("", userAppendedStringToTheEnd: true)
        XCTAssertFalse(suggestionLoadingMock.getSuggestionsCalled)

        suggestionContainerViewModel.$selectedSuggestionViewModel
            .dropFirst()
            .sink { _ in
                XCTFail("Unexpected suggestion view model selection")
            }
            .store(in: &cancellables)

        suggestionLoadingMock.completion?(SuggestionResult.noTopHitsResult, nil)

        waitForMainQueueToFlush(for: 1)
    }

    @MainActor
    func testWhenSuggestionLoadingDataSourceOpenTabsRequested_ThenOpenTabsProviderIsCalled() {
        // Setup open tabs with matching URLs and titles
        let openTabs = [
            OpenTab(title: "DuckDuckGo", url: URL(string: "http://duckduckgo.com")!),
            OpenTab(title: "Duck Tales", url: URL(string: "http://ducktales.com")!),
        ]

        // Mock the open tabs provider to return the defined open tabs
        suggestionContainer = SuggestionContainer(openTabsProvider: { openTabs },
                                                  suggestionLoading: suggestionLoadingMock,
                                                  historyCoordinating: historyCoordinatingMock,
                                                  bookmarkManager: LocalBookmarkManager.shared,
                                                  burnerMode: .regular)
        suggestionContainerViewModel = SuggestionContainerViewModel(suggestionContainer: suggestionContainer)

        suggestionContainer.getSuggestions(for: "Duck")

        let openTabsResult = suggestionLoadingMock.dataSource!.openTabs(for: suggestionLoadingMock) as! [OpenTab]
        XCTAssertEqual(openTabsResult, openTabs)
    }

}

extension SuggestionContainerViewModel {

    convenience init(suggestionContainer: SuggestionContainer) {
        self.init(isHomePage: false, isBurner: false, suggestionContainer: suggestionContainer)
    }

}

extension SuggestionResult {

    static var aSuggestionResult: SuggestionResult {
        let topHits = [
            Suggestion.bookmark(title: "DuckDuckGo", url: URL.duckDuckGo, isFavorite: true, allowedInTopHits: true),
            Suggestion.website(url: URL.duckDuckGoAutocomplete)
        ]
        return SuggestionResult(topHits: topHits,
                                duckduckgoSuggestions: [],
                                localSuggestions: [])
    }

    static var noTopHitsResult: SuggestionResult {
        let suggestions = [
            Suggestion.website(url: URL.duckDuckGo),
            Suggestion.website(url: URL.duckDuckGoAutocomplete)
        ]
        return SuggestionResult(topHits: [],
                                duckduckgoSuggestions: suggestions,
                                localSuggestions: [])
    }

}
