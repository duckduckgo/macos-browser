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
import Combine

class MainWindowController: NSWindowController {
    private static let windowFrameSaveName = "MainWindow"

    var mainViewController: MainViewController? {
        contentViewController as? MainViewController
    }

    init(mainViewController: MainViewController) {
        let window = MainWindow(frame: NSRect(x: 0, y: 0, width: 1024, height: 790))
        window.contentViewController = mainViewController

        super.init(window: window)

        setupWindow()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupWindow() {
        window?.delegate = self
        window?.setFrameAutosaveName(Self.windowFrameSaveName)

        setupToolbar()
    }

    var trafficLightsAlphaCancellable: AnyCancellable?
    private func setupToolbar() {
        // Empty toolbar ensures that window buttons are centered vertically
        window?.toolbar = NSToolbar()
        window?.toolbar?.showsBaselineSeparator = true

        guard let tabBarViewController = mainViewController?.tabBarViewController else {
            assertionFailure("MainWindowController: tabBarViewController is nil" )
            return
        }

        guard let titlebarView = window?.standardWindowButton(.closeButton)?.superview else { return }

        tabBarViewController.view.removeFromSuperview()
        titlebarView.addSubview(tabBarViewController.view)

        tabBarViewController.view.frame = titlebarView.bounds
        tabBarViewController.view.translatesAutoresizingMaskIntoConstraints = false
        let constraints = tabBarViewController.view.addConstraints(to: titlebarView, [
            .leading: .leading(),
            .trailing: .trailing(),
            .top: .top(),
            .height: .const(38.0)
        ])
        NSLayoutConstraint.activate(constraints)

        // slide tabs to the left in full screen
        trafficLightsAlphaCancellable = window?.standardWindowButton(.closeButton)?
            .publisher(for: \.alphaValue)
            .map { alphaValue in 80.0 * alphaValue }
            .weakAssign(to: \.constant, on: tabBarViewController.scrollViewLeadingConstraint)

    }

    override func showWindow(_ sender: Any?) {
        window!.makeKeyAndOrderFront(sender)
        WindowControllersManager.shared.register(self)
    }

}

extension MainWindowController: NSWindowDelegate {

    func window(_ window: NSWindow,
                willUseFullScreenPresentationOptions: NSApplication.PresentationOptions) -> NSApplication.PresentationOptions {
        return [.fullScreen, .autoHideMenuBar]
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
