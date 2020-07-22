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

class SuggestionsViewModel {

    let suggestions: Suggestions

    init(suggestions: Suggestions) {
        self.suggestions = suggestions
    }

    var numberOfSuggestions: Int {
        (suggestions.items.remote?.count ?? 0) + (suggestions.items.local?.count ?? 0)
    }

    @Published private(set) var selectionIndex: Int? {
        didSet { setSelectedSuggestionViewModel() }
    }

    @Published private(set) var selectedSuggestionViewModel: SuggestionViewModel?

    private func setSelectedSuggestionViewModel() {
        if let selectionIndex = selectionIndex {
            selectedSuggestionViewModel = suggestionViewModel(at: selectionIndex)
        } else {
            selectedSuggestionViewModel = nil
        }
    }
    
    func suggestionViewModel(at index: Int) -> SuggestionViewModel? {
        let remote = suggestions.items.remote ?? []
        let local = suggestions.items.local ?? []

        guard index < remote.count + local.count else {
            os_log("SuggestionsViewModel: Absolute index is out of bounds", log: OSLog.Category.general, type: .error)
            return nil
        }

        if remote.count == 0 {
            return SuggestionViewModel(suggestion: local[index])
        }

        switch index {
        case 0 ..< remote.count:
            return SuggestionViewModel(suggestion: remote[index])
        case remote.count ..< (remote.count + local.count):
            let index = index - remote.count
            return SuggestionViewModel(suggestion: local[index])
        default:
            os_log("SuggestionsViewModel: absolute index is out of bounds", log: OSLog.Category.general, type: .error)
            return nil
        }
    }

    func select(at index: Int) {
        guard index >= 0, index < numberOfSuggestions else {
            os_log("SuggestionsViewModel: Index out of bounds", log: OSLog.Category.general, type: .error)
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
