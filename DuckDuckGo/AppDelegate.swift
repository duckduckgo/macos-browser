//
//  AppDelegate.swift
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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationWillFinishLaunching(_ notification: Notification) {
        listenUrlEvents()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            WindowsManager.openNewWindow()
            return true
        }
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let applicationDockMenu = ApplicationDockMenu()
        applicationDockMenu.dataSource = WindowControllersManager.shared
        applicationDockMenu.applicationDockMenuDelegate = WindowControllersManager.shared
        return applicationDockMenu
    }

}

// MARK: - URL Events

extension AppDelegate {

    private func listenUrlEvents() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleUrlEvent(event:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleUrlEvent(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let path = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue?.removingPercentEncoding,
              let url = URL(string: path) else {
            os_log("AppDelegate: URL initialization failed", type: .error)
            return
        }

        guard let windowController = WindowControllersManager.shared.lastKeyMainWindowController else {
            os_log("AppDelegate: No key window controller", type: .error)
            return
        }

        guard let mainViewController = windowController.mainViewController else {
            os_log("AppDelegate: No main view controller", type: .error)
            return
        }

        let tabCollectionViewModel = mainViewController.tabCollectionViewModel
        let tabCollection = tabCollectionViewModel.tabCollection

        if tabCollection.tabs.count == 1,
           let firstTab = tabCollection.tabs.first,
           firstTab.isHomepageLoaded {
            firstTab.url = url
        } else {
            let newTab = Tab()
            newTab.url = url
            tabCollectionViewModel.append(tab: newTab)
        }
    }

}
