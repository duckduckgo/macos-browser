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

final class TabLazyLoader {

    /**
     * Emits output when lazy loader finishes.
     *
     * The output is `true` if lazy loading was performed and `false` if no tabs were lazy loaded.
     */
    private(set) lazy var lazyLoadingDidFinish: AnyPublisher<Bool, Never> = {
        lazyLoadingDidFinishSubject.prefix(1).eraseToAnyPublisher()
    }()

    init?(tabCollectionViewModel: TabCollectionViewModel) {
        guard tabCollectionViewModel.qualifiesForLazyLoading,
              let currentTab = tabCollectionViewModel.selectedTabViewModel?.tab
        else {
            os_log("Lazy loading not applicable", log: .tabLazyLoading, type: .debug)
            return nil
        }

        self.tabCollectionViewModel = tabCollectionViewModel

        trackUserSwitchingTabs()
        delayLazyLoadingUntilCurrentTabFinishesLoading(currentTab)
    }

    // MARK: - Private

    private enum Const {
        static let maxNumberOfLazyLoadedTabs = 3
    }

    private let lazyLoadingDidFinishSubject = PassthroughSubject<Bool, Never>()
    private let tabDidFinishLazyLoadingSubject = PassthroughSubject<Tab, Never>()
    private var tabsSelectedOrReloadedInThisSession = Set<Tab>()
    private var cancellables = Set<AnyCancellable>()

    private weak var tabCollectionViewModel: TabCollectionViewModel?

    private func trackUserSwitchingTabs() {

        tabCollectionViewModel?.$selectedTabViewModel
            .compactMap { $0?.tab }
            .sink { [weak self] tab in
                self?.tabsSelectedOrReloadedInThisSession.insert(tab)
            }
            .store(in: &cancellables)
    }

    private func delayLazyLoadingUntilCurrentTabFinishesLoading(_ tab: Tab) {
        guard tab.content.isUrl else {
            lazyLoadRecentlySelectedTabs()
            return
        }

        tab.loadingFinishedPublisher
            .sink { [weak self] _ in
                self?.lazyLoadRecentlySelectedTabs()
            }
            .store(in: &cancellables)
    }

    private func lazyLoadRecentlySelectedTabs() {
        let tabs = findRecentlySelectedTabs()
        guard !tabs.isEmpty else {
            os_log("No tabs for lazy loading", log: .tabLazyLoading, type: .debug)
            lazyLoadingDidFinishSubject.send(false)
            return
        }

        tabDidFinishLazyLoadingSubject
            .prefix(tabs.count)
            .sink(receiveCompletion: { [weak self] _ in
                os_log("Lazy tab loading finished", log: .tabLazyLoading, type: .debug)
                self?.lazyLoadingDidFinishSubject.send(true)
            }, receiveValue: { tab in
                os_log("Tab did finish loading %s", log: .tabLazyLoading, type: .debug, String(reflecting: tab.content.url))
            })
            .store(in: &cancellables)

        tabs.forEach { tab in
            subscribeToTabDidFinishNavigation(tab)
            os_log("Reloading %s", log: .tabLazyLoading, type: .debug, String(reflecting: tab.content.url))

            Task {
                let didRequestReload = await tab.reloadIfNeeded(shouldLoadInBackground: true)
                if !didRequestReload {
                    os_log("Tab cached, loading from cache %s", log: .tabLazyLoading, type: .debug, String(reflecting: tab.content.url))
                    tabDidFinishLazyLoadingSubject.send(tab)
                } else {
                    os_log("Tab not found in cache %s", log: .tabLazyLoading, type: .debug, String(reflecting: tab.content.url))
                }
            }
        }
    }

    private func findRecentlySelectedTabs() -> [Tab] {
        guard let viewModel = tabCollectionViewModel else {
            return []
        }

        return Array(
            viewModel.tabCollection.tabs
                .filter { $0.lastSelectedAt != nil && $0.content.isUrl && !tabsSelectedOrReloadedInThisSession.contains($0) }
                .sorted { $0.lastSelectedAt! > $1.lastSelectedAt! }
                .prefix(Const.maxNumberOfLazyLoadedTabs)
        )
    }

    private func subscribeToTabDidFinishNavigation(_ tab: Tab) {
        tab.loadingFinishedPublisher
            .subscribe(tabDidFinishLazyLoadingSubject)
            .store(in: &cancellables)
    }
}

private extension TabCollectionViewModel {
    var qualifiesForLazyLoading: Bool {

        let notSelectedURLTabsCount: Int = {
            let count = tabCollection.tabs.filter({ $0.content.isUrl }).count
            let isURLTabSelected = selectedTabViewModel?.tab.content.isUrl ?? false
            return isURLTabSelected ? count-1 : count
        }()

        return notSelectedURLTabsCount > 0
    }
}

private extension Tab {
    var loadingFinishedPublisher: AnyPublisher<Tab, Never> {
        Publishers.Merge(webViewDidFinishNavigationPublisher, webViewDidFailNavigationPublisher)
            .prefix(1)
            .map { self }
            .eraseToAnyPublisher()
    }
}
