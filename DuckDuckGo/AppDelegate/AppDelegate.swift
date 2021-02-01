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
import Combine
import os.log

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    let urlEventListener = UrlEventListener()

    private let keyStore = EncryptionKeyStore()
    private var fileStore: FileStore!
    private var stateRestorationManager: StateRestorationManager!
    private var stateChangedObserver: AnyCancellable!

    func applicationWillFinishLaunching(_ notification: Notification) {
        do {
            let encryptionKey = isRunningTests ? nil : try keyStore.readKey()
            fileStore = FileStore(encryptionKey: encryptionKey)
        } catch {
            os_log("App Encryption Key could not be read: %s", "\(error)")
            fileStore = FileStore()
        }

        urlEventListener.listen()
        MainMenuManager.setupMainMenu()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Database.shared.loadStore()
        HTTPSUpgrade.shared.loadDataAsync()

        if !isRunningTests {
            setupStateRestoration()

            if WindowsManager.windows.isEmpty {
                WindowsManager.openNewWindow()
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        stateChangedObserver.cancel()
        stateRestorationManager.persistState(using: WindowControllersManager.shared.encodeState(with:), sync: true)

        return .terminateNow
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

    // MARK: - State Restoration

    func setupStateRestoration() {
        guard !isRunningTests else { return }

        // state restoration
        stateRestorationManager = StateRestorationManager(fileStore: fileStore, fileName: "persistentState")
        stateChangedObserver = WindowControllersManager.shared.stateChanged
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [unowned self] _ in
                self.stateDidChange()
            }

        do {
            try stateRestorationManager.restoreState(using: WindowsManager.restoreState(from:))
        } catch CocoaError.fileReadNoSuchFile {
            // ignore
        } catch {
            os_log("App state could not be decoded: %s", "\(error)")
        }
    }

    func stateDidChange() {
        stateRestorationManager.persistState(using: WindowControllersManager.shared.encodeState(with:))
    }

}
