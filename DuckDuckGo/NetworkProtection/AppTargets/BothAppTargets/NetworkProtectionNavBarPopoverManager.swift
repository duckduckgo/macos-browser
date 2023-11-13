//
//  NetworkProtectionNavBarPopoverModel.swift
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
import NetworkProtection
import NetworkProtectionIPC
import NetworkProtectionUI

#if NETWORK_PROTECTION
final class NetworkProtectionNavBarPopoverManager {
    private var networkProtectionPopover: NetworkProtectionPopover?
    let ipcClient: TunnelControllerIPCClient

    init(ipcClient: TunnelControllerIPCClient) {
        self.ipcClient = ipcClient
    }

    var isShown: Bool {
#if NETWORK_PROTECTION
        networkProtectionPopover?.isShown ?? false
#else
        return false
#endif
    }

    private func show(_ popover: NSPopover, positionedBelow view: NSView) {
        view.isHidden = false

        popover.show(positionedBelow: view.bounds.insetFromLineOfDeath(flipped: view.isFlipped), in: view)
    }

    func show(positionedBelow view: NSView, withDelegate delegate: NSPopoverDelegate) {

        let popover = networkProtectionPopover ?? {

            let controller = NetworkProtectionIPCTunnelController(ipcClient: ipcClient)

            let statusReporter = DefaultNetworkProtectionStatusReporter(
                statusObserver: ipcClient.connectionStatusObserver,
                serverInfoObserver: ipcClient.serverInfoObserver,
                connectionErrorObserver: ipcClient.connectionErrorObserver,
                connectivityIssuesObserver: ConnectivityIssueObserverThroughDistributedNotifications(),
                controllerErrorMessageObserver: ControllerErrorMesssageObserverThroughDistributedNotifications()
            )

            let menuItems = [
                NetworkProtectionStatusView.Model.MenuItem(name: UserText.networkProtectionNavBarStatusMenuVPNSettings, action: {
                    let appLauncher = AppLauncher(appBundleURL: Bundle.main.bundleURL)
                    await appLauncher.launchApp(withCommand: .showSettings)
                }),
                NetworkProtectionStatusView.Model.MenuItem(
                    name: UserText.networkProtectionNavBarStatusViewShareFeedback,
                    action: {
                        let appLauncher = AppLauncher(appBundleURL: Bundle.main.bundleURL)
                        await appLauncher.launchApp(withCommand: .shareFeedback)
                    })
            ]

            let onboardingStatusPublisher = UserDefaults.shared.networkProtectionOnboardingStatusPublisher

            let popover = NetworkProtectionPopover(controller: controller, onboardingStatusPublisher: onboardingStatusPublisher, statusReporter: statusReporter, menuItems: menuItems)
            popover.delegate = delegate

            networkProtectionPopover = popover
            return popover
        }()

        show(popover, positionedBelow: view)
    }

    func toggle(positionedBelow view: NSView, withDelegate delegate: NSPopoverDelegate) {
        if let networkProtectionPopover, networkProtectionPopover.isShown {
            networkProtectionPopover.close()
        } else {
            let featureVisibility = DefaultNetworkProtectionVisibility()

            if featureVisibility.isNetworkProtectionVisible() {
                show(positionedBelow: view, withDelegate: delegate)
            } else {
                featureVisibility.disableForWaitlistUsers()
            }
        }
    }

    func close() {
        networkProtectionPopover?.close()
    }
}
#endif
