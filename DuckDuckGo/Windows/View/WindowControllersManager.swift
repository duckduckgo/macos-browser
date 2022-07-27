//
//  WindowControllersManager.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import Cocoa
import os.log
import Combine

protocol WindowControllersManagerProtocol {

    var pinnedTabsManager: PinnedTabsManager { get }

    var didRegisterWindowController: PassthroughSubject<(MainWindowController), Never> { get }
    var didUnregisterWindowController: PassthroughSubject<(MainWindowController), Never> { get }

    func register(_ windowController: MainWindowController)
    func unregister(_ windowController: MainWindowController)

}

final class WindowControllersManager: WindowControllersManagerProtocol {

    static let shared = WindowControllersManager()

    /**
     * _Initial_ meaning a single window with a single home page tab.
     */
    @Published private(set) var isInInitialState: Bool = true
    @Published private(set) var mainWindowControllers = [MainWindowController]()
    private(set) var pinnedTabsManager = PinnedTabsManager()

    weak var lastKeyMainWindowController: MainWindowController? {
        didSet {
            if lastKeyMainWindowController != oldValue {
                didChangeKeyWindowController.send(())
            }
        }
    }

    let didChangeKeyWindowController = PassthroughSubject<Void, Never>()
    let didRegisterWindowController = PassthroughSubject<(MainWindowController), Never>()
    let didUnregisterWindowController = PassthroughSubject<(MainWindowController), Never>()

    func register(_ windowController: MainWindowController) {
        guard !mainWindowControllers.contains(windowController) else {
            assertionFailure("Window controller already registered")
            return
        }

        mainWindowControllers.append(windowController)
        didRegisterWindowController.send(windowController)
    }

    func unregister(_ windowController: MainWindowController) {
        guard let idx = mainWindowControllers.firstIndex(of: windowController) else {
            os_log("WindowControllersManager: Window Controller not registered", type: .error)
            return
        }
        mainWindowControllers.remove(at: idx)
        didUnregisterWindowController.send(windowController)
    }

    func updateIsInInitialState() {
        if isInInitialState {

            isInInitialState = mainWindowControllers.isEmpty ||
            (
                mainWindowControllers.count == 1 &&
                mainWindowControllers.first?.mainViewController.tabCollectionViewModel.tabs.count == 1 &&
                mainWindowControllers.first?.mainViewController.tabCollectionViewModel.tabs.first?.content == .homePage &&
                pinnedTabsManager.tabCollection.tabs.isEmpty
            )
        }
    }

}

// MARK: - Opening a url from the external event

extension WindowControllersManager {

    func showBookmarksTab() {
        showTab(with: .bookmarks)
    }

    func showPreferencesTab(withSelectedPane pane: PreferencePaneIdentifier? = nil) {
        showTab(with: .preferences(pane: pane))
    }

    /// Opens a bookmark in a tab, respecting the current modifier keys when deciding where to open the bookmark's URL.
    func open(bookmark: Bookmark) {
        if NSApplication.shared.isCommandPressed && NSApplication.shared.isShiftPressed {
            WindowsManager.openNewWindow(with: bookmark.url)
        } else if NSApplication.shared.isCommandPressed {
            show(url: bookmark.url, newTab: true)
        } else {
            show(url: bookmark.url)
        }
    }
    
    func show(url: URL?, newTab: Bool = false) {

        func show(url: URL?, in windowController: MainWindowController) {
            let viewController = windowController.mainViewController
            windowController.window?.makeKeyAndOrderFront(self)

            let tabCollectionViewModel = viewController.tabCollectionViewModel
            let tabCollection = tabCollectionViewModel.tabCollection

            if tabCollection.tabs.count == 1,
               let firstTab = tabCollection.tabs.first,
               case .homePage = firstTab.content,
               !newTab {
                firstTab.setContent(url.map { .url($0) } ?? .homePage)
            } else if let tab = tabCollectionViewModel.selectedTabViewModel?.tab, !newTab {
                tab.setContent(url.map { .url($0) } ?? .homePage)
            } else {
                let newTab = Tab(content: url.map { .url($0) } ?? .homePage)
                newTab.setContent(url.map { .url($0) } ?? .homePage)
                tabCollectionViewModel.append(tab: newTab)
            }
        }

        // If there is a main window, open the URL in it
        if let windowController = mainWindowControllers.first(where: { $0.window?.isMainWindow == true && $0.window?.isPopUpWindow == false })
            // If a last key window is available, open the URL in it
            ?? lastKeyMainWindowController
            // If there is any open window on the current screen, open the URL in it
            ?? mainWindowControllers.first(where: { $0.window?.screen == NSScreen.main && $0.window?.isPopUpWindow == false })
            // If there is any window available, open the URL in it
            ?? { mainWindowControllers.first?.window?.isPopUpWindow == false ? mainWindowControllers.first : nil }() {

            show(url: url, in: windowController)
            return
        }

        // Open a new window
        if let url = url {
            WindowsManager.openNewWindow(with: url)
        } else {
            WindowsManager.openNewWindow()
        }
    }

    func showTab(with content: Tab.TabContent) {
        guard let windowController = mainWindowControllers.first(where: {
            let isMain = $0.window?.isMainWindow ?? false
            let hasMainChildWindow = $0.window?.childWindows?.contains { $0.isMainWindow } ?? false

            return $0.window?.isPopUpWindow == false && (isMain || hasMainChildWindow)
        }) else { return }

        let viewController = windowController.mainViewController
        let tabCollectionViewModel = viewController.tabCollectionViewModel
        tabCollectionViewModel.appendNewTab(with: content)
        windowController.window?.orderFront(nil)
    }

}

// MARK: - ApplicationDockMenu

extension WindowControllersManager: ApplicationDockMenuDataSource {

    func numberOfWindowMenuItems(in applicationDockMenu: ApplicationDockMenu) -> Int {
        return mainWindowControllers.count
    }

    func applicationDockMenu(_ applicationDockMenu: ApplicationDockMenu, windowTitleFor windowMenuItemIndex: Int) -> String {
        guard windowMenuItemIndex >= 0, windowMenuItemIndex < mainWindowControllers.count else {
            os_log("WindowControllersManager: Index out of bounds", type: .error)
            return "-"
        }

        let windowController = mainWindowControllers[windowMenuItemIndex]
        let mainViewController = windowController.mainViewController
        guard let selectedTabViewModel = mainViewController.tabCollectionViewModel.selectedTabViewModel else {
            os_log("WindowControllersManager: Cannot get selected tab view model", type: .error)
            return "-"
        }

        return selectedTabViewModel.title
    }

    func indexOfSelectedWindowMenuItem(in applicationDockMenu: ApplicationDockMenu) -> Int? {
        guard let lastKeyMainWindowController = lastKeyMainWindowController else {
            os_log("WindowControllersManager: Last key main window controller property is nil", type: .error)
            return nil
        }

        return mainWindowControllers.firstIndex(of: lastKeyMainWindowController)
    }

}

extension WindowControllersManager: ApplicationDockMenuDelegate {

    func applicationDockMenu(_ applicationDockMenu: ApplicationDockMenu, selectWindowWith index: Int) {
        guard index >= 0, index < mainWindowControllers.count else {
            os_log("WindowControllersManager: Index out of bounds", type: .error)
            return
        }

        let windowController = mainWindowControllers[index]

        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }
        windowController.window?.makeKeyAndOrderFront(self)
    }

}
