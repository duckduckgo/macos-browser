//
//  Autocomplete.swift
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
import os.log

class Autocomplete {

    let autocompleteAPI: AutocompleteAPI
    let autocompleteStore: AutocompleteStore

    var suggestions: [Suggestion]?

    init(autocompleteAPI: AutocompleteAPI, autocompleteStore: AutocompleteStore) {
        self.autocompleteAPI = autocompleteAPI
        self.autocompleteStore = autocompleteStore
    }

    convenience init () {
        self.init(autocompleteAPI: DuckDuckGoAutocompleteAPI(), autocompleteStore: LocalAutocompleteStore())
    }

    func getSuggestions(for query: String) {
        //todo local

        autocompleteAPI.fetchSuggestions(for: query) { (suggestions, error) in
            guard error == nil else {
                os_log("Autocomplete: Failed to fetch suggestions - ", log: OSLog.Category.general, type: .error, error?.localizedDescription ?? "")
                return
            }

            self.suggestions = suggestions
        }
    }

    func saveSuggestion(url: URL) {
        //todo
    }

}
