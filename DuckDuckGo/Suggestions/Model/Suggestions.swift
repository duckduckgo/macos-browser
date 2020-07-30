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

    enum Constants {
        static let maxNumberInCategory = 5
    }

    let suggestionsAPI: SuggestionsAPI
    let historyStore: HistoryStore

    @Published private(set) var items: (remote: [Suggestion]?, local: [Suggestion]?) = (nil, nil)

    init(suggestionsAPI: SuggestionsAPI, historyStore: HistoryStore) {
        self.suggestionsAPI = suggestionsAPI
        self.historyStore = historyStore
    }

    convenience init () {
        self.init(suggestionsAPI: DuckDuckGoSuggestionsAPI(), historyStore: LocalHistoryStore())
    }

    func getSuggestions(for query: String) {
        if query == "" {
            items = (nil, nil)
            return
        }

        getRemoteSuggestions(for: query)
        getLocalSuggestions(for: query)
    }

    private func getRemoteSuggestions(for query: String) {
        suggestionsAPI.fetchSuggestions(for: query) { (result, error) in
            guard let result = result, error == nil else {
                self.items.remote = nil
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

            let filtered = Array(suggestions.prefix(Constants.maxNumberInCategory))
            self.items.remote = filtered
        }
    }

    private func getLocalSuggestions(for query: String) {
        historyStore.loadWebsiteVisits(textQuery: query, limit: Constants.maxNumberInCategory) { (websiteVisits, error) in
            guard let websiteVisits = websiteVisits, error == nil else {
                self.items.local = nil
                os_log("Suggestions: Failed to fetch local suggestions - %s",
                       log: OSLog.Category.general,
                       type: .error,
                       error?.localizedDescription ?? "")
                return
            }
            let suggestions = websiteVisits.map { Suggestion.website(url: $0.url, title: $0.title) }
            let filtered = Array(suggestions.prefix(Constants.maxNumberInCategory))
            self.items.local = filtered
        }
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
