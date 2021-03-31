//
//  SuggestionCoordinator.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

public protocol SuggestionCoordinatorProtocol {

    func getSuggestions(query: Query, maximum: Int, completion: @escaping ([Suggestion]?, Error?) -> Void)

}

public class SuggestionCoordinator: SuggestionCoordinatorProtocol {

    public static let defaultMaxOfSuggestions = 9

    public enum SuggestionCoordinatorError: Error {
        case noDataSource
        case failedToObtainData
        case failedToMakeUrlRequest
    }

    public weak var dataSource: SuggestionCoordinatorDataSource?

    public func getSuggestions(query: Query,
                               maximum: Int,
                               completion: @escaping ([Suggestion]?, Error?) -> Void) {
        guard let dataSource = dataSource else {
            completion(nil, SuggestionCoordinatorError.noDataSource)
            return
        }

        if query == "" {
            completion([], nil)
            return
        }

        let bookmarks = dataSource.bookmarks(for: self)
        let bookmarkSuggestions = self.bookmarkSuggestions(from: bookmarks, for: query)

        guard let remoteSuggestionsRequest = remoteSuggestionsRequest(for: query) else {
            completion(nil, SuggestionCoordinatorError.failedToMakeUrlRequest)
            return
        }
        dataSource.suggestionCoordinator(self, suggestionDataFromUrlRequest: remoteSuggestionsRequest) { [weak self] data, error in
            guard let self = self else { return }
            guard let data = data, error == nil else {
                completion(nil, SuggestionCoordinatorError.failedToObtainData)
                return
            }

            let remoteSuggestions = self.remoteSuggestions(from: data)
            completion(self.result(maximum: maximum, bookmarkSuggestions: bookmarkSuggestions, remoteSuggestions: remoteSuggestions), nil)
        }
    }

    // MARK: - Bookmark Suggestions

    static var minimumQueryLengthForBookmarkSuggestions = 2

    private func bookmarkSuggestions(from bookmarks: [BookmarkProtocol], for query: Query) -> [Suggestion] {
        guard query.count >= Self.minimumQueryLengthForBookmarkSuggestions else { return [] }

        let queryTokens = query
            .split(separator: " ")
            .filter { !$0.isEmpty }
            .map { String($0).lowercased() }
        
        return bookmarks
            // Score bookmarks
            .map { bookmark -> (bookmark: BookmarkProtocol, score: Score) in
                let score = Score(bookmark: bookmark, query: query, queryTokens: queryTokens)
                return (bookmark, score)
            }
            // Filter not relevant
            .filter { $0.score > 0 }
            // Sort according to the score
            .sorted { $0.score < $1.score }
            // Pick first two
            .prefix(2)
            // Create suggestion array
            .map { Suggestion(bookmark: $0.bookmark) }
    }

    // MARK: - Remote Suggestions

    private func remoteSuggestionsRequest(for query: Query) -> URLRequest? {
        let url = URL.duckDuckGoAutocomplete
        guard let searchUrl = try? url.addParameter(name: URL.DuckDuckGoParameters.search.rawValue, value: query) else {
            return nil
        }
        return URLRequest.defaultRequest(with: searchUrl)
    }

    private func remoteSuggestions(from data: Data) -> [Suggestion] {
        let decoder = JSONDecoder()
        guard let suggestionsResult = try? decoder.decode(RemoteSuggestionsAPIResult.self, from: data) else {
            return []
        }

        return suggestionsResult.items
            .joined()
            .map { Suggestion(key: $0.key, value: $0.value) }
    }

    // MARK: - Merging

    private func result(maximum: Int,
                        bookmarkSuggestions: [Suggestion],
                        remoteSuggestions: [Suggestion]) -> [Suggestion] {
        return Array((bookmarkSuggestions + remoteSuggestions).prefix(maximum))
    }

}

public protocol SuggestionCoordinatorDataSource: AnyObject {

    func bookmarks(for suggestionCoordinator: SuggestionCoordinator) -> [BookmarkProtocol]

    func suggestionCoordinator(_ suggestionCoordinator: SuggestionCoordinator,
                               suggestionDataFromUrlRequest urlRequest: URLRequest,
                               completion: @escaping (Data?, Error?) -> Void)

}
