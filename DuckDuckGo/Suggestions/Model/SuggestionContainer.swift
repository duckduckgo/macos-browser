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

import Combine
import Common
import Foundation
import History
import os.log
import PixelKit
import Suggestions

final class SuggestionContainer {

    static let maximumNumberOfSuggestions = 9

    @PublishedAfter var result: SuggestionResult?

    typealias OpenTabsProvider = @MainActor () -> [any Suggestions.BrowserTab]
    private let openTabsProvider: OpenTabsProvider
    private let historyCoordinating: HistoryCoordinating
    private let bookmarkManager: BookmarkManager
    private let startupPreferences: StartupPreferences
    private let loading: SuggestionLoading

    // Used for presenting the same suggestions after the removal of the local suggestion
    private(set) var suggestionDataCache: Data?

    private var latestQuery: Query?

    fileprivate let suggestionsURLSession = URLSession(configuration: .ephemeral)

    init(openTabsProvider: @escaping OpenTabsProvider, suggestionLoading: SuggestionLoading, historyCoordinating: HistoryCoordinating, bookmarkManager: BookmarkManager, startupPreferences: StartupPreferences = .shared) {
        self.openTabsProvider = openTabsProvider
        self.bookmarkManager = bookmarkManager
        self.historyCoordinating = historyCoordinating
        self.startupPreferences = startupPreferences
        self.loading = suggestionLoading
    }

    convenience init () {
        let urlFactory = { urlString in
            return URL.makeURL(fromSuggestionPhrase: urlString)
        }
        let openTabsProvider: OpenTabsProvider = { @MainActor in
            let selectedTab = WindowControllersManager.shared.selectedTab
            return WindowControllersManager.shared.allTabViewModels.compactMap { model in
                guard model.tab !== selectedTab, model.tab.content.isUrl else { return nil }
                return model.tab.content.userEditableUrl.map { url in
                    OpenTab(title: model.title, url: url)
                }
            }
        }
        self.init(openTabsProvider: openTabsProvider, suggestionLoading: SuggestionLoader(urlFactory: urlFactory),
                  historyCoordinating: HistoryCoordinator.shared,
                  bookmarkManager: LocalBookmarkManager.shared)
    }

    func getSuggestions(for query: String, useCachedData: Bool = false) {
        latestQuery = query

        // Don't use cache by default
        if !useCachedData {
            suggestionDataCache = nil
        }

        loading.getSuggestions(query: query, usingDataSource: self) { [weak self] result, error in
            dispatchPrecondition(condition: .onQueue(.main))

            guard let self, self.latestQuery == query else { return }
            guard let result else {
                self.result = nil
                Logger.general.error("Suggestions: Failed to get suggestions - \(String(describing: error))")
                PixelKit.fire(DebugEvent(GeneralPixel.suggestionsFetchFailed, error: error))
                return
            }

            if let error = error {
                // Fetching remote suggestions failed but local can be presented
                Logger.general.error("Suggestions: Error when getting suggestions - \(error.localizedDescription)")
            }

            self.result = result
        }
    }

    func stopGettingSuggestions() {
        latestQuery = nil
    }

}

struct OpenTab: BrowserTab {

    let title: String
    let url: URL

}

extension SuggestionContainer: SuggestionLoadingDataSource {

    var platform: Platform {
        return .desktop
    }

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

    @MainActor func openTabs(for suggestionLoading: any Suggestions.SuggestionLoading) -> [any Suggestions.BrowserTab] {
        openTabsProvider()
    }

    func suggestionLoading(_ suggestionLoading: SuggestionLoading,
                           suggestionDataFromUrl url: URL,
                           withParameters parameters: [String: String],
                           completion: @escaping (Data?, Error?) -> Void) {
        if let suggestionDataCache = suggestionDataCache {
            completion(suggestionDataCache, nil)
            return
        }

        let url = url.appendingParameters(parameters)
        var request = URLRequest.defaultRequest(with: url)
        request.timeoutInterval = 1

        suggestionsURLSession.dataTask(with: request) { (data, _, error) in
            self.suggestionDataCache = data
            completion(data, error)
        }.resume()
    }

}

extension HistoryEntry: HistorySuggestion {

    public var numberOfVisits: Int {
        return numberOfTotalVisits
    }

}
