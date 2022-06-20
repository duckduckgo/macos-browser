//
//  RecentlyClosedCoordinator.swift
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
import os.log

protocol RecentlyClosedCoordinatorProtocol: AnyObject {

    var cache: [RecentlyClosedCacheItem] { get }

    func reopenTab(cacheIndex: Int?)
    func burnCache(domains: Set<String>?)

}

final class RecentlyClosedCoordinator: RecentlyClosedCoordinatorProtocol {

    static let shared = RecentlyClosedCoordinator(windowControllerManager: WindowControllersManager.shared)

    var windowControllerManager: WindowControllersManagerProtocol

    init(windowControllerManager: WindowControllersManagerProtocol) {
        self.windowControllerManager = windowControllerManager

        subscribeToWindowControllersManager()
    }

    var canReopenRecentlyClosedTab: Bool {
        return !cache.isEmpty
    }

    // MARK: - Subscribtions to events

    private var mainVCDidRegisterCancellable: AnyCancellable?
    private var mainVCDidUnregisterCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    private func subscribeToWindowControllersManager() {
        mainVCDidRegisterCancellable = WindowControllersManager.shared.didRegisterWindowController
            .sink(receiveValue: { [weak self] mainWindowController in
                self?.subscribeToTabCollection(of: mainWindowController)
            })
        mainVCDidUnregisterCancellable = WindowControllersManager.shared.didUnregisterWindowController
            .sink(receiveValue: { [weak self] mainWindowController in
                self?.cacheTabCollectionContent(mainWindowController.mainViewController.tabCollectionViewModel.tabCollection)
            })
    }

    private func subscribeToTabCollection(of mainWindowController: MainWindowController) {
        mainWindowController.mainViewController.tabCollectionViewModel.tabCollection.didRemoveTabPublisher
            .sink { [weak self] (tab, index) in
                self?.cacheTabContent(tab, at: index)
            }
            .store(in: &cancellables)
    }

    // MARK: - Cache

    private(set) var cache = [RecentlyClosedCacheItem]()

    private func cacheTabContent(_ tab: Tab, at tabIndex: Int) {
        guard tab.content != .none, tab.content != .homePage else {
            // We don't cache empty tabs
            return
        }

        let cacheItem = RecentlyClosedCacheItem(tab: tab, tabIndex: tabIndex)
        cache.append(cacheItem)
    }

    private func cacheTabCollectionContent(_ tabCollection: TabCollection) {
        tabCollection.tabs.enumerated().forEach { (index, tab) in
            cacheTabContent(tab, at: index)
        }
    }

    func reopenTab(cacheIndex: Int? = nil) {
        let cacheIndex = cacheIndex ?? (cache.count - 1)
        guard let cacheItem = cache[safe: cacheIndex] else {
            os_log("RecentlyClosedCoordinator: No tab removed yet", type: .error)
            return
        }

        let tabCollectionViewModel: TabCollectionViewModel
        let tabIndex: Int
        if let originalTabCollection = cacheItem.originalTabCollection,
           let lastKeyMainWindowController = WindowControllersManager.shared.lastKeyMainWindowController,
           originalTabCollection == lastKeyMainWindowController.mainViewController.tabCollectionViewModel.tabCollection {
            // Original window still exists and it is key
            tabCollectionViewModel = lastKeyMainWindowController.mainViewController.tabCollectionViewModel
            tabIndex = min(cacheItem.index, tabCollectionViewModel.tabCollection.tabs.count)

        } else if let lastKeyMainWindowController = WindowControllersManager.shared.lastKeyMainWindowController {
            // Original window is closed, reopen the tab in the current window
            tabCollectionViewModel = lastKeyMainWindowController.mainViewController.tabCollectionViewModel
            tabIndex = tabCollectionViewModel.tabCollection.tabs.count

        } else {
            // There is no window available, create a new one
            let tab = Tab(content: cacheItem.tabContent)
            WindowsManager.openNewWindow(with: tab)
            return
        }

        let tab = Tab(content: cacheItem.tabContent)
        tabCollectionViewModel.insert(tab: tab, at: tabIndex, selected: true)
        cache.remove(at: cacheIndex)
    }

    func burnCache(domains: Set<String>? = nil) {
        if let domains = domains {
            cache.removeAll { (cacheItem) in
                if let host = cacheItem.tabContent.url?.host, domains.contains(host) {
                    return true
                }
                return false
            }
        } else {
            cache.removeAll()
        }
    }

}

private extension RecentlyClosedCacheItem {

    init (tab: Tab, tabIndex: Int) {
        tabContent = tab.content
        favicon = tab.favicon
        title = tab.title
        index = tabIndex
    }

}
