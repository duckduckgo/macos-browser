//
//  PixelEvent.swift
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

extension Pixel {

    enum Event {
        case appLaunch(isDefault: IsDefaultBrowser = .init(), launch: AppLaunch)
        case launchTiming

        case appActiveUsage(isDefault: IsDefaultBrowser = .init(), avgTabs: AverageTabsCount)

        case burn(repetition: Repetition = .init(key: "fire"), burnedTabs: BurnedTabs, burnedWindows: BurnedWindows)

        case fireproof(kind: FireproofKind, repetition: Repetition = .init(key: "fireproof"), suggested: FireproofingSuggested)

        case bookmark(fireproofed: IsBookmarkFireproofed, repetition: Repetition = .init(key: "bookmark"), source: AccessPoint)
        case favorite(fireproofed: IsBookmarkFireproofed, repetition: Repetition = .init(key: "favorite"), source: AccessPoint)

        static func bookmark(isFavorite: Bool, isFireproofed: Bool, source: AccessPoint) -> Event {
            if isFavorite {
                return .favorite(fireproofed: IsBookmarkFireproofed(booleanLiteral: isFireproofed), source: source)
            }
            return .bookmark(fireproofed: IsBookmarkFireproofed(booleanLiteral: isFireproofed), source: source)
        }

        case navigation(kind: NavigationKind, source: NavigationAccessPoint)

        case suggestionsDisplayed(hasBookmark: HasBookmark, hasFavorite: HasFavorite)

        case sharingMenu(repetition: Repetition = .init(key: "sharing"), result: SharingResult)

        case moreMenu(repetition: Repetition = .init(key: "more"), result: MoreResult)

        case refresh(source: RefreshAccessPoint)

        case debug(event: Debug, error: Error, countedBy: Pixel.Counter? = nil)

        enum Debug: String {
            case dbMigrationError = "dbme"
            case dbInitializationError = "dbie"
            case dbSaveExcludedHTTPSDomainsError = "dbsw"
            case dbSaveBloomFilterError = "dbsb"

            case configurationFetchError = "cfgfetch"

            case trackerDataParseFailed = "tds_p"
            case trackerDataReloadFailed = "tds_r"
            case trackerDataCouldNotBeLoaded = "tds_l"

            case fileStoreWriteFailed = "fswf"
            case fileMoveToDownloadsFailed = "df"

            case suggestionsFetchFailed = "sgf"
            case appOpenURLFailed = "url"
            case appStateRestorationFailed = "srf"
        }

    }

}

extension Pixel.Event {

    var name: String {
        switch self {
        case .appLaunch(isDefault: let isDefault, launch: let launch):
            return "ml_mac_app-launch_\(isDefault)_\(launch)"
        case .launchTiming:
            return "ml_mac_launch-timing"

        case .appActiveUsage(isDefault: let isDefault, avgTabs: let avgTabs):
            return "m_mac_active-usage_\(isDefault)_\(avgTabs)"

        case .burn(repetition: let repetition, burnedTabs: let tabs, burnedWindows: let windows):
            return "m_mac_fire-button.\(repetition)_\(tabs)_\(windows)"

        case .fireproof(kind: let kind, repetition: let repetition, suggested: let suggested):
            return "m_mac_fireproof_\(kind)_\(repetition)_\(suggested)"

        case .bookmark(fireproofed: let fireproofed, repetition: let repetition, source: let source):
            return "m_mac_bookmark_\(fireproofed)_\(repetition)_\(source)"
        case .favorite(fireproofed: let fireproofed, repetition: let repetition, source: let source):
            return "m_mac_favorite_\(fireproofed)_\(repetition)_\(source)"

        case .navigation(kind: let kind, source: let source):
            return "m_mac_navigation_\(kind)_\(source)"

        case .suggestionsDisplayed(hasBookmark: let hasBookmark, hasFavorite: let hasFavorite):
            return "m_mac_suggestions-displayed_\(hasBookmark)_\(hasFavorite)"

        case .sharingMenu(repetition: let repetition, result: let result):
            return "m_mac_share_\(repetition)_\(result)"

        case .moreMenu(repetition: let repetition, result: let result):
            return "m_mac_more-menu_\(repetition)_\(result)"

        case .refresh(source: let source):
            return "m_mac_refresh_\(source)"

        case .debug(event: let event, error: _, countedBy: _):
            return "m_debug_\(event)"
        }
    }

}
