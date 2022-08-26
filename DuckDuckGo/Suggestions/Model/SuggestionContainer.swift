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

    @Published private(set) var result: SuggestionResult?

    private let historyCoordinating: HistoryCoordinating
    private let bookmarkManager: BookmarkManager
    private let loading: SuggestionLoading

    private var latestQuery: Query?
    
    fileprivate let suggestionsURLSession = URLSession(configuration: .ephemeral)

    init(suggestionLoading: SuggestionLoading, historyCoordinating: HistoryCoordinating, bookmarkManager: BookmarkManager) {
        self.bookmarkManager = bookmarkManager
        self.historyCoordinating = historyCoordinating
        self.loading = suggestionLoading
        self.loading.dataSource = self
    }

    convenience init () {
        let urlFactory = { urlString in
            return URL.makeURL(fromSuggestionPhrase: urlString)
        }

        self.init(suggestionLoading: SuggestionLoader(urlFactory: urlFactory),
                  historyCoordinating: HistoryCoordinator.shared,
                  bookmarkManager: LocalBookmarkManager.shared)
    }

    func getSuggestions(for query: String) {
        latestQuery = query
        loading.getSuggestions(query: query) { [weak self] result, error in
            dispatchPrecondition(condition: .onQueue(.main))

            guard self?.latestQuery == query else { return }
            guard let result = result else {
                self?.result = nil
                os_log("Suggestions: Failed to get suggestions - %s",
                       type: .error,
                       "\(String(describing: error))")
                Pixel.fire(.debug(event: .suggestionsFetchFailed, error: error))
                return
            }

            if let error = error {
                // Fetching remote suggestions failed but local can be presented
                os_log("Suggestions: Error when getting suggestions - %s",
                       type: .error,
                       "\(String(describing: error))")
            }

            self?.result = result
        }
    }

    func stopGettingSuggestions() {
        latestQuery = nil
    }

}

extension SuggestionContainer: SuggestionLoadingDataSource {

    func history(for suggestionLoading: SuggestionLoading) -> [BrowserServicesKit.HistoryEntry] {
        return historyCoordinating.history ?? []
    }

    func bookmarks(for suggestionLoading: SuggestionLoading) -> [BrowserServicesKit.Bookmark] {
        bookmarkManager.list?.bookmarks() ?? []
    }

    func suggestionLoading(_ suggestionLoading: SuggestionLoading,
                           suggestionDataFromUrl url: URL,
                           withParameters parameters: [String: String],
                           completion: @escaping (Data?, Error?) -> Void) {
        var url = url
        parameters.forEach {
            do {
                try url = url.appendingParameter(name: $0.key, value: $0.value)
            } catch {
                assertionFailure("SuggestionContainer: Failed to add parameter")
            }
        }
        
        var request = URLRequest.defaultRequest(with: url)
        request.timeoutInterval = 1

        suggestionsURLSession.dataTask(with: request) { (data, _, error) in
            completion(data, error)
        }.resume()
    }

}

extension HistoryEntry: BrowserServicesKit.HistoryEntry {

    var numberOfVisits: Int {
        return numberOfTotalVisits
    }

}

extension Bookmark: BrowserServicesKit.Bookmark {}
