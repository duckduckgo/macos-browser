//
//  FireCoordinator.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

final class FireCoordinator: NSObject {
    static let shared = FireCoordinator()
    private override init() {}

    var fireViewModel = FireViewModel()
    var firePopover: FirePopover?

    private weak var fireButton: NSButton?

    func fireButtonAction() {
        let burningWindow: NSWindow
        let waitForOpening: Bool

        if let lastKeyMainWindowController = WindowControllersManager.shared.lastKeyMainWindowController,
           let lastKeyWindow = lastKeyMainWindowController.window,
           lastKeyWindow.isVisible {
            burningWindow = lastKeyWindow
            burningWindow.makeKeyAndOrderFront(nil)
            lastKeyMainWindowController.mainViewController.navigationBarViewController.closeTransientPopovers()
            waitForOpening = false
        } else {
            burningWindow = WindowsManager.openNewWindow()!
            waitForOpening = true
        }

        guard let mainViewController = burningWindow.contentViewController as? MainViewController else {
            assertionFailure("Burning window or its content view controller is nil")
            return
        }

        if waitForOpening {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1/3) {
                self.showFirePopover(relativeTo: mainViewController.tabBarViewController.fireButton,
                                tabCollectionViewModel: mainViewController.tabCollectionViewModel)
            }
        } else {
            showFirePopover(relativeTo: mainViewController.tabBarViewController.fireButton,
                            tabCollectionViewModel: mainViewController.tabCollectionViewModel)
        }
    }

    func showFirePopover(relativeTo positioningView: NSButton, tabCollectionViewModel: TabCollectionViewModel) {
        if !(firePopover?.isShown ?? false) {
            self.fireButton = positioningView
            positioningView.state = .on

            firePopover = FirePopover(fireViewModel: fireViewModel, tabCollectionViewModel: tabCollectionViewModel)
            firePopover?.delegate = self
            firePopover?.show(relativeTo: positioningView.bounds.insetFromLineOfDeath(),
                             of: positioningView,
                             preferredEdge: .maxY)
        }
    }

}

extension FireCoordinator: NSPopoverDelegate {

    func popoverDidClose(_ notification: Notification) {
        self.fireButton?.state = .off
    }

}
