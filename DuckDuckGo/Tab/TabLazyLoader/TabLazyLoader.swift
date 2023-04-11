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

    enum Const {
        static var maxNumberOfLazyLoadedTabs: Int { 20 }
        static var maxNumberOfLazyLoadedAdjacentTabs: Int { 10 }
        static var maxNumberOfConcurrentlyLoadedTabs: Int { 3 }
    }

    /**
     * Emits output when lazy loader finishes.
     *
     * The output is `true` if lazy loading was performed and `false` if no tabs were lazy loaded.
     */
    private(set) lazy var lazyLoadingDidFinishPublisher: AnyPublisher<Bool, Never> = {
        lazyLoadingDidFinishSubject.prefix(1).eraseToAnyPublisher()
    }()

    private(set) lazy var isLazyLoadingPausedPublisher: AnyPublisher<Bool, Never> = {
        isLazyLoadingPausedSubject.removeDuplicates().eraseToAnyPublisher()
    }()

    init?(dataSource: DataSource) {
        guard dataSource.qualifiesForLazyLoading else {
            os_log("Lazy loading not applicable", log: .tabLazyLoading, type: .debug)
            return nil
        }

        self.dataSource = dataSource

        if let selectedTabIndex = dataSource.selectedTabIndex,
           dataSource.tabs.filter({ $0.isUrl }).count > Const.maxNumberOfLazyLoadedTabs {

            os_log("%d open URL tabs, will load adjacent tabs first", log: .tabLazyLoading, type: .debug, dataSource.tabs.count)
            shouldLoadAdjacentTabs = true

            // Adjacent tab loading only applies to non-pinned tabs. If a pinned tab is selected,
            // start adjacent tab loading from the first tab (closest to pinned tabs section).
            adjacentItemEnumerator = .init(itemIndex: selectedTabIndex.isUnpinnedTab ? selectedTabIndex.item : 0)
        } else {
            shouldLoadAdjacentTabs = false
        }
    }

    func scheduleLazyLoading() {
        guard let currentTab = dataSource.selectedTab else {
            os_log("Lazy loading not applicable", log: .tabLazyLoading, type: .debug)
            lazyLoadingDidFinishSubject.send(false)
            return
        }

        trackUserSwitchingTabs()
        delayLazyLoadingUntilCurrentTabFinishesLoading(currentTab)
    }

    // MARK: - Private

    private let lazyLoadingDidFinishSubject = PassthroughSubject<Bool, Never>()
    private let isLazyLoadingPausedSubject = CurrentValueSubject<Bool, Never>(false)
    private let tabDidLoadSubject = PassthroughSubject<DataSource.Tab, Never>()

    private let numberOfTabsInProgress = CurrentValueSubject<Int, Never>(0)
    private var numberOfTabsRemaining = Const.maxNumberOfLazyLoadedTabs

    private let shouldLoadAdjacentTabs: Bool
    private var adjacentItemEnumerator: AdjacentItemEnumerator?
    private var numberOfAdjacentTabsRemaining = Const.maxNumberOfLazyLoadedAdjacentTabs

    private var idsOfTabsSelectedOrReloadedInThisSession = Set<DataSource.Tab.ID>()
    private var cancellables = Set<AnyCancellable>()

    private unowned var dataSource: DataSource

    private func trackUserSwitchingTabs() {
        dataSource.selectedTabPublisher
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
        guard hasAnyTabsToLoad() else {
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

        willReloadNextTab
            .sink { [weak self] in
                self?.findAndReloadNextTab()
            }
            .store(in: &cancellables)
    }

    private var willReloadNextTab: AnyPublisher<Void, Never> {
        let readyToLoadNextTab = numberOfTabsInProgress
            .filter { [weak self] _ in
                guard let self = self else { return false }

                if self.dataSource.isSelectedTabLoading {
                    os_log("Selected tab is currently loading, pausing lazy loading until it finishes", log: .tabLazyLoading, type: .debug)
                    self.isLazyLoadingPausedSubject.send(true)
                    return false
                }
                self.isLazyLoadingPausedSubject.send(false)
                return true
            }
            .asVoid()

        let selectedTabDidFinishLoading = dataSource.isSelectedTabLoadingPublisher.filter({ !$0 }).asVoid()

        return Publishers.Merge(readyToLoadNextTab, selectedTabDidFinishLoading)
            .filter { [weak self] in
                (self?.numberOfTabsInProgress.value ?? 0) < Const.maxNumberOfConcurrentlyLoadedTabs
            }
            .eraseToAnyPublisher()
    }

    private func findAndReloadNextTab() {
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

    private func hasAnyTabsToLoad() -> Bool {
        return findTabToLoad(dryRun: true) != nil
    }

    /**
     * `dryRun` parameter, when set to `true`, reverts any changes made to lazy loader's state.
     *
     * This is to allow this function to be called to check whether there is any tab,
     * either adjacent to current or recently selected, that can be loaded.
     */
    private func findTabToLoad(dryRun: Bool = false) -> DataSource.Tab? {
        var tab: DataSource.Tab?

        tab = findRecentlySelectedTabToLoad(from: dataSource.pinnedTabs)

        if tab != nil {
            if !dryRun {
                os_log("Will reload recently selected pinned tab", log: .tabLazyLoading, type: .debug)
            }
        } else {
            if shouldLoadAdjacentTabs, numberOfAdjacentTabsRemaining > 0 {
                tab = findAdjacentTabToLoad()
                if dryRun {
                    adjacentItemEnumerator?.reset()
                } else if tab != nil {
                    numberOfAdjacentTabsRemaining -= 1
                    os_log("Will reload adjacent tab #%d of %d", log: .tabLazyLoading, type: .debug,
                           Const.maxNumberOfLazyLoadedAdjacentTabs - numberOfAdjacentTabsRemaining,
                           Const.maxNumberOfLazyLoadedAdjacentTabs)
                }
            }

            if tab == nil {
                tab = findRecentlySelectedTabToLoad(from: dataSource.tabs)
                if !dryRun, tab != nil {
                    os_log("Will reload recently selected tab", log: .tabLazyLoading, type: .debug)
                }
            }
        }

        return tab
    }

    private func findAdjacentTabToLoad() -> DataSource.Tab? {
        while true {
            guard let nextIndex = adjacentItemEnumerator?.nextIndex(arraySize: dataSource.tabs.count) else {
                return nil
            }
            let tab = dataSource.tabs[nextIndex]
            if tab.isUrl {
                return tab
            }
        }
    }

    private func findRecentlySelectedTabToLoad(from collection: [DataSource.Tab]) -> DataSource.Tab? {
        collection
            .filter { $0.isUrl && !idsOfTabsSelectedOrReloadedInThisSession.contains($0.id) }
            .sorted { $0.isNewer(than: $1) }
            .first
    }

    private func lazyLoadTab(_ tab: DataSource.Tab) {
        os_log("Reloading %s", log: .tabLazyLoading, type: .debug, String(reflecting: tab.url))

        subscribeToTabLoadingFinished(tab)
        idsOfTabsSelectedOrReloadedInThisSession.insert(tab.id)

        if let selectedTabWebViewSize = dataSource.selectedTab?.webViewSize {
            tab.webViewSize = selectedTabWebViewSize
        }

        tab.isLazyLoadingInProgress = true
        tab.reload()
        numberOfTabsRemaining -= 1
        numberOfTabsInProgress.value += 1
    }

    private func subscribeToTabLoadingFinished(_ tab: DataSource.Tab) {
        tab.loadingFinishedPublisher
            .sink(receiveValue: { [weak self] tab in
                tab.isLazyLoadingInProgress = false
                self?.tabDidLoadSubject.send(tab)
            })
            .store(in: &cancellables)
    }
}
