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

@MainActor
final class FireCoordinator {

    static var fireViewModel = FireViewModel()

    static var firePopover: FirePopover?

    static func fireButtonAction() {
        let burningWindow: NSWindow
        let waitForOpening: Bool

        if let lastKeyWindow = WindowControllersManager.shared.lastKeyMainWindowController?.window,
           lastKeyWindow.isVisible {
            burningWindow = lastKeyWindow
            burningWindow.makeKeyAndOrderFront(nil)
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
                showFirePopover(relativeTo: mainViewController.tabBarViewController.fireButton,
                                tabCollectionViewModel: mainViewController.tabCollectionViewModel)
            }
        } else {
            showFirePopover(relativeTo: mainViewController.tabBarViewController.fireButton,
                            tabCollectionViewModel: mainViewController.tabCollectionViewModel)
        }
    }

    static func showFirePopover(relativeTo positioningView: NSView, tabCollectionViewModel: TabCollectionViewModel) {
        guard !(firePopover?.isShown ?? false) else {
            firePopover?.close()
            return
        }
        firePopover = FirePopover(fireViewModel: fireViewModel, tabCollectionViewModel: tabCollectionViewModel)
        firePopover?.show(positionedBelow: positioningView.bounds.insetBy(dx: 0, dy: 3), in: positioningView)
    }

}
