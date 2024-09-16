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
import Common
import os.log

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
            Logger.tabLazyLoading.debug("Lazy loading not applicable")
            return nil
        }

        self.dataSource = dataSource

        if let selectedTabIndex = dataSource.selectedTabIndex,
           dataSource.tabs.filter({ $0.isUrl }).count > Const.maxNumberOfLazyLoadedTabs {

            Logger.tabLazyLoading.debug("\(dataSource.tabs.count) open URL tabs, will load adjacent tabs first")
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
            Logger.tabLazyLoading.debug("Lazy loading not applicable")
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
            Logger.tabLazyLoading.debug("No tabs to load")
            let loadedAnyTab = numberOfTabsRemaining < Const.maxNumberOfLazyLoadedTabs
            lazyLoadingDidFinishSubject.send(loadedAnyTab)
            return
        }

        tabDidLoadSubject
            .prefix(Const.maxNumberOfLazyLoadedTabs)
            .sink(receiveCompletion: { [weak self] _ in

                Logger.tabLazyLoading.debug("Lazy tab loading finished, preloaded \(Const.maxNumberOfLazyLoadedTabs) tabs")
                self?.lazyLoadingDidFinishSubject.send(true)

            }, receiveValue: { [weak self] tab in

                Logger.tabLazyLoading.debug("Tab did finish loading \(String(reflecting: tab.url))")
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
                    Logger.tabLazyLoading.debug("Selected tab is currently loading, pausing lazy loading until it finishes")
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
            Logger.tabLazyLoading.debug("Maximum allowed tabs loaded (\(Const.maxNumberOfLazyLoadedTabs), skipping")
            return
        }

        let tabToLoad = findTabToLoad()

        switch (tabToLoad, numberOfTabsInProgress.value) {
        case (.none, 0):
            Logger.tabLazyLoading.debug("No more tabs suitable for lazy loading")
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
                Logger.tabLazyLoading.debug("Will reload recently selected pinned tab")
            }
        } else {
            if shouldLoadAdjacentTabs, numberOfAdjacentTabsRemaining > 0 {
                tab = findAdjacentTabToLoad()
                if dryRun {
                    adjacentItemEnumerator?.reset()
                } else if tab != nil {
                    numberOfAdjacentTabsRemaining -= 1
                    Logger.tabLazyLoading.debug("Will reload adjacent tab #\(Const.maxNumberOfLazyLoadedAdjacentTabs - self.numberOfAdjacentTabsRemaining) of \(Const.maxNumberOfLazyLoadedAdjacentTabs)")
                }
            }

            if tab == nil {
                tab = findRecentlySelectedTabToLoad(from: dataSource.tabs)
                if !dryRun, tab != nil {
                    Logger.tabLazyLoading.debug("Will reload recently selected tab")
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
        Logger.tabLazyLoading.debug("Reloading \(String(reflecting: tab.url))")

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
