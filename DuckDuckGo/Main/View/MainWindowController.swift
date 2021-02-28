//
//  MainWindowController.swift
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

class MainWindowController: NSWindowController {

    var mainViewController: MainViewController? {
        contentViewController as? MainViewController
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        setupWindow()
    }

    private func setupWindow() {
        window?.setFrameAutosaveName("MainWindow")
        window?.hasShadow = true
        window?.titleVisibility = .hidden
        window?.titlebarAppearsTransparent = true
        window?.isMovable = false

        setupEmptyToolbar()
    }

    private func setupEmptyToolbar() {
        // Empty toolbar ensures that window buttons are centered vertically
        window?.toolbar = NSToolbar()
        window?.toolbar?.showsBaselineSeparator = false
    }

    private func clearEmptyToolbar() {
        // Empty toolbar makes problems in full screen mode
        window?.toolbar = nil
    }

    override func showWindow(_ sender: Any?) {
        window!.makeKeyAndOrderFront(sender)
        WindowControllersManager.shared.register(self)
    }

}

extension MainWindowController: NSWindowDelegate {

    func windowWillEnterFullScreen(_ notification: Notification) {
        clearEmptyToolbar()
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        setupEmptyToolbar()
    }

    func windowDidBecomeMain(_ notification: Notification) {
        guard let mainViewController = contentViewController as? MainViewController else {
            os_log("MainWindowController: Failed to get reference to main view controller", type: .error)
            return
        }

        mainViewController.windowDidBecomeMain()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        WindowControllersManager.shared.lastKeyMainWindowController = self
    }

    func windowDidResignMain(_ notification: Notification) {
        mainViewController?.windowDidResignMain()
    }

    func windowWillClose(_ notification: Notification) {
        guard let mainViewController = contentViewController as? MainViewController else {
            os_log("MainWindowController: Failed to get reference to main view controller", type: .error)
            return
        }

        mainViewController.windowWillClose()

        window?.resignKey()
        window?.resignMain()

        // Unregistering triggers deinitialization of this object.
        // Because it's also the delegate, deinit within this method caused crash
        DispatchQueue.main.async {
            WindowControllersManager.shared.unregister(self)
        }
    }

}
