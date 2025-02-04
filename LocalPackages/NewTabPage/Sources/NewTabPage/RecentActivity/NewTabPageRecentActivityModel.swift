//
//  NewTabPageRecentActivityModel.swift
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
import Common
import Foundation
import os.log
import Persistence
import PrivacyStats

/**
 * This protocol describes Recent Activity widget data source.
 *
 * It allows subscribing to history updates as well as triggering activity calculation on demand.
 */
public protocol NewTabPageRecentActivityProviding: AnyObject {
    /**
     * This function should return `DomainActivity` array based on current state of browser history.
     */
    func refreshActivity() -> [NewTabPageDataModel.DomainActivity]

    /**
     * This publisher should publish changes to `DomainActivity` array every time browser history is updated.
     */
    var activityPublisher: AnyPublisher<[NewTabPageDataModel.DomainActivity], Never> { get }
}

public protocol NewTabPageRecentActivitySettingsPersistor: AnyObject {
    var isViewExpanded: Bool { get set }
}

final class UserDefaultsNewTabPageRecentActivitySettingsPersistor: NewTabPageRecentActivitySettingsPersistor {
    enum Keys {
        static let isViewExpanded = "new-tab-page.recent-activity.is-view-expanded"
    }

    private let keyValueStore: KeyValueStoring

    init(_ keyValueStore: KeyValueStoring = UserDefaults.standard, getLegacySetting: @autoclosure () -> Bool?) {
        self.keyValueStore = keyValueStore
        migrateFromLegacyHomePageSettings(using: getLegacySetting)
    }

    var isViewExpanded: Bool {
        get { return keyValueStore.object(forKey: Keys.isViewExpanded) as? Bool ?? true }
        set { keyValueStore.set(newValue, forKey: Keys.isViewExpanded) }
    }

    private func migrateFromLegacyHomePageSettings(using getLegacySetting: () -> Bool?) {
        guard keyValueStore.object(forKey: Keys.isViewExpanded) == nil, let legacySetting = getLegacySetting() else {
            return
        }
        isViewExpanded = legacySetting
    }
}

public final class NewTabPageRecentActivityModel {

    let activityProvider: NewTabPageRecentActivityProviding
    let actionsHandler: RecentActivityActionsHandling

    @Published var isViewExpanded: Bool {
        didSet {
            settingsPersistor.isViewExpanded = self.isViewExpanded
        }
    }

    private let settingsPersistor: NewTabPageRecentActivitySettingsPersistor

    public convenience init(
        activityProvider: NewTabPageRecentActivityProviding,
        actionsHandler: RecentActivityActionsHandling,
        keyValueStore: KeyValueStoring = UserDefaults.standard,
        getLegacyIsViewExpandedSetting: @autoclosure () -> Bool?
    ) {
        self.init(
            activityProvider: activityProvider,
            actionsHandler: actionsHandler,
            settingsPersistor: UserDefaultsNewTabPageRecentActivitySettingsPersistor(keyValueStore, getLegacySetting: getLegacyIsViewExpandedSetting())
        )
    }

    init(
        activityProvider: NewTabPageRecentActivityProviding,
        actionsHandler: RecentActivityActionsHandling,
        settingsPersistor: NewTabPageRecentActivitySettingsPersistor
    ) {
        self.activityProvider = activityProvider
        self.actionsHandler = actionsHandler
        self.settingsPersistor = settingsPersistor

        isViewExpanded = settingsPersistor.isViewExpanded
    }

    // MARK: - Actions

    @MainActor func addFavorite(_ url: String) async {
        guard let url = URL(string: url), url.isValid else { return }
        await actionsHandler.addFavorite(url)
    }

    @MainActor func removeFavorite(_ url: String) async {
        guard let url = URL(string: url), url.isValid else { return }
        await actionsHandler.removeFavorite(url)
    }

    @MainActor func confirmBurn(_ url: String) async -> Bool {
        guard let url = URL(string: url), url.isValid else { return false }
        return await actionsHandler.confirmBurn(url)
    }

    @MainActor func open(_ url: String, target: LinkOpenTarget) async {
        guard let url = URL(string: url), url.isValid else { return }
        await actionsHandler.open(url, target: target)
    }
}
