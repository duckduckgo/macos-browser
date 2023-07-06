//
//  ScreenSharingModeCoordinator.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import Foundation

final class ScreenSharingModeCoordinator {

    internal init(windowControllerManager: WindowControllersManager, mainMenu: MainMenu) {
        self.windowControllerManager = windowControllerManager
        self.mainMenu = mainMenu
    }

    let windowControllerManager: WindowControllersManager
    let mainMenu: MainMenu

    private(set) var isActive: Bool = false {
        didSet {
            adjustMainMenu()
            Task {
                await adjustViews()
            }
        }
    }

    func switchMode() {
        isActive = !isActive
    }

    @MainActor
    private func adjustViews() {
        for windowController in windowControllerManager.mainWindowControllers {
            let rootView = windowController.mainViewController.view
            applyBlurToAllSubviews(of: rootView)
            if let titlebarView = windowController.titlebarView {
                applyBlurToAllSubviews(of: titlebarView)
            }
        }
    }

    private func applyBlurToAllSubviews(of view: NSView) {
        for subview in view.subviews {
            //TODO avoid if the tab is active
            if let tabBarViewItem = subview as? TabBarViewItem {
                if tabBarViewItem.isSelected {
                    continue
                }
            }
            if let blurringView = subview as? BlurringView {
                blurringView.shouldBlur = isActive
            }

            applyBlurToAllSubviews(of: subview) // Recurse into the subview's children
        }
    }

    private func adjustMainMenu() {
        mainMenu.screenSharingModeMenuItem.state = isActive ? .on : .off
    }

}
