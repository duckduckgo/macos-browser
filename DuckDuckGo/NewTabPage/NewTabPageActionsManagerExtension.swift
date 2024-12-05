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
import NewTabPage
import PrivacyStats

extension NewTabPageActionsManager {

    convenience init(
        appearancePreferences: AppearancePreferences,
        activeRemoteMessageModel: ActiveRemoteMessageModel,
        privacyStats: PrivacyStatsCollecting,
        openURLHandler: @escaping (URL) -> Void
    ) {
        let privacyStatsModel = NewTabPagePrivacyStatsModel(
            privacyStats: privacyStats,
            trackerDataProvider: PrivacyStatsTrackerDataProvider(contentBlocking: ContentBlocking.shared),
            keyValueStore: UserDefaults.standard,
            getLegacyIsViewExpandedSetting: UserDefaultsWrapper<Bool>(key: .homePageShowRecentlyVisited, defaultValue: false).wrappedValue
        )

        let favoritesPublisher = LocalBookmarkManager.shared.listPublisher.map({ $0?.favoriteBookmarks ?? [] }).eraseToAnyPublisher()
        let favoritesModel = NewTabPageFavoritesModel(actionsHandler: DefaultFavoritesActionsHandler(), favoritesPublisher: favoritesPublisher)

        self.init(scriptClients: [
            NewTabPageConfigurationClient(sectionsVisibilityProvider: appearancePreferences),
            NewTabPageRMFClient(remoteMessageProvider: activeRemoteMessageModel, openURLHandler: openURLHandler),
            NewTabPageNextStepsCardsClient(model: HomePage.Models.ContinueSetUpModel(tabOpener: NewTabPageTabOpener())),
            NewTabPageFavoritesClient(favoritesModel: favoritesModel),
            NewTabPagePrivacyStatsClient(model: privacyStatsModel)
        ])
    }
}

struct NewTabPageTabOpener: ContinueSetUpModelTabOpening {
    @MainActor
    func openTab(_ tab: Tab) {
        WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel.insertOrAppend(tab: tab, selected: true)
    }
}
