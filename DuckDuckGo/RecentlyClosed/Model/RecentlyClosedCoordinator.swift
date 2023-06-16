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

import AppKit
import Foundation
import Combine
import DependencyInjection

@MainActor
protocol RecentlyClosedCoordinating: AnyObject {

    var cache: [RecentlyClosedCacheItem] { get }

    func reopenItem(_ cacheItem: RecentlyClosedCacheItem?)
    func burnCache(domains: Set<String>?)

}

#if swift(>=5.9)
@Injectable
#endif
@MainActor
final class RecentlyClosedCoordinator: RecentlyClosedCoordinating, Injectable {

    let dependencies: DependencyStorage

    @Injected
    var windowManager: WindowManagerProtocol

    @Injected
    var pinnedTabsManager: PinnedTabsManager

    typealias InjectedDependencies = Tab.Dependencies

    init(dependencyProvider: DependencyProvider) {
        self.dependencies = .init(dependencyProvider)

        guard !NSApp.isRunningUnitTests else {
            return
        }
        subscribeToWindowManager()
    }

    var canReopenRecentlyClosedTab: Bool {
        return !cache.isEmpty
    }

    // MARK: - Subscriptions

    private var mainVCDidRegisterCancellable: AnyCancellable?
    private var mainVCDidUnregisterCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    private func subscribeToWindowManager() {
        subscribeToPinnedTabCollection(of: pinnedTabsManager)

        mainVCDidRegisterCancellable = windowManager.didRegisterWindowController
            .sink(receiveValue: { [weak self] mainWindowController in
                self?.subscribeToTabCollection(of: mainWindowController)
            })
        mainVCDidUnregisterCancellable = windowManager.didUnregisterWindowController
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
        guard !tab.isContentEmpty, !tab.isBurner else {
            // Don't cache empty tabs and burner tabs
            return
        }

        let cacheItem = RecentlyClosedTab(tab: tab, originalTabCollection: tabCollection, tabIndex: tabIndex)
        cache.append(cacheItem)
    }

    private func cacheWindowContent(mainWindowController: MainWindowController) {
        let tabCollection = mainWindowController.mainViewController.tabCollectionViewModel.tabCollection
        guard let first = tabCollection.tabs.first,
              (!first.isContentEmpty || tabCollection.tabs.count > 1),
              !mainWindowController.mainViewController.tabCollectionViewModel.isBurner else {
            // Don't cache empty window and burner windows
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
           let lastKeyMainWindowController = windowManager.lastKeyMainWindowController,
           originalTabCollection == lastKeyMainWindowController.mainViewController.tabCollectionViewModel.tabCollection {
            // Original window still exists and it is key
            tabCollectionViewModel = lastKeyMainWindowController.mainViewController.tabCollectionViewModel
            tabIndex = min(recentlyClosedTab.index.item, tabCollectionViewModel.tabCollection.tabs.count)

        } else if let lastKeyMainWindowController = windowManager.lastKeyMainWindowController {
            // Original window is closed, reopen the tab in the current window
            tabCollectionViewModel = lastKeyMainWindowController.mainViewController.tabCollectionViewModel
            tabIndex = tabCollectionViewModel.tabCollection.tabs.count

        } else {
            // There is no window available, create a new one
            let tab = Tab(dependencyProvider: dependencies, content: recentlyClosedTab.tabContent, interactionStateData: recentlyClosedTab.interactionData, shouldLoadInBackground: true, isBurner: false, shouldLoadFromCache: true)
        windowManager.openNewWindow(with: tab, isBurner: false)
            return
        }

        let tab = Tab(dependencyProvider: dependencies, content: recentlyClosedTab.tabContent, interactionStateData: recentlyClosedTab.interactionData, shouldLoadInBackground: true, isBurner: false, shouldLoadFromCache: true)
        tabCollectionViewModel.insert(tab, at: .unpinned(tabIndex), selected: true)
    }

    private func reopenPinnedTab(_ recentlyClosedTab: RecentlyClosedTab) {
        var lastKeyMainWindowController = windowManager.lastKeyMainWindowController
        if lastKeyMainWindowController == nil {
            // Create a new window if none exists
            windowManager.openNewWindow(with: Tab(dependencyProvider: dependencies, content: .homePage, shouldLoadInBackground: true, isBurner: false, shouldLoadFromCache: true), isBurner: false)
            lastKeyMainWindowController = windowManager.lastKeyMainWindowController
        }

        guard let tabCollectionViewModel = lastKeyMainWindowController?.mainViewController.tabCollectionViewModel else {
            return
        }

        let tab = Tab(dependencyProvider: dependencies, content: recentlyClosedTab.tabContent, interactionStateData: recentlyClosedTab.interactionData, shouldLoadInBackground: true, isBurner: tabCollectionViewModel.isBurner, shouldLoadFromCache: true)
        let tabIndex = min(recentlyClosedTab.index.item, pinnedTabsManager.tabCollection.tabs.count)

        tabCollectionViewModel.insert(tab, at: .pinned(tabIndex), selected: true)
    }

    private func reopenWindow(_ recentlyClosedWindow: RecentlyClosedWindow) {
        let tabCollection = TabCollection()
        recentlyClosedWindow.tabs.forEach { recentlyClosedTab in
            let tab = Tab(
                dependencyProvider: dependencies,
                content: recentlyClosedTab.tabContent,
                title: recentlyClosedTab.title,
                favicon: recentlyClosedTab.favicon,
                interactionStateData: recentlyClosedTab.interactionData,
                shouldLoadInBackground: false,
                isBurner: false,
                shouldLoadFromCache: true
            )
            tabCollection.append(tab: tab)
        }
        windowManager.openNewWindow(with: tabCollection,
                                    isBurner: false,
                                    droppingPoint: recentlyClosedWindow.droppingPoint,
                                    contentSize: recentlyClosedWindow.contentSize)
        cache.removeAll(where: { $0 === recentlyClosedWindow })
    }

    func burnCache(domains: Set<String>? = nil) {
        if let domains = domains {
            cache.burn(for: domains)
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
                  interactionData: tab.getActualInteractionStateData(),
                  originalTabCollection: originalTabCollection,
                  index: tabIndex)
    }
}

private extension Tab {

    var isContentEmpty: Bool {
        content == .none || content == .homePage
    }
}
