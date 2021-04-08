//
//  SuggestionContainer.swift
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
import BrowserServicesKit

final class SuggestionContainer {

    static let maximumNumberOfSuggestions = 9

    @Published private(set) var suggestions: [Suggestion]?

    private let bookmarkManager: BookmarkManager
    private let loading: SuggestionLoading

    private var latestQuery: Query?

    init(suggestionLoading: SuggestionLoading, bookmarkManager: BookmarkManager) {
        self.bookmarkManager = bookmarkManager
        self.loading = suggestionLoading
        self.loading.dataSource = self
    }

    convenience init () {
        self.init(suggestionLoading: SuggestionLoader(), bookmarkManager: LocalBookmarkManager.shared)
    }

    func getSuggestions(for query: String) {
        latestQuery = query
        loading.getSuggestions(query: query, maximum: Self.maximumNumberOfSuggestions) { [weak self] (suggestions, error) in
            guard self?.latestQuery == query else { return }
            guard let suggestions = suggestions, error == nil else {
                self?.suggestions = nil
                os_log("Suggestions: Failed to get suggestions - %s",
                       type: .error,
                       "\(String(describing: error))")
                return
            }
            self?.suggestions = suggestions
        }
    }

    func stopGettingSuggestions() {
        latestQuery = nil
    }

}

extension SuggestionContainer: SuggestionLoadingDataSource {

    func bookmarks(for suggestionLoading: SuggestionLoading) -> [BrowserServicesKit.Bookmark] {
        bookmarkManager.list?.bookmarks() ?? []
    }

    func suggestionLoading(_ suggestionLoading: SuggestionLoading,
                          suggestionDataFromUrl url: URL,
                          withParameters parameters: [String: String],
                          completion: @escaping (Data?, Error?) -> Void) {
        var url = url
        parameters.forEach {
            if let newUrl = try? url.addParameter(name: $0.key, value: $0.value) {
                url = newUrl
            } else {
                assertionFailure("SuggestionContainer: Failed to add parameter")
            }
        }
        let request = URLRequest.defaultRequest(with: url)

        URLSession.shared.dataTask(with: request) { (data, _, error) in
            completion(data, error)
        }.resume()
    }

}

extension Bookmark: BrowserServicesKit.Bookmark {}
