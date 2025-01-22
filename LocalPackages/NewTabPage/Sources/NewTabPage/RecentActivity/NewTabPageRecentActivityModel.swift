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

public protocol NewTabPageRecentActivitySettingsPersistor: AnyObject {
    var isViewExpanded: Bool { get set }
}

final class UserDefaultsNewTabPageRecentActivitySettingsPersistor: NewTabPagePrivacyStatsSettingsPersistor {
    enum Keys {
        static let isViewExpanded = "new-tab-page.recent-activity.is-view-expanded"
    }

    private let keyValueStore: KeyValueStoring

    init(_ keyValueStore: KeyValueStoring = UserDefaults.standard, getLegacySetting: @autoclosure () -> Bool?) {
        self.keyValueStore = keyValueStore
        migrateFromLegacyHomePageSettings(using: getLegacySetting)
    }

    var isViewExpanded: Bool {
        get { return keyValueStore.object(forKey: Keys.isViewExpanded) as? Bool ?? false }
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

    let privacyStats: PrivacyStatsCollecting
    let actionsHandler: RecentActivityActionsHandling
    let statsUpdatePublisher: AnyPublisher<Void, Never>

    @Published var isViewExpanded: Bool {
        didSet {
            settingsPersistor.isViewExpanded = self.isViewExpanded
        }
    }

    @Published var activity: [NewTabPageDataModel.DomainActivity] = []

    private let settingsPersistor: NewTabPagePrivacyStatsSettingsPersistor
    private let statsUpdateSubject = PassthroughSubject<Void, Never>()
    private var cancellables: Set<AnyCancellable> = []

    public convenience init(
        privacyStats: PrivacyStatsCollecting,
        activityPublisher: AnyPublisher<[NewTabPageDataModel.DomainActivity], Never>,
        actionsHandler: RecentActivityActionsHandling,
        keyValueStore: KeyValueStoring = UserDefaults.standard,
        getLegacyIsViewExpandedSetting: @autoclosure () -> Bool?
    ) {
        self.init(
            privacyStats: privacyStats,
            activityPublisher: activityPublisher,
            actionsHandler: actionsHandler,
            settingsPersistor: UserDefaultsNewTabPagePrivacyStatsSettingsPersistor(keyValueStore, getLegacySetting: getLegacyIsViewExpandedSetting())
        )
    }

    init(
        privacyStats: PrivacyStatsCollecting,
        activityPublisher: AnyPublisher<[NewTabPageDataModel.DomainActivity], Never>,
        actionsHandler: RecentActivityActionsHandling,
        settingsPersistor: NewTabPagePrivacyStatsSettingsPersistor
    ) {
        self.privacyStats = privacyStats
        self.actionsHandler = actionsHandler
        self.settingsPersistor = settingsPersistor

        isViewExpanded = settingsPersistor.isViewExpanded
        statsUpdatePublisher = statsUpdateSubject.eraseToAnyPublisher()

        activityPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] activity in
                self?.activity = activity
            }
            .store(in: &cancellables)

        privacyStats.statsUpdatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.statsUpdateSubject.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @MainActor
    func open(_ url: String, target: LinkOpenTarget) {
        guard let url = URL(string: url), url.isValid else { return }
        actionsHandler.open(url, target: target)
    }
}
