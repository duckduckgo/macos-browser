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
import DependencyInjection

#if swift(>=5.9)
@Injectable
#endif
@MainActor
final class FireCoordinator: Injectable {

    let dependencies: DependencyStorage

    @Injected
    var windowManager: WindowManagerProtocol

    @Injected
    var fireViewModel: FireViewModel

    typealias InjectedDependencies = FirePopover.Dependencies

    private var firePopover: FirePopover?

    init(dependencyProvider: DependencyProvider) {
        self.dependencies = .init(dependencyProvider)
    }

    func fireButtonAction() {
        let burningWindow: NSWindow
        let waitForOpening: Bool

        if let lastKeyWindow = windowManager.lastKeyMainWindowController?.window,
           lastKeyWindow.isVisible {
            burningWindow = lastKeyWindow
            burningWindow.makeKeyAndOrderFront(nil)
            waitForOpening = false
        } else {
            burningWindow = windowManager.openNewWindow(isBurner: false)!
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

    func showFirePopover(relativeTo positioningView: NSView, tabCollectionViewModel: TabCollectionViewModel) {
        if !(firePopover?.isShown ?? false) {
            firePopover = FirePopover(tabCollectionViewModel: tabCollectionViewModel, dependencyProvider: dependencies)
            firePopover?.showBelow(positioningView)
        }
    }

}
