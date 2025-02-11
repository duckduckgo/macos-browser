//
//  NewTabPageActionsManagerExtension.swift
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

import AppKit
import History
import NewTabPage
import PrivacyStats

extension NewTabPageActionsManager {

    convenience init(
        appearancePreferences: AppearancePreferences,
        settingsModel: HomePage.Models.SettingsModel,
        bookmarkManager: BookmarkManager & URLFavoriteStatusProviding = LocalBookmarkManager.shared,
        duckPlayerHistoryEntryTitleProvider: DuckPlayerHistoryEntryTitleProviding = DuckPlayer.shared,
        contentBlocking: ContentBlockingProtocol = ContentBlocking.shared,
        activeRemoteMessageModel: ActiveRemoteMessageModel,
        historyCoordinator: HistoryCoordinating,
        privacyStats: PrivacyStatsCollecting,
        freemiumDBPPromotionViewCoordinator: FreemiumDBPPromotionViewCoordinator
    ) {
        let favoritesPublisher = bookmarkManager.listPublisher.map({ $0?.favoriteBookmarks ?? [] }).eraseToAnyPublisher()
        let favoritesModel = NewTabPageFavoritesModel(
            actionsHandler: DefaultFavoritesActionsHandler(),
            favoritesPublisher: favoritesPublisher,
            getLegacyIsViewExpandedSetting: UserDefaultsWrapper<Bool>(key: .homePageShowAllFavorites, defaultValue: true).wrappedValue
        )

        let customizationProvider = NewTabPageCustomizationProvider(homePageSettingsModel: settingsModel)
        let freemiumDBPBannerProvider = NewTabPageFreemiumDBPBannerProvider(model: freemiumDBPPromotionViewCoordinator)

        let privacyStatsModel = NewTabPagePrivacyStatsModel(
            privacyStats: privacyStats,
            trackerDataProvider: PrivacyStatsTrackerDataProvider(contentBlocking: ContentBlocking.shared),
            eventMapping: NewTabPagePrivacyStatsEventHandler(),
            getLegacyIsViewExpandedSetting: UserDefaultsWrapper<Bool>(key: .homePageShowRecentlyVisited, defaultValue: false).wrappedValue
        )

        let recentActivityProvider = RecentActivityProvider(
            historyCoordinator: historyCoordinator,
            urlFavoriteStatusProvider: bookmarkManager,
            duckPlayerHistoryEntryTitleProvider: duckPlayerHistoryEntryTitleProvider,
            trackerEntityPrevalenceComparator: ContentBlockingPrevalenceComparator(contentBlocking: contentBlocking)
        )
        let recentActivityModel = NewTabPageRecentActivityModel(
            activityProvider: recentActivityProvider,
            actionsHandler: DefaultRecentActivityActionsHandler(),
            getLegacyIsViewExpandedSetting: UserDefaultsWrapper<Bool>(key: .homePageShowRecentlyVisited, defaultValue: false).wrappedValue
        )

        self.init(scriptClients: [
            NewTabPageConfigurationClient(
                sectionsAvailabilityProvider: NewTabPageModeDecider(),
                sectionsVisibilityProvider: appearancePreferences,
                customBackgroundProvider: customizationProvider,
                linkOpener: DefaultHomePageSettingsModelNavigator(),
                eventMapper: NewTabPageConfigurationErrorHandler()
            ),
            NewTabPageCustomBackgroundClient(model: customizationProvider),
            NewTabPageRMFClient(remoteMessageProvider: activeRemoteMessageModel),
            NewTabPageFreemiumDBPClient(provider: freemiumDBPBannerProvider),
            NewTabPageNextStepsCardsClient(model: NewTabPageNextStepsCardsProvider(continueSetUpModel: HomePage.Models.ContinueSetUpModel(tabOpener: NewTabPageTabOpener()))),
            NewTabPageFavoritesClient(favoritesModel: favoritesModel, preferredFaviconSize: Int(Favicon.SizeCategory.medium.rawValue)),
            NewTabPagePrivacyStatsClient(model: privacyStatsModel),
            NewTabPageRecentActivityClient(model: recentActivityModel)
        ])
    }
}

struct NewTabPageTabOpener: ContinueSetUpModelTabOpening {
    @MainActor
    func openTab(_ tab: Tab) {
        WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel.insertOrAppend(tab: tab, selected: true)
    }
}
