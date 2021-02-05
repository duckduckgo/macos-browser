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

class WindowControllersManager {

    static let shared = WindowControllersManager()

    private(set) var mainWindowControllers = [MainWindowController]()
    weak var lastKeyMainWindowController: MainWindowController?

    func register(_ windowController: MainWindowController) {
        mainWindowControllers.append(windowController)
    }

    func unregister(_ windowController: MainWindowController) {
        mainWindowControllers.removeAll(where: { $0 === windowController })
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
        guard let mainViewController = windowController.mainViewController,
              let selectedTabViewModel = mainViewController.tabCollectionViewModel.selectedTabViewModel else {
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
