//
//  SuggestionContainerViewModel.swift
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
import Combine
import Common
import BrowserServicesKit

final class SuggestionContainerViewModel {

    var isHomePage: Bool
    let suggestionContainer: SuggestionContainer
    private var suggestionResultCancellable: AnyCancellable?

    init(isHomePage: Bool, suggestionContainer: SuggestionContainer) {
        self.isHomePage = isHomePage
        self.suggestionContainer = suggestionContainer
        subscribeToSuggestionResult()
    }

    var numberOfSuggestions: Int {
        suggestionContainer.result?.count ?? 0
    }

    @Published private(set) var selectionIndex: Int? {
        didSet { updateSelectedSuggestionViewModel() }
    }

    @Published private(set) var selectedSuggestionViewModel: SuggestionViewModel?

    private(set) var userStringValue: String?

    private var isTopSuggestionSelectionExpected = false

    private var shouldSelectTopSuggestion: Bool {
        guard let result = suggestionContainer.result, !result.isEmpty else { return false }

        if self.isTopSuggestionSelectionExpected,
           result.canBeAutocompleted,
           let userStringValue = self.userStringValue,
           let firstSuggestion = self.suggestionViewModel(at: 0),
           firstSuggestion.autocompletionString.lowercased().hasPrefix(userStringValue.lowercased()) {
            return true
        } else {
            return false
        }
    }

    private func subscribeToSuggestionResult() {
        suggestionResultCancellable = suggestionContainer.$result.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
            guard let self = self,
                  self.shouldSelectTopSuggestion
            else { return }

            self.select(at: 0)
        }
    }

    func setUserStringValue(_ userStringValue: String, userAppendedStringToTheEnd: Bool) {
        guard AppearancePreferences.shared.showAutocompleteSuggestions else {
            return
        }

        let oldValue = self.userStringValue
        self.userStringValue = userStringValue

        guard !userStringValue.isEmpty else {
            suggestionContainer.stopGettingSuggestions()
            return
        }
        guard userStringValue.lowercased() != oldValue?.lowercased() else { return }

        self.isTopSuggestionSelectionExpected = userAppendedStringToTheEnd && !userStringValue.contains(" ")
        suggestionContainer.getSuggestions(for: userStringValue)
    }

    func clearUserStringValue() {
        self.userStringValue = nil
        suggestionContainer.stopGettingSuggestions()
    }

    private func updateSelectedSuggestionViewModel() {
        if let selectionIndex = selectionIndex {
            selectedSuggestionViewModel = suggestionViewModel(at: selectionIndex)
        } else {
            selectedSuggestionViewModel = nil
        }
    }

    func suggestionViewModel(at index: Int) -> SuggestionViewModel? {
        let items = suggestionContainer.result?.all ?? []

        guard index < items.count else {
            os_log("SuggestionContainerViewModel: Absolute index is out of bounds", type: .error)
            return nil
        }

        return SuggestionViewModel(isHomePage: isHomePage, suggestion: items[index], userStringValue: userStringValue ?? "")
    }

    func select(at index: Int) {
        guard index >= 0, index < numberOfSuggestions else {
            os_log("SuggestionContainerViewModel: Index out of bounds", type: .error)
            selectionIndex = nil
            return
        }

        if suggestionViewModel(at: index) !== self.selectedSuggestionViewModel {
            selectionIndex = index
        }
    }

    func clearSelection() {
        if selectionIndex != nil {
            selectionIndex = nil
        }
    }

    func selectNextIfPossible() {
        // When no item is selected, start selection from the top of the list
        guard let selectionIndex = selectionIndex else {
            select(at: 0)
            return
        }

        // At the end of the list, cancel the selection
        if selectionIndex == numberOfSuggestions - 1 {
            clearSelection()
            return
        }

        let newIndex = min(numberOfSuggestions - 1, selectionIndex + 1)
        select(at: newIndex)
    }

    func selectPreviousIfPossible() {
        // When no item is selected, start selection from the bottom of the list
        guard let selectionIndex = selectionIndex else {
            select(at: numberOfSuggestions - 1)
            return
        }

        // If the first item is selected, cancel the selection
        if selectionIndex == 0 {
            clearSelection()
            return
        }

        let newIndex = max(0, selectionIndex - 1)
        select(at: newIndex)
    }

}
