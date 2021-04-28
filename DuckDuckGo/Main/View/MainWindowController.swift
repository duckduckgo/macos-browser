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

final class MainWindowController: NSWindowController {
    private static let windowFrameSaveName = "MainWindow"

    var mainViewController: MainViewController {
        // swiftlint:disable force_cast
        contentViewController as! MainViewController
        // swiftlint:enable force_cast
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

        guard let tabBarViewController = mainViewController.tabBarViewController else {
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
            .map { alphaValue in TabBarViewController.HorizontalSpace.leadingStackViewPadding.rawValue * alphaValue }
            .weakAssign(to: \.constant, on: tabBarViewController.leadingStackViewLeadingConstraint)
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
        mainViewController.windowDidBecomeMain()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        WindowControllersManager.shared.lastKeyMainWindowController = self
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        mainViewController.tabBarViewController.draggingSpace.isHidden = true
    }

    func windowWillExitFullScreen(_ notification: Notification) {
        mainViewController.tabBarViewController.draggingSpace.isHidden = false
    }

    func windowDidResignMain(_ notification: Notification) {
        mainViewController.windowDidResignMain()
    }

    func windowWillClose(_ notification: Notification) {
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
