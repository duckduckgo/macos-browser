//
//  NewTabPageCoordinator.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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
import Foundation
import History
import NewTabPage
import Persistence
import PixelKit
import PrivacyStats

final class NewTabPageCoordinator {
    let actionsManager: NewTabPageActionsManager
    let keyValueStore: KeyValueStoring

    init(
        appearancePreferences: AppearancePreferences,
        settingsModel: HomePage.Models.SettingsModel,
        bookmarkManager: BookmarkManager & URLFavoriteStatusProviding = LocalBookmarkManager.shared,
        activeRemoteMessageModel: ActiveRemoteMessageModel,
        historyCoordinator: HistoryCoordinating,
        privacyStats: PrivacyStatsCollecting,
        freemiumDBPPromotionViewCoordinator: FreemiumDBPPromotionViewCoordinator,
        keyValueStore: KeyValueStoring = UserDefaults.standard,
        notificationCenter: NotificationCenter = .default,
        fireDailyPixel: @escaping (PixelKitEvent) -> Void = { PixelKit.fire($0, frequency: .daily) }
    ) {
        actionsManager = NewTabPageActionsManager(
            appearancePreferences: appearancePreferences,
            settingsModel: settingsModel,
            bookmarkManager: bookmarkManager,
            activeRemoteMessageModel: activeRemoteMessageModel,
            historyCoordinator: historyCoordinator,
            privacyStats: privacyStats,
            freemiumDBPPromotionViewCoordinator: freemiumDBPPromotionViewCoordinator
        )
        self.keyValueStore = keyValueStore
        self.fireDailyPixel = fireDailyPixel

        notificationCenter.publisher(for: .newTabPageWebViewDidAppear)
            .prefix(1)
            .sink { [weak self, weak settingsModel, weak appearancePreferences] _ in
                guard let self, let settingsModel, let appearancePreferences else {
                    return
                }
                fireNewTabPageShownPixel(appearancePreferences: appearancePreferences, settingsModel: settingsModel)
            }
            .store(in: &cancellables)
    }

    private func fireNewTabPageShownPixel(appearancePreferences: AppearancePreferences, settingsModel: HomePage.Models.SettingsModel) {
        let mode = NewTabPageModeDecider(keyValueStore: keyValueStore).effectiveMode
        let recentActivity = mode == .recentActivity ? appearancePreferences.isRecentActivityVisible : nil
        let privacyStats = mode == .privacyStats ? appearancePreferences.isPrivacyStatsVisible : nil
        let customBackground = settingsModel.customBackground != nil

        fireDailyPixel(
            NewTabPagePixel.newTabPageShown(
                favorites: appearancePreferences.isFavoriteVisible,
                recentActivity: recentActivity,
                privacyStats: privacyStats,
                customBackground: customBackground
            )
        )
    }

    private let fireDailyPixel: (PixelKitEvent) -> Void
    private var cancellables: Set<AnyCancellable> = []
}
