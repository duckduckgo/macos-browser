//
//  TabsSearchService.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

private typealias TabNavEventChange = Publishers.NestedObjectChanges<
    AnyPublisher<NavigationEvent, Never>,
    Published<[Tab]>.Publisher>.Change
private typealias WindowControllerTabLoadedChange = Publishers.NestedObjectChanges<
    AnyPublisher<TabNavEventChange, Never>,
    Published<[MainWindowController]>.Publisher>.Change
private extension TabCollectionViewModel {
    var tabNavigationEvents: AnyPublisher<TabNavEventChange, Never> {
        return tabCollection.$tabs.nestedObjectChanges(\.navigationEvents).eraseToAnyPublisher()
    }
}
private extension WindowControllersManager {
    var pageLoadedPublisher: AnyPublisher<WindowControllerTabLoadedChange, Never> {
        $mainWindowControllers.nestedObjectChanges(\.mainViewController!.tabCollectionViewModel.tabNavigationEvents)
            .eraseToAnyPublisher()
    }
}

final class TabsSearchService {
    static let shared = TabsSearchService()

    var c: AnyCancellable?

    var tabViewModels = [TabId: TabViewModel]()

    init() {
        c = WindowControllersManager.shared.pageLoadedPublisher.sink { [weak self] in
            guard let self = self else { return }
            switch $0 {
            case .composition(added: let added, removed: let removed):
                added.forEach(self.added(controller:))
                removed.forEach(self.removed(controller:))

            case .value(owner: let controller, value: let value):
                switch value {
                case .composition(added: let added, removed: let removed):
                    self.added(added, in: controller)
                    self.removed(removed)

                case .value(owner: let tab, value: .pageFinishedLoading):
                    self.tabDidFinishLoading(tab)

                case .value:
                    break
                }
            }
        }
    }

    func added(controller: MainWindowController) {
        let tabs = controller.mainViewController!.tabCollectionViewModel.tabCollection.tabs
        self.added(Set(tabs), in: controller)
    }

    func added(_ tabs: Set<Tab>, in controller: MainWindowController) {
        let tabCollectionViewModel = controller.mainViewController!.tabCollectionViewModel
        for tab in tabs {
            self.tabViewModels[tab.id] = tabCollectionViewModel.tabViewModel(for: tab)
        }
    }

    func removed(controller: MainWindowController) {
        let tabs = controller.mainViewController!.tabCollectionViewModel.tabCollection.tabs
        self.removed(Set(tabs))
    }

    func removed(_ tabs: Set<Tab>) {
        for tab in tabs {
            self.tabViewModels[tab.id] = nil
        }
    }

    func tabDidFinishLoading(_ tab: Tab) {

    }

}
