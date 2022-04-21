//
//  TabLazyLoader.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import os

final class TabLazyLoader<DataSource: TabLazyLoaderDataSource> {

    /**
     * Emits output when lazy loader finishes.
     *
     * The output is `true` if lazy loading was performed and `false` if no tabs were lazy loaded.
     */
    private(set) lazy var lazyLoadingDidFinishPublisher: AnyPublisher<Bool, Never> = {
        lazyLoadingDidFinishSubject.prefix(1).eraseToAnyPublisher()
    }()

    init?(dataSource: DataSource) {
        guard dataSource.qualifiesForLazyLoading else {
            os_log("Lazy loading not applicable", log: .tabLazyLoading, type: .debug)
            return nil
        }

        self.dataSource = dataSource
    }

    func scheduleLazyLoading() {
        guard let currentTab = dataSource?.selectedTab else {
            os_log("Lazy loading not applicable", log: .tabLazyLoading, type: .debug)
            lazyLoadingDidFinishSubject.send(false)
            return
        }

        trackUserSwitchingTabs()
        delayLazyLoadingUntilCurrentTabFinishesLoading(currentTab)
    }

    // MARK: - Private

    enum Const {
        static var maxNumberOfLazyLoadedTabs: Int { 20 }
        static var maxNumberOfConcurrentlyLoadedTabs: Int { 3 }
    }

    private let lazyLoadingDidFinishSubject = PassthroughSubject<Bool, Never>()
    private let tabDidLoadSubject = PassthroughSubject<DataSource.Tab, Never>()

    private let numberOfTabsInProgress = CurrentValueSubject<Int, Never>(0)
    private var numberOfTabsRemaining = Const.maxNumberOfLazyLoadedTabs

    private var idsOfTabsSelectedOrReloadedInThisSession = Set<DataSource.Tab.ID>()
    private var cancellables = Set<AnyCancellable>()

    private weak var dataSource: DataSource?

    private func trackUserSwitchingTabs() {
        dataSource?.selectedTabPublisher
            .sink { [weak self] tab in
                self?.idsOfTabsSelectedOrReloadedInThisSession.insert(tab.id)
            }
            .store(in: &cancellables)
    }

    private func delayLazyLoadingUntilCurrentTabFinishesLoading(_ tab: DataSource.Tab) {
        guard tab.isUrl else {
            startLazyLoadingRecentlySelectedTabs()
            return
        }

        tab.loadingFinishedPublisher
            .sink { [weak self] _ in
                self?.startLazyLoadingRecentlySelectedTabs()
            }
            .store(in: &cancellables)
    }

    private func startLazyLoadingRecentlySelectedTabs() {
        guard findTabToLoad() != nil else {
            os_log("No tabs to load", log: .tabLazyLoading, type: .debug)
            let loadedAnyTab = numberOfTabsRemaining < Const.maxNumberOfLazyLoadedTabs
            lazyLoadingDidFinishSubject.send(loadedAnyTab)
            return
        }

        tabDidLoadSubject
            .prefix(Const.maxNumberOfLazyLoadedTabs)
            .sink(receiveCompletion: { [weak self] _ in

                os_log("Lazy tab loading finished, preloaded %d tabs", log: .tabLazyLoading, type: .debug, Const.maxNumberOfLazyLoadedTabs)
                self?.lazyLoadingDidFinishSubject.send(true)

            }, receiveValue: { [weak self] tab in

                os_log("Tab did finish loading %s", log: .tabLazyLoading, type: .debug, String(reflecting: tab.url))
                self?.numberOfTabsInProgress.value -= 1

            })
            .store(in: &cancellables)

        numberOfTabsInProgress
            .filter { $0 < Const.maxNumberOfConcurrentlyLoadedTabs }
            .sink { [weak self] _ in
                self?.findAndReloadRecentlySelectedTab()
            }
            .store(in: &cancellables)
    }

    private func findAndReloadRecentlySelectedTab() {
        guard numberOfTabsRemaining > 0 else {
            os_log("Maximum allowed tabs loaded (%d), skipping", log: .tabLazyLoading, type: .debug, Const.maxNumberOfLazyLoadedTabs)
            return
        }

        let tabToLoad = findTabToLoad()

        switch (tabToLoad, numberOfTabsInProgress.value) {
        case (.none, 0):
            os_log("No more tabs suitable for lazy loading", log: .tabLazyLoading, type: .debug)
            lazyLoadingDidFinishSubject.send(true)
        case (.none, _):
            break
        case (let .some(tab), _):
            lazyLoadTab(tab)
        }
    }

    private func findTabToLoad() -> DataSource.Tab? {
        dataSource?.tabs
            .filter { $0.isUrl && !idsOfTabsSelectedOrReloadedInThisSession.contains($0.id) }
            .sorted { $0.isNewer(than: $1) }
            .first
    }

    private func lazyLoadTab(_ tab: DataSource.Tab) {
        os_log("Reloading %s", log: .tabLazyLoading, type: .debug, String(reflecting: tab.url))

        subscribeToTabLoadingFinished(tab)
        idsOfTabsSelectedOrReloadedInThisSession.insert(tab.id)

        if let selectedTabWebViewFrame = dataSource?.selectedTab?.webViewFrame {
            tab.webViewFrame = selectedTabWebViewFrame
        }

        numberOfTabsRemaining -= 1
        numberOfTabsInProgress.value += 1
        tab.reload()
    }

    private func subscribeToTabLoadingFinished(_ tab: DataSource.Tab) {
        tab.loadingFinishedPublisher
            .sink(receiveValue: { [weak self] tab in
                self?.tabDidLoadSubject.send(tab)
            })
            .store(in: &cancellables)
    }
}
