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

    private var tabsSelectedInThisSession = [Tab]()
    private var cancellables = Set<AnyCancellable>()
    private weak var tabCollectionViewModel: TabCollectionViewModel?

    init?(tabCollectionViewModel: TabCollectionViewModel) {
//        var recentTabs = tabCollectionViewModel.tabCollection.tabs
//            .filter { $0.lastSelectedAt != nil && $0.content.isUrl }
//            .sorted { $0.lastSelectedAt! < $1.lastSelectedAt! }
//
//        guard recentTabs.count > 1 else {
//            return nil
//        }
//        currentTab = recentTabs.removeFirst()
//        tabs = Array(recentTabs.prefix(3))

        guard let currentTab = tabCollectionViewModel.selectedTabViewModel?.tab else {
            return nil
        }

        self.tabCollectionViewModel = tabCollectionViewModel

//        tabCollectionViewModel.selectedTabViewModel

        let currentTabDidFinishLoading = currentTab.webViewDidFinishNavigationPublisher.prefix(1)

        currentTabDidFinishLoading
            .sink { [weak self] in
                print("Current tab did finish loading")
                self?.reloadRecentTabs()
            }
            .store(in: &cancellables)
    }

    private func reloadRecentTabs() {
        let recentTabs = tabCollectionViewModel?.tabCollection.tabs
            .filter { $0.lastSelectedAt != nil && $0.content.isUrl }
            .sorted { $0.lastSelectedAt! > $1.lastSelectedAt! }

        guard let tabs = recentTabs, tabs.count > 1 else {
            return
        }

        tabs.dropFirst().prefix(3).forEach { tab in
            print(String(describing: tab.content.url))
            tab.reload()
        }
    }

}
