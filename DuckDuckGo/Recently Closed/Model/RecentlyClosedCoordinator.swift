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

protocol RecentlyClosedCoordinating: AnyObject {

    var cache: [RecentlyClosedCacheItem] { get }

    func reopenItem(_ cacheItem: RecentlyClosedCacheItem?)
    func burnCache(domains: Set<String>?)

}

final class RecentlyClosedCoordinator: RecentlyClosedCoordinating {

    static let shared = RecentlyClosedCoordinator(windowControllerManager: WindowControllersManager.shared)

    var windowControllerManager: WindowControllersManagerProtocol

    init(windowControllerManager: WindowControllersManagerProtocol) {
        self.windowControllerManager = windowControllerManager

        guard !AppDelegate.isRunningTests else {
            return
        }
        subscribeToWindowControllersManager()
    }

    var canReopenRecentlyClosedTab: Bool {
        return !cache.isEmpty
    }

    // MARK: - Subscriptions

    private var mainVCDidRegisterCancellable: AnyCancellable?
    private var mainVCDidUnregisterCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    private func subscribeToWindowControllersManager() {
        subscribeToPinnedTabCollection(of: windowControllerManager.pinnedTabsManager)

        mainVCDidRegisterCancellable = windowControllerManager.didRegisterWindowController
            .sink(receiveValue: { [weak self] mainWindowController in
                self?.subscribeToTabCollection(of: mainWindowController)
            })
        mainVCDidUnregisterCancellable = windowControllerManager.didUnregisterWindowController
            .sink(receiveValue: { [weak self] mainWindowController in
                self?.cacheWindowContent(mainWindowController: mainWindowController)
            })
    }

    private func subscribeToPinnedTabCollection(of pinnedTabsManager: PinnedTabsManager) {
        let tabCollection = pinnedTabsManager.tabCollection
        tabCollection.didRemoveTabPublisher
            .sink { [weak self, weak tabCollection] (tab, index) in
                guard let tabCollection = tabCollection else {
                    return
                }
                self?.cacheTabContent(tab, of: tabCollection, at: .pinned(index))
            }
            .store(in: &cancellables)
    }

    private func subscribeToTabCollection(of mainWindowController: MainWindowController) {
        let tabCollection = mainWindowController.mainViewController.tabCollectionViewModel.tabCollection
        tabCollection.didRemoveTabPublisher
            .sink { [weak self, weak tabCollection] (tab, index) in
                guard let tabCollection = tabCollection else {
                    return
                }
                self?.cacheTabContent(tab, of: tabCollection, at: .unpinned(index))
            }
            .store(in: &cancellables)
    }

    // MARK: - Cache

    private(set) var cache = [RecentlyClosedCacheItem]()

    private func cacheTabContent(_ tab: Tab, of tabCollection: TabCollection, at tabIndex: TabIndex) {
        guard !tab.isContentEmpty else {
            // Don't cache empty tabs
            return
        }

        let cacheItem = RecentlyClosedTab(tab: tab, originalTabCollection: tabCollection, tabIndex: tabIndex)
        cache.append(cacheItem)
    }

    private func cacheWindowContent(mainWindowController: MainWindowController) {
        let tabCollection = mainWindowController.mainViewController.tabCollectionViewModel.tabCollection
        guard let first = tabCollection.tabs.first,
              (!first.isContentEmpty || tabCollection.tabs.count > 1) else {
            // Don't cache empty window
            return
        }

        let tabCacheItems = tabCollection.tabs.enumerated().map {
            RecentlyClosedTab(tab: $0.element, originalTabCollection: tabCollection, tabIndex: .unpinned($0.offset))
        }
        let droppingPoint = mainWindowController.window?.frame.origin
        let contentSize = mainWindowController.window?.frame.size
        let cacheItem = RecentlyClosedWindow(tabs: tabCacheItems, droppingPoint: droppingPoint, contentSize: contentSize)
        cache.append(cacheItem)
    }

    func reopenItem(_ cacheItem: RecentlyClosedCacheItem? = nil) {
        guard let cacheItem = cacheItem ?? cache.last else {
            assertionFailure("Can't reopen since the cache is empty")
            return
        }

        switch cacheItem {
        case let recentlyClosedTab as RecentlyClosedTab:
            reopenTab(recentlyClosedTab)
        case let recentlyClosedWindow as RecentlyClosedWindow:
            reopenWindow(recentlyClosedWindow)
        default:
            assertionFailure("Unknown type")
        }
    }

