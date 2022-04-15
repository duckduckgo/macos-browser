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

    private enum Const {
        static let numberOfLazyLoadedTabs = 3
    }

    private var tabsSelectedOrReloadedInThisSession = Set<Tab>()
    private var cancellables = Set<AnyCancellable>()

    private var tabDidFinishLoadingPublisher = PassthroughSubject<Tab, Never>()

    private weak var tabCollectionViewModel: TabCollectionViewModel?

    init?(tabCollectionViewModel: TabCollectionViewModel) {
        guard let currentTab = tabCollectionViewModel.selectedTabViewModel?.tab else {
            return nil
        }

        self.tabCollectionViewModel = tabCollectionViewModel

        tabCollectionViewModel.$selectedTabViewModel
            .compactMap { $0 }
            .map(\.tab)
            .sink { [weak self] tab in
                self?.tabsSelectedOrReloadedInThisSession.insert(tab)
            }
            .store(in: &cancellables)

        subscribeToTabDidFinishNavigation(currentTab)

        tabDidFinishLoadingPublisher
            .prefix(Const.numberOfLazyLoadedTabs + 1)
            .sink(receiveCompletion: { _ in
                print("Lazy tab loading finished")
            }, receiveValue: { [weak self] tab in
                print("Tab did finish loading", String(reflecting: tab.content.url))
                self?.tabsSelectedOrReloadedInThisSession.insert(tab)
                self?.reloadRecentlySelectedTab()
            })
            .store(in: &cancellables)
    }

    private func reloadRecentlySelectedTab() {
        guard let tab = findRecentlySelectedTab() else {
            tabDidFinishLoadingPublisher.send(completion: .finished)
            return
        }
        subscribeToTabDidFinishNavigation(tab)
        print("Reloading", String(reflecting: tab.content.url))
        tab.reload()
//        Task {
//            let didRequestReload = await tab.reloadIfNeeded()
//            if !didRequestReload {
//                print("Tab cached, skipping reload", String(reflecting: tab.content.url))
//                tabDidFinishLoadingPublisher.send(tab)
//            } else {
//                print("Reloading tab", String(reflecting: tab.content.url))
//            }
//        }
    }

    private func findRecentlySelectedTab() -> Tab? {
        let tabs = tabCollectionViewModel?.tabCollection.tabs
            .filter { $0.lastSelectedAt != nil && $0.content.isUrl && !tabsSelectedOrReloadedInThisSession.contains($0) }
            .sorted { $0.lastSelectedAt! > $1.lastSelectedAt! }

        guard let tabs = tabs else {
            return nil
        }

//        print(tabs.prefix(3).map(\.content.url!))

        return tabs.first
    }

    private func subscribeToTabDidFinishNavigation(_ tab: Tab) {
        Publishers.Merge(tab.webViewDidFinishNavigationPublisher, tab.webViewDidFailNavigationPublisher)
            .prefix(1)
            .sink { [weak self] in
                self?.tabDidFinishLoadingPublisher.send(tab)
            }
            .store(in: &cancellables)
    }
}
