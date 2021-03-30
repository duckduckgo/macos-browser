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

    func getSuggestions(query: Query, completion: @escaping (Query, [Suggestion]?, Error?) -> Void)

}

public class SuggestionCoordinator: SuggestionCoordinatorProtocol {

    public enum SuggestionCoordinatorError: Error {
        case noDataSource
    }

    public weak var dataSource: SuggestionCoordinatorDataSource?

    public func getSuggestions(query: Query, completion: @escaping (Query, [Suggestion]?, Error?) -> Void) {

        guard let dataSource = dataSource else {
            completion(query, nil, SuggestionCoordinatorError.noDataSource)
            return
        }

        let bookmarks = dataSource.bookmarks(for: self)

        dataSource.suggestionCoordinator(self, suggestionDataFromUrl: URL.duckDuckGo) { data, error in

        }

    }

    private func bookmarkSuggestions(for query: Query) {
        //todo
    }

    private func remoteSuggestions(from data: Data) {
        //todo
    }

    private func result(bookmarkSuggestions: [Suggestion], remoteSuggestions: [Suggestion]) -> [Suggestion] {
        //todo
        return []
    }

}

public protocol SuggestionCoordinatorDataSource: AnyObject {

    func bookmarks(for suggestionCoordinator: SuggestionCoordinator) -> [BookmarkProtocol]

    func suggestionCoordinator(_ suggestionCoordinator: SuggestionCoordinator,
                               suggestionDataFromUrl url: URL,
                               completion: @escaping (Data?, Error?) -> Void)

}
