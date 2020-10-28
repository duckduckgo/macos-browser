//
//  Suggestions.swift
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

class Suggestions {
    let suggestionsAPI: SuggestionsAPI

    @Published private(set) var items: [Suggestion]?

    init(suggestionsAPI: SuggestionsAPI) {
        self.suggestionsAPI = suggestionsAPI
    }

    convenience init () {
        self.init(suggestionsAPI: DuckDuckGoSuggestionsAPI())
    }

    func getSuggestions(for query: String) {
        if query == "" {
            items = nil
            return
        }

        suggestionsAPI.fetchSuggestions(for: query) { (result, error) in
            guard let result = result, error == nil else {
                self.items = nil
                os_log("Suggestions: Failed to fetch remote suggestions - %s",
                       log: OSLog.Category.general,
                       type: .error,
                       error?.localizedDescription ?? "")
                return
            }

            var suggestions = [Suggestion]()
            for resultItem in result.items {
                for (key, value) in resultItem {
                    suggestions.append(Suggestion.makeSuggestion(key: key, value: value))
                }
            }

            self.items = suggestions
        }
    }

    func stopFetchingSuggestions() {
        suggestionsAPI.stopFetchingSuggestions()
    }

}

fileprivate extension Suggestion {

    static func makeSuggestion(key: String, value: String) -> Suggestion {
        let suggestion = key == "phrase" ? Suggestion.phrase(phrase: value) : Suggestion.unknown(value: value)
        if key != "phrase" {
            os_log("SuggestionsAPIResult: Unknown suggestion type", log: OSLog.Category.general, type: .debug)
        }
        return suggestion
    }

}
