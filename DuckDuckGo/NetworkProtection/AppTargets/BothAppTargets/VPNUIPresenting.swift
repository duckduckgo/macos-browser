//
//  VPNUIPresenting.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

protocol VPNUIPresenting {
    @MainActor
    func showVPNAppExclusions()

    @MainActor
    func showVPNDomainExclusions()
}

extension WindowControllersManager: VPNUIPresenting {

    @MainActor
    func showVPNAppExclusions() {
        showPreferencesTab(withSelectedPane: .vpn)

        let windowController = ExcludedAppsViewController.create().wrappedInWindowController()

        guard let window = windowController.window,
              let parentWindowController = WindowControllersManager.shared.lastKeyMainWindowController
        else {
            assertionFailure("Failed to present ExcludedAppsViewController")
            return
        }

        parentWindowController.window?.beginSheet(window)
    }

    @MainActor
    func showVPNDomainExclusions() {
        showPreferencesTab(withSelectedPane: .vpn)

        let windowController = ExcludedDomainsViewController.create().wrappedInWindowController()

        guard let window = windowController.window,
              let parentWindowController = WindowControllersManager.shared.lastKeyMainWindowController
        else {
            assertionFailure("Failed to present ExcludedDomainsViewController")
            return
        }

        parentWindowController.window?.beginSheet(window)
    }
}