    private func reopenTab(_ recentlyClosedTab: RecentlyClosedTab) {
        defer {
            cache.removeAll(where: { $0 === recentlyClosedTab })
        }

        guard recentlyClosedTab.index.isUnpinnedTab else {
            reopenPinnedTab(recentlyClosedTab)
            return
        }

        let tabCollectionViewModel: TabCollectionViewModel
        let tabIndex: Int
        if let originalTabCollection = recentlyClosedTab.originalTabCollection,
           let lastKeyMainWindowController = WindowControllersManager.shared.lastKeyMainWindowController,
           originalTabCollection == lastKeyMainWindowController.mainViewController.tabCollectionViewModel.tabCollection {
            // Original window still exists and it is key
            tabCollectionViewModel = lastKeyMainWindowController.mainViewController.tabCollectionViewModel
            tabIndex = min(recentlyClosedTab.index.item, tabCollectionViewModel.tabCollection.tabs.count)

        } else if let lastKeyMainWindowController = WindowControllersManager.shared.lastKeyMainWindowController {
            // Original window is closed, reopen the tab in the current window
            tabCollectionViewModel = lastKeyMainWindowController.mainViewController.tabCollectionViewModel
            tabIndex = tabCollectionViewModel.tabCollection.tabs.count

        } else {
            // There is no window available, create a new one
            let tab = Tab(content: recentlyClosedTab.tabContent, shouldLoadInBackground: true)
            //TODO!
            WindowsManager.openNewWindow(with: tab, isDisposable: false)
            return
        }

        let tab = Tab(content: recentlyClosedTab.tabContent, shouldLoadInBackground: true)
        tabCollectionViewModel.insert(tab, at: .unpinned(tabIndex), selected: true)
    }

    private func reopenPinnedTab(_ recentlyClosedTab: RecentlyClosedTab) {
        var lastKeyMainWindowController = WindowControllersManager.shared.lastKeyMainWindowController
        if lastKeyMainWindowController == nil {
            // Create a new window if none exists
            //TODO!
            WindowsManager.openNewWindow(with: Tab(content: .homePage, shouldLoadInBackground: true), isDisposable: false)
            lastKeyMainWindowController = WindowControllersManager.shared.lastKeyMainWindowController
        }

        guard let tabCollectionViewModel = lastKeyMainWindowController?.mainViewController.tabCollectionViewModel else {
            return
        }

        let tab = Tab(content: recentlyClosedTab.tabContent, shouldLoadInBackground: true)
        let tabIndex = min(recentlyClosedTab.index.item, windowControllerManager.pinnedTabsManager.tabCollection.tabs.count)

        tabCollectionViewModel.insert(tab, at: .pinned(tabIndex), selected: true)
    }

    private func reopenWindow(_ recentlyClosedWindow: RecentlyClosedWindow) {
        let tabCollection = TabCollection()
        recentlyClosedWindow.tabs.forEach { recentlyClosedTab in
            let tab = Tab(content: recentlyClosedTab.tabContent, title: recentlyClosedTab.title, favicon: recentlyClosedTab.favicon, shouldLoadInBackground: false)
            tabCollection.append(tab: tab)
        }
        //TODO!
        WindowsManager.openNewWindow(with: tabCollection,
                                     isDisposable: false,
                                     droppingPoint: recentlyClosedWindow.droppingPoint,
                                     contentSize: recentlyClosedWindow.contentSize)
        cache.removeAll(where: { $0 === recentlyClosedWindow })
    }

    func burnCache(domains: Set<String>? = nil) {
        if let domains = domains {
            cache.removeAll { (cacheItem) in
                switch cacheItem {
                case let tab as RecentlyClosedTab:
                    return tab.contentContainsDomains(domains)
                case let window as RecentlyClosedWindow:
                    window.tabs.removeAll(where: { tab in
                        tab.contentContainsDomains(domains)
                    })
                    if window.tabs.isEmpty { return true }
                default:
                    assertionFailure("Unknown type")
                }

                return false
            }
        } else {
            cache.removeAll()
        }
    }

}

private extension RecentlyClosedTab {

    convenience init (tab: Tab, originalTabCollection: TabCollection, tabIndex: TabIndex) {
        self.init(tabContent: tab.content,
                  favicon: tab.favicon,
                  title: tab.title,
                  originalTabCollection: originalTabCollection,
                  index: tabIndex)
    }

    func contentContainsDomains(_ domains: Set<String>) -> Bool {
        if let host = tabContent.url?.host, domains.contains(host) {
            return true
        } else {
            return false
        }
    }

}

private extension Tab {

    var isContentEmpty: Bool {
        content == .none || content == .homePage
    }

}
