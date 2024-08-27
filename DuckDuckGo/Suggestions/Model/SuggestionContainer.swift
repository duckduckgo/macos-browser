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
import Suggestions
import Common
import History
import PixelKit
import os.log

final class SuggestionContainer {

    static let maximumNumberOfSuggestions = 9

    @Published private(set) var result: SuggestionResult?

    private let historyCoordinating: HistoryCoordinating
    private let bookmarkManager: BookmarkManager
    private let startupPreferences: StartupPreferences
    private let loading: SuggestionLoading

    private var latestQuery: Query?

    fileprivate let suggestionsURLSession = URLSession(configuration: .ephemeral)

    init(suggestionLoading: SuggestionLoading, historyCoordinating: HistoryCoordinating, bookmarkManager: BookmarkManager, startupPreferences: StartupPreferences = .shared) {
        self.bookmarkManager = bookmarkManager
        self.historyCoordinating = historyCoordinating
        self.startupPreferences = startupPreferences
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
                Logger.general.error("Suggestions: Failed to get suggestions - \(String(describing: error), privacy: .public)")
                PixelKit.fire(DebugEvent(GeneralPixel.suggestionsFetchFailed, error: error))
                return
            }

            if let error = error {
                // Fetching remote suggestions failed but local can be presented
                Logger.general.error("Suggestions: Error when getting suggestions - \(String(describing: error), privacy: .public)")
            }

            self?.result = result
        }
    }

    func stopGettingSuggestions() {
        latestQuery = nil
    }

}

extension SuggestionContainer: SuggestionLoadingDataSource {

    func history(for suggestionLoading: SuggestionLoading) -> [HistorySuggestion] {
        return historyCoordinating.history ?? []
    }

    @MainActor func internalPages(for suggestionLoading: Suggestions.SuggestionLoading) -> [Suggestions.InternalPage] {
        [
            // suggestions for Bookmarks&Settings
            .init(title: UserText.bookmarks, url: .bookmarks),
            .init(title: UserText.settings, url: .settings),
        ] + PreferencePaneIdentifier.allCases.map {
            // preference panes URLs
            .init(title: UserText.settings + " → " + $0.displayName, url: .settingsPane($0))
        } + {
            guard startupPreferences.launchToCustomHomePage,
                  let homePage = URL(string: startupPreferences.formattedCustomHomePageURL) else { return [] }
            // home page suggestion
            return [.init(title: UserText.homePage, url: homePage)]
        }()
    }

    @MainActor func bookmarks(for suggestionLoading: SuggestionLoading) -> [Suggestions.Bookmark] {
        bookmarkManager.list?.bookmarks() ?? []
    }

    func suggestionLoading(_ suggestionLoading: SuggestionLoading,
                           suggestionDataFromUrl url: URL,
                           withParameters parameters: [String: String],
                           completion: @escaping (Data?, Error?) -> Void) {
        let url = url.appendingParameters(parameters)
        var request = URLRequest.defaultRequest(with: url)
        request.timeoutInterval = 1

        suggestionsURLSession.dataTask(with: request) { (data, _, error) in
            completion(data, error)
        }.resume()
    }

}

extension HistoryEntry: HistorySuggestion {

    public var numberOfVisits: Int {
        return numberOfTotalVisits
    }

}
