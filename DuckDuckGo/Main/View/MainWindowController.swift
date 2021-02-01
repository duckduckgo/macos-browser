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

final class MainWindowController: NSWindowController {
    private static let windowFrameSaveName = "MainWindow"

    var mainViewController: MainViewController? {
        contentViewController as? MainViewController
    }

    required init?(coder: NSCoder) {
        fatalError("MainWindowController: Bad initializer")
    }

    init(tabCollectionViewModel: TabCollectionViewModel? = nil) {
        let mainViewController = NSStoryboard.main.instantiateController(identifier: .mainViewController) { coder in
            MainViewController(coder: coder, tabCollectionViewModel: tabCollectionViewModel)!
        }

        let window = MainWindow()
        window.contentViewController = mainViewController

        super.init(window: window)

        setupWindow()
    }

    private func setupWindow() {
        window!.delegate = self
        window!.setFrameAutosaveName(Self.windowFrameSaveName)
    }

    override func showWindow(_ sender: Any?) {
        window!.makeKeyAndOrderFront(sender)
        WindowControllersManager.shared.register(self)
    }

}

extension MainWindowController: NSWindowDelegate {

    func windowDidResize(_ notification: Notification) {
    }

    func windowDidMove(_ notification: Notification) {
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

    func windowWillClose(_ notification: Notification) {
        guard let mainViewController = contentViewController as? MainViewController else {
            os_log("MainWindowController: Failed to get reference to main view controller", type: .error)
            return
        }

        mainViewController.windowWillClose()

        // Unregistering triggers deinitialization of this object.
        // Because it's also the delegate, deinit within this method caused crash
        DispatchQueue.main.async {
            WindowControllersManager.shared.unregister(self)
        }
    }

}

fileprivate extension NSStoryboard.SceneIdentifier {
    static let mainViewController = NSStoryboard.SceneIdentifier("mainViewController")
}
