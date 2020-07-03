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

class SuggestionsViewModel {

    let suggestions: Suggestions
    @Published private(set) var selectedSuggestion: Suggestion?

    private var selectionIndexCancellable: AnyCancellable?

    init(suggestions: Suggestions) {
        self.suggestions = suggestions

        bindSelectionIndex()
    }

    private func bindSelectionIndex() {
        selectionIndexCancellable = suggestions.$selectionIndex.sinkAsync { _ in
            self.setSelectedSuggestion()
        }
    }

    private func setSelectedSuggestion() {
        if let index = suggestions.selectionIndex {
            selectedSuggestion = suggestions.suggestion(at: index)
        } else {
            selectedSuggestion = nil
        }
    }

    func selectNextIfPossible() {
        // When no item is selected, start selection from the top of the list
        guard let selectionIndex = suggestions.selectionIndex else {
            suggestions.select(at: 0)
            return
        }

        // At the end of the list, cancel the selection
        if selectionIndex == suggestions.items.count - 1 {
            suggestions.clearSelection()
            return
        }

        let newIndex = min(suggestions.items.count - 1, selectionIndex + 1)
        suggestions.select(at: newIndex)
    }

    func selectPreviousIfPossible() {
        // When no item is selected, start selection from the bottom of the list
        guard let selectionIndex = suggestions.selectionIndex else {
            suggestions.select(at: suggestions.items.count - 1)
            return
        }

        // If the first item is selected, cancel the selection
        if selectionIndex == 0 {
            suggestions.clearSelection()
            return
        }

        let newIndex = max(0, selectionIndex - 1)
        suggestions.select(at: newIndex)
    }
    
}
