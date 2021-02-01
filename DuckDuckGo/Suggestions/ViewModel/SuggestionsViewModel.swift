//
//  AutocompleteViewModel.swift
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
import os.log

final class SuggestionsViewModel {

    let suggestions: Suggestions

    init(suggestions: Suggestions) {
        self.suggestions = suggestions
    }

    var numberOfSuggestions: Int {
        suggestions.items?.count ?? 0
    }

    @Published private(set) var selectionIndex: Int? {
        didSet { updateSelectedSuggestionViewModel() }
    }

    @Published private(set) var selectedSuggestionViewModel: SuggestionViewModel?

    var userStringValue: String? {
        didSet {
            if let userStringValue = userStringValue {
                suggestions.getSuggestions(for: userStringValue)
            }
        }
    }

    private func updateSelectedSuggestionViewModel() {
        if let selectionIndex = selectionIndex {
            selectedSuggestionViewModel = suggestionViewModel(at: selectionIndex)
        } else {
            selectedSuggestionViewModel = nil
        }
    }
    
    func suggestionViewModel(at index: Int) -> SuggestionViewModel? {
        let items = suggestions.items ?? []

        guard index < items.count else {
            os_log("SuggestionsViewModel: Absolute index is out of bounds", type: .error)
            return nil
        }

        return SuggestionViewModel(suggestion: items[index], userStringValue: userStringValue ?? "")
    }

    func select(at index: Int) {
        guard index >= 0, index < numberOfSuggestions else {
            os_log("SuggestionsViewModel: Index out of bounds", type: .error)
            selectionIndex = nil
            return
        }

        if selectionIndex != index {
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
