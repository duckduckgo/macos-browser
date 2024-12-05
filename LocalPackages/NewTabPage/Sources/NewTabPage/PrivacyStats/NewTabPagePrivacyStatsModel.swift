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
import os.log
import Persistence
import PrivacyStats

public protocol NewTabPagePrivacyStatsSettingsPersistor: AnyObject {
    var isViewExpanded: Bool { get set }
}

public final class UserDefaultsNewTabPagePrivacyStatsSettingsPersistor: NewTabPagePrivacyStatsSettingsPersistor {
    enum Keys {
        static let isViewExpanded = "new-tab-page.privacy-stats.is-view-expanded"
    }

    private let keyValueStore: KeyValueStoring

    public init(_ keyValueStore: KeyValueStoring) {
        self.keyValueStore = keyValueStore
        migrateFromNativeHomePageSettings()
    }

    public var isViewExpanded: Bool {
        get { return keyValueStore.object(forKey: Keys.isViewExpanded) as? Bool ?? false }
        set { keyValueStore.set(newValue, forKey: Keys.isViewExpanded) }
    }

    private func migrateFromNativeHomePageSettings() {
//        guard keyValueStore.object(forKey: Keys.isViewExpanded) == nil else {
//            return
//        }
//        let legacyKey = UserDefaultsWrapper<Any>.Key.homePageShowRecentlyVisited.rawValue
//        isViewExpanded = keyValueStore.object(forKey: legacyKey) as? Bool ?? false
    }
}

public final class NewTabPagePrivacyStatsModel {

    public let privacyStats: PrivacyStatsCollecting
    public let statsUpdatePublisher: AnyPublisher<Void, Never>

    @Published public var isViewExpanded: Bool {
        didSet {
            settingsPersistor.isViewExpanded = self.isViewExpanded
        }
    }

    private let settingsPersistor: NewTabPagePrivacyStatsSettingsPersistor
    private var topCompanies: Set<String> = []
    private let trackerDataProvider: PrivacyStatsTrackerDataProviding

    private let statsUpdateSubject = PassthroughSubject<Void, Never>()
    private var cancellables: Set<AnyCancellable> = []

    public convenience init(
        privacyStats: PrivacyStatsCollecting,
        trackerDataProvider: PrivacyStatsTrackerDataProviding,
        keyValueStore: KeyValueStoring
    ) {
        self.init(
            privacyStats: privacyStats,
            trackerDataProvider: trackerDataProvider,
            settingsPersistor: UserDefaultsNewTabPagePrivacyStatsSettingsPersistor(keyValueStore)
        )
    }

    public init(
        privacyStats: PrivacyStatsCollecting,
        trackerDataProvider: PrivacyStatsTrackerDataProviding,
        settingsPersistor: NewTabPagePrivacyStatsSettingsPersistor
    ) {
        self.privacyStats = privacyStats
        self.trackerDataProvider = trackerDataProvider
        self.settingsPersistor = settingsPersistor

        isViewExpanded = settingsPersistor.isViewExpanded
        statsUpdatePublisher = statsUpdateSubject.eraseToAnyPublisher()

        privacyStats.statsUpdatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.statsUpdateSubject.send()
            }
            .store(in: &cancellables)

        trackerDataProvider.trackerDataUpdatesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.refreshTopCompanies()
            }
            .store(in: &cancellables)

        refreshTopCompanies()
    }

    public func calculatePrivacyStats() async -> NewTabPagePrivacyStatsClient.PrivacyStatsData {
        let stats = await privacyStats.fetchPrivacyStats()

        var totalCount: Int64 = 0
        var otherCount: Int64 = 0

        var companiesStats: [NewTabPagePrivacyStatsClient.TrackerCompany] = stats.compactMap { key, value in
            totalCount += value
            guard topCompanies.contains(key) else {
                otherCount += value
                return nil
            }
            return NewTabPagePrivacyStatsClient.TrackerCompany(count: value, displayName: key)
        }

        if otherCount > 0 {
            companiesStats.append(.otherCompanies(count: otherCount))
        }
        return NewTabPagePrivacyStatsClient.PrivacyStatsData(totalCount: totalCount, trackerCompanies: companiesStats)
    }

    private func refreshTopCompanies() {
        struct TrackerWithPrevalence {
            let name: String
            let prevalence: Double
        }

        let trackers: [TrackerWithPrevalence] = trackerDataProvider.trackerData.entities.values.compactMap { entity in
            guard let displayName = entity.displayName, let prevalence = entity.prevalence else {
                return nil
            }
            return TrackerWithPrevalence(name: displayName, prevalence: prevalence)
        }

        let topTrackersArray = trackers.sorted(by: { $0.prevalence > $1.prevalence }).prefix(Const.maxTopCompaniesCount).map(\.name)
        Logger.privacyStats.debug("top tracker companies: \(topTrackersArray)")
        topCompanies = Set(topTrackersArray)
    }

    private enum Const {
        /**
         * This number is arbitrary, we decided to only show up to 100 most popular companies
         * while putting all others into "Other companies" bucket. FWIW, at the time of writing
         * this there are 831 companies in total in the Tracker Data Set.
         */
        static let maxTopCompaniesCount: Int = 100
    }
}
