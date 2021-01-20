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

    private enum WindowButtonTrailingSpace {
        static let close: CGFloat = 12
        static let minimize: CGFloat = 32
        static let zoom: CGFloat = 52
    }

    private enum WindowButtonTopSpace {
        static let common: CGFloat = 27
    }

    private var isLoaded = false

    private var closeWidget: NSView?
    private var minimizeWidget: NSView?
    private var zoomWidget: NSView?

    var mainViewController: MainViewController {
        // swiftlint:disable force_cast
        contentViewController as! MainViewController
        // swiftlint:enable force_cast
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        isLoaded = true

        setupWindow()
        referenceWindowButtons()
        addWindowButtonsAsSubViewsIfNeeded()
    }

    private func setupWindow() {
        window?.setFrameAutosaveName("MainWindow")
        window?.isMovableByWindowBackground = true
        window?.hasShadow = true
    }

    private func resizeTitleBar() {
        guard let themeFrame = window?.contentView?.superview else {
            return
        }

        guard let titlebarContainerView = themeFrame.subviews.first(where: { $0.className == "NSTitlebarContainerView" }) else {
            return
        }

        titlebarContainerView.frame = NSRect(x: titlebarContainerView.frame.origin.x,
                                             y: titlebarContainerView.frame.origin.y,
                                             width: titlebarContainerView.frame.size.width,
                                             height: 0)
    }

    private var windowButtonsReferenced = false

    private func referenceWindowButtons() {
        guard let window = window,
              let contentView = window.contentView,
              let themeFrame = contentView.superview,
              let titlebarContainerView = themeFrame.subviews.first(where: { $0.className == "NSTitlebarContainerView" }),
              let titlebarView = titlebarContainerView.subviews.first(where: { $0.className == "NSTitlebarView" }),
              let closeWidget = titlebarView.subviews.first(where: { $0.className == "_NSThemeCloseWidget" }),
              let minimizeWidget = titlebarView.subviews.first(where: { $0.className == "_NSThemeWidget" }),
              let zoomWidget = titlebarView.subviews.first(where: { $0.className == "_NSThemeZoomWidget" }) else {
            os_log("MainWindowController: Failed to get references to window buttons", type: .error)
            return
        }

        self.closeWidget = closeWidget
        self.minimizeWidget = minimizeWidget
        self.zoomWidget = zoomWidget
        windowButtonsReferenced = true
    }

    private func addWindowButtonsAsSubViewsIfNeeded() {
        guard let window = window, let contentView = window.contentView else {
            os_log("MainWindowController: Window not available", type: .error)
            return
        }

        guard let closeWidget = closeWidget,
              let minimizeWidget = minimizeWidget,
              let zoomWidget = zoomWidget else {
            os_log("MainWindowController: Failed to get references to window buttons", type: .error)
            return
        }

        guard closeWidget.superview != window.contentView,
              minimizeWidget.superview != window.contentView,
              zoomWidget.superview != window.contentView else {
            layoutWindowButtons()
            return
        }

        closeWidget.removeFromSuperview()
        contentView.addSubview(closeWidget)

        minimizeWidget.removeFromSuperview()
        contentView.addSubview(minimizeWidget)

        zoomWidget.removeFromSuperview()
        contentView.addSubview(zoomWidget)

        layoutWindowButtons()
    }

    private func layoutWindowButtons() {
        guard isLoaded else { return }

        guard let contentView = window?.contentView,
              let closeWidget = closeWidget,
              let minimizeWidget = minimizeWidget,
              let zoomWidget = zoomWidget else {
            os_log("MainWindowController: No references to window buttons", type: .error)
            return
        }

        closeWidget.frame = NSRect(x: WindowButtonTrailingSpace.close,
                                   y: contentView.frame.size.height - WindowButtonTopSpace.common,
                                   width: closeWidget.frame.size.width,
                                   height: closeWidget.frame.size.height)

        minimizeWidget.frame = NSRect(x: WindowButtonTrailingSpace.minimize,
                                      y: contentView.frame.size.height - WindowButtonTopSpace.common,
                                      width: minimizeWidget.frame.size.width,
                                      height: minimizeWidget.frame.size.height)

        zoomWidget.frame = NSRect(x: WindowButtonTrailingSpace.zoom,
                                  y: contentView.frame.size.height - WindowButtonTopSpace.common,
                                  width: zoomWidget.frame.size.width,
                                  height: zoomWidget.frame.size.height)
    }

    override func showWindow(_ sender: Any?) {
        window!.makeKeyAndOrderFront(sender)
        WindowControllersManager.shared.register(self)
    }

}

extension MainWindowController: NSWindowDelegate {

    func windowDidResize(_ notification: Notification) {
        resizeTitleBar()
        if windowButtonsReferenced {
            layoutWindowButtons()
        }
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        resizeTitleBar()
        addWindowButtonsAsSubViewsIfNeeded()
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        addWindowButtonsAsSubViewsIfNeeded()
    }

    func windowDidMove(_ notification: Notification) {
        addWindowButtonsAsSubViewsIfNeeded()
    }

    func windowDidBecomeMain(_ notification: Notification) {
        mainViewController.windowDidBecomeMain()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        WindowControllersManager.shared.lastKeyMainWindowController = self

        addWindowButtonsAsSubViewsIfNeeded()
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
