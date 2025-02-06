//
//  MockAppearancePreferencesPersistor.swift
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
@testable import DuckDuckGo_Privacy_Browser

class MockAppearancePreferencesPersistor: AppearancePreferencesPersistor {
    var homeButtonPosition: HomeButtonPosition = .hidden

    var homePageCustomBackground: String?

    var showFullURL: Bool = false

    var showAutocompleteSuggestions: Bool = false

    var currentThemeName: String = ""

    var defaultPageZoom: CGFloat = 1.0

    var favoritesDisplayMode: String?

    var isFavoriteVisible: Bool = true

    var isContinueSetUpVisible: Bool = true

    var continueSetUpCardsLastDemonstrated: Date?

    var continueSetUpCardsNumberOfDaysDemonstrated: Int = 0

    var continueSetUpCardsClosed: Bool = false

    var isRecentActivityVisible: Bool = true

    var isPrivacyStatsVisible: Bool = false

    var isSearchBarVisible: Bool = true

    var showBookmarksBar: Bool = false

    var bookmarksBarAppearance: BookmarksBarAppearance = .alwaysOn

    var centerAlignedBookmarksBar: Bool = false

    var didDismissHomePagePromotion = true

    var showTabsAndBookmarksBarOnFullScreen: Bool = false
}
