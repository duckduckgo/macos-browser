//
//  BookmarksBarVisibilityManager.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Combine

/// Decides if the BookmarksBar should be visible based on the Tab.Content and Appearance preferences.
final class BookmarksBarVisibilityManager {
    private var bookmarkBarVisibilityCancellable: AnyCancellable?
    private var bookmarkContentCancellable: AnyCancellable?

    /// A published value indicating the visibility of the bookmarks bar.
    /// Returns`true` if the bookmarks bar is visible; otherwise, `false`.
    @Published var isBookmarksBarVisible: Bool = false

    private let selectedTabPublisher: AnyPublisher<TabViewModel?, Never>
    private let preferences: AppearancePreferences

    /// Create an instance given the specified `TabViewModel` publisher and `AppearancePreferences`.
    /// - Parameters:
    ///   - selectedTabPublisher: A publisher that returns the selected Tab view model.
    ///   - preferences: The `AppearancePreferences` to read the bookmarks appearance preferences from.
    init(selectedTabPublisher: AnyPublisher<TabViewModel?, Never>, preferences: AppearancePreferences = .shared) {
        self.selectedTabPublisher = selectedTabPublisher
        self.preferences = preferences
        bind()
    }

}

// MARK: - Private

private extension BookmarksBarVisibilityManager {

    func bind() {
        let bookmarksBarVisibilityPublisher = NotificationCenter.default
            .publisher(for: AppearancePreferences.Notifications.showBookmarksBarSettingChanged)

        let bookmarksBarAppearancePublisher = NotificationCenter.default
            .publisher(for: AppearancePreferences.Notifications.bookmarksBarSettingAppearanceChanged)

        let bookmarksBarNotificationsPublisher = Publishers.Merge(bookmarksBarVisibilityPublisher, bookmarksBarAppearancePublisher)
            .map { _ in () } // Map To Void, we're not interested in the notification itself
            .prepend(()) // Start with a value so combineLatest can fire

        // Every time the user select a tab or the Appeareance preference changes check if bookmarks bar should be visible or not.
        // For the selected Tab we should also check if the Tab content changes as it can switch from empty to url if the user loads a web page.
        bookmarkBarVisibilityCancellable = bookmarksBarNotificationsPublisher
            .combineLatest(selectedTabPublisher)
            .compactMap { _, selectedTab -> TabViewModel? in
                guard let selectedTab else { return nil }
                return selectedTab
            }
            .flatMap { tabViewModel in
                // Subscribe to the selected tab content.
                // When a tab is empty and the bookmarksBar should show only on empty Tabs it should disappear when we load a website.
                tabViewModel.tab.$content.eraseToAnyPublisher()
            }
            .sink(receiveValue: { [weak self] tabContent in
                guard let self = self else { return }
                self.updateBookmarksBar(content: tabContent, preferences: self.preferences)
            })
    }

    func updateBookmarksBar(content: Tab.TabContent, preferences: AppearancePreferences) {
        // If visibility should be off, set visibility off and exit
        guard preferences.showBookmarksBar else {
            isBookmarksBarVisible = false
            return
        }

        // If visibility is on check Appearance
        switch preferences.bookmarksBarAppearance {
        case .newTabOnly:
            isBookmarksBarVisible = content.isEmpty
        case .alwaysOn:
            isBookmarksBarVisible = true
        }
    }

}
