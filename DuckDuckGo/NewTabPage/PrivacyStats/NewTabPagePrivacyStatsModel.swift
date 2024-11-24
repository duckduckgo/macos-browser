//
//  NewTabPagePrivacyStatsModel.swift
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

import Combine
import Persistence
import PrivacyStats

protocol NewTabPagePrivacyStatsSettingsPersistor: AnyObject {
    var isViewExpanded: Bool { get set }
}

final class UserDefaultsNewTabPagePrivacyStatsSettingsPersistor: NewTabPagePrivacyStatsSettingsPersistor {
    enum Keys {
        static let isViewExpanded = "new-tab-page.privacy-stats.is-view-expanded"
    }

    private let keyValueStore: KeyValueStoring

    init(_ keyValueStore: KeyValueStoring = UserDefaults.standard) {
        self.keyValueStore = keyValueStore
        migrateFromNativeHomePageSettings()
    }

    var isViewExpanded: Bool {
        get { return keyValueStore.object(forKey: Keys.isViewExpanded) as? Bool ?? false }
        set { keyValueStore.set(newValue, forKey: Keys.isViewExpanded) }
    }

    private func migrateFromNativeHomePageSettings() {
        guard keyValueStore.object(forKey: Keys.isViewExpanded) == nil else {
            return
        }
        let legacyKey = UserDefaultsWrapper<Any>.Key.homePageShowRecentlyVisited.rawValue
        isViewExpanded = keyValueStore.object(forKey: legacyKey) as? Bool ?? false
    }
}

final class NewTabPagePrivacyStatsModel {

    let privacyStats: PrivacyStatsCollecting

    let statsUpdatePublisher: AnyPublisher<Void, Never>

    @Published var isViewExpanded: Bool {
        didSet {
            settingsPersistor.isViewExpanded = self.isViewExpanded
        }
    }

    private let settingsPersistor: NewTabPagePrivacyStatsSettingsPersistor

    private let statsUpdateSubject = PassthroughSubject<Void, Never>()
    private var statsUpdateCancellable: AnyCancellable?

    init(
        privacyStats: PrivacyStatsCollecting,
        settingsPersistor: NewTabPagePrivacyStatsSettingsPersistor = UserDefaultsNewTabPagePrivacyStatsSettingsPersistor()
    ) {
        self.privacyStats = privacyStats
        self.settingsPersistor = settingsPersistor

        isViewExpanded = settingsPersistor.isViewExpanded
        statsUpdatePublisher = statsUpdateSubject.eraseToAnyPublisher()

        statsUpdateCancellable = privacyStats.currentStatsPublisher
            .debounce(for: 1, scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.statsUpdateSubject.send()
            }
    }
}
