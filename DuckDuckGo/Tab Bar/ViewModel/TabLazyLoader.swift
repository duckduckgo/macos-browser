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

final class TabLazyLoader {

    @Published private(set) var isInProgress: Bool = true

    init?(tabCollectionViewModel: TabCollectionViewModel) {
        guard tabCollectionViewModel.qualifiesForLazyLoading,
              let currentTab = tabCollectionViewModel.selectedTabViewModel?.tab
        else {
            print("Lazy loading not applicable")
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

    private var tabDidFinishLazyLoadingPublisher = PassthroughSubject<Tab, Never>()
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
            print("No tabs for lazy loading")
            isInProgress = false
            return
        }

        tabDidFinishLazyLoadingPublisher
            .prefix(tabs.count)
            .sink(receiveCompletion: { [weak self] _ in
                print("Lazy tab loading finished")
                self?.isInProgress = false
            }, receiveValue: { tab in
                print("Tab did finish loading", String(reflecting: tab.content.url))
            })
            .store(in: &cancellables)

        tabs.forEach { tab in
            subscribeToTabDidFinishNavigation(tab)
            print("Reloading", String(reflecting: tab.content.url))

            Task {
                let didRequestReload = await tab.reloadIfNeeded(shouldLoadInBackground: true)
                if !didRequestReload {
                    print("Tab cached, loading from cache", String(reflecting: tab.content.url))
                    tabDidFinishLazyLoadingPublisher.send(tab)
                } else {
                    print("Tab not found in cache", String(reflecting: tab.content.url))
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
            .subscribe(tabDidFinishLazyLoadingPublisher)
            .store(in: &cancellables)
    }
}

private extension TabCollectionViewModel {
    var qualifiesForLazyLoading: Bool {
        tabCollection.tabs.filter({ $0.content.isUrl }).count > 1
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
