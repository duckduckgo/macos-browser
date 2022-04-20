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

protocol TabLazyLoaderDataSource: AnyObject {
    var tabs: [Tab] { get }
    var selectedTab: Tab? { get }
    var selectedTabPublisher: AnyPublisher<Tab, Never> { get }
}

extension TabLazyLoaderDataSource {
    var qualifiesForLazyLoading: Bool {

        let notSelectedURLTabsCount: Int = {
            let count = tabs.filter({ $0.content.isUrl }).count
            let isURLTabSelected = selectedTab?.content.isUrl ?? false
            return isURLTabSelected ? count-1 : count
        }()

        return notSelectedURLTabsCount > 0
    }
}

// MARK: - TabLazyLoader

final class TabLazyLoader {

    /**
     * Emits output when lazy loader finishes.
     *
     * The output is `true` if lazy loading was performed and `false` if no tabs were lazy loaded.
     */
    private(set) lazy var lazyLoadingDidFinishPublisher: AnyPublisher<Bool, Never> = {
        lazyLoadingDidFinishSubject.prefix(1).eraseToAnyPublisher()
    }()

    init?(dataSource: TabLazyLoaderDataSource) {
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

    private enum Const {
        static let maxNumberOfLazyLoadedTabs = 20
        static let maxNumberOfConcurrentlyLoadedTabs = 3
    }

    private let lazyLoadingDidFinishSubject = PassthroughSubject<Bool, Never>()
    private let tabDidLoadSubject = PassthroughSubject<Tab, Never>()

    private let numberOfTabsInProgress = CurrentValueSubject<Int, Never>(0)
    private var numberOfTabsRemaining = Const.maxNumberOfLazyLoadedTabs

    private var tabsSelectedOrReloadedInThisSession = Set<Tab>()
    private var cancellables = Set<AnyCancellable>()

    private weak var dataSource: TabLazyLoaderDataSource?

    private func trackUserSwitchingTabs() {
        dataSource?.selectedTabPublisher
            .sink { [weak self] tab in
                self?.tabsSelectedOrReloadedInThisSession.insert(tab)
            }
            .store(in: &cancellables)
    }

    private func delayLazyLoadingUntilCurrentTabFinishesLoading(_ tab: Tab) {
        guard tab.content.isUrl else {
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
            lazyLoadingDidFinishSubject.send(false)
            return
        }

        tabDidLoadSubject
            .prefix(Const.maxNumberOfLazyLoadedTabs)
            .sink(receiveCompletion: { [weak self] _ in

                os_log("Lazy tab loading finished, preloaded %d tabs", log: .tabLazyLoading, type: .debug, Const.maxNumberOfLazyLoadedTabs)
                self?.lazyLoadingDidFinishSubject.send(true)

            }, receiveValue: { [weak self] tab in

                os_log("Tab did finish loading %s", log: .tabLazyLoading, type: .debug, String(reflecting: tab.content.url))
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

    private func findTabToLoad() -> Tab? {
        dataSource?.tabs
            .filter { $0.content.isUrl && !tabsSelectedOrReloadedInThisSession.contains($0) }
            .sorted { $0.isNewer(than: $1) }
            .first
    }

    private func lazyLoadTab(_ tab: Tab) {
        os_log("Reloading %s", log: .tabLazyLoading, type: .debug, String(reflecting: tab.content.url))

        subscribeToTabLoadingFinished(tab)
        tabsSelectedOrReloadedInThisSession.insert(tab)

        if let selectedTabWebViewFrame = dataSource?.selectedTab?.webView.frame {
            tab.webView.frame = selectedTabWebViewFrame
        }
        tab.reload()

        numberOfTabsRemaining -= 1
        DispatchQueue.main.async {
            self.numberOfTabsInProgress.value += 1
        }
    }

    private func subscribeToTabLoadingFinished(_ tab: Tab) {
        tab.loadingFinishedPublisher
            .sink(receiveValue: { [weak self] tab in
                self?.tabDidLoadSubject.send(tab)
            })
            .store(in: &cancellables)
    }
}

extension TabCollectionViewModel: TabLazyLoaderDataSource {
    var tabs: [Tab] {
        tabCollection.tabs
    }

    var selectedTab: Tab? {
        selectedTabViewModel?.tab
    }

    var selectedTabPublisher: AnyPublisher<Tab, Never> {
        $selectedTabViewModel.compactMap(\.?.tab).eraseToAnyPublisher()
    }
}

private extension Tab {
    var loadingFinishedPublisher: AnyPublisher<Tab, Never> {
        Publishers.Merge(webViewDidFinishNavigationPublisher, webViewDidFailNavigationPublisher)
            .prefix(1)
            .map { self }
            .eraseToAnyPublisher()
    }

    func isNewer(than other: Tab) -> Bool {
        switch (lastSelectedAt, other.lastSelectedAt) {
        case (.none, .none), (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.some(let timestamp), .some(let otherTimestamp)):
            return timestamp > otherTimestamp
        }
    }
}
