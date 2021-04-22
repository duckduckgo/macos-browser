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
            let suggestions = suggestions?.map { suggestion -> Suggestion in
                if case .phrase(phrase: let phrase) = suggestion,
                   let url = phrase.punycodedUrl, url.isValid {
                    return .website(url: url)
                }
                return suggestion
            }
            .enumerated()
            .sorted { lhs, rhs -> Bool in
                switch (lhs.element, rhs.element) {
                case (.bookmark, .bookmark),
                     (.phrase, .phrase),
                     (.website, .website):
                    // keep original order for same-kind entities
                    return lhs.offset < rhs.offset

                // bookmarks go first
                case (.bookmark, _):
                    return true
                case (_, .bookmark):
                    return false

                // unknown go last
                case (_, .unknown):
                    return true
                case (.unknown, _):
                    return false

                // websites before phrases
                case (.website, .phrase):
                    return true
                case (.phrase, .website):
                    return false
                }
            }
            .map(\.element)

            DispatchQueue.main.async {
                guard self?.latestQuery == query else { return }
                guard let suggestions = suggestions, error == nil else {
                    self?.suggestions = nil
                    os_log("Suggestions: Failed to get suggestions - %s",
                           type: .error,
                           "\(String(describing: error))")
                    Pixel.fire(.debug(event: .suggestionsFetchFailed, error: error))
                    return
                }

                self?.suggestions = suggestions
            }
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
