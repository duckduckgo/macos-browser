//
//  SuggestionList.swift
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

final class SuggestionList {

    static let maximumNumberOfSuggestions = 9

    @Published private(set) var suggestions: [Suggestion]?

    private let bookmarkManager: BookmarkManager
    private let coordinator = SuggestionCoordinator()

    private var latestQuery: Query?

    init(bookmarkManager: BookmarkManager) {
        self.bookmarkManager = bookmarkManager

        coordinator.dataSource = self
    }

    convenience init () {
        self.init(bookmarkManager: LocalBookmarkManager.shared)
    }

    func getSuggestions(for query: String) {
        latestQuery = query
        coordinator.getSuggestions(query: query, maximum: Self.maximumNumberOfSuggestions) { [weak self] (suggestions, error) in
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

extension SuggestionList: SuggestionCoordinatorDataSource {

    func bookmarks(for suggestionCoordinator: SuggestionCoordinator) -> [BookmarkProtocol] {
        bookmarkManager.list?.bookmarks() ?? []
    }

    func suggestionCoordinator(_ suggestionCoordinator: SuggestionCoordinator,
                               suggestionDataFromUrlRequest urlRequest: URLRequest,
                               completion: @escaping (Data?, Error?) -> Void) {
        URLSession.shared.dataTask(with: urlRequest) { (data, _, error) in
            completion(data, error)
        }.resume()
    }

}

extension Bookmark: BookmarkProtocol {}
