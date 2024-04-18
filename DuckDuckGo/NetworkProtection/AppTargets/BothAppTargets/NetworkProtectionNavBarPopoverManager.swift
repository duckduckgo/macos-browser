//
//  NetworkProtectionNavBarPopoverManager.swift
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

import AppKit
import Combine
import Foundation
import LoginItems
import NetworkProtection
import NetworkProtectionIPC
import NetworkProtectionUI
import Subscription

protocol NetworkProtectionIPCClient {
    var ipcStatusObserver: ConnectionStatusObserver { get }
    var ipcServerInfoObserver: ConnectionServerInfoObserver { get }
    var ipcConnectionErrorObserver: ConnectionErrorObserver { get }

    func start(completion: @escaping (Error?) -> Void)
    func stop(completion: @escaping (Error?) -> Void)
}

extension TunnelControllerIPCClient: NetworkProtectionIPCClient {
    public var ipcStatusObserver: any NetworkProtection.ConnectionStatusObserver { connectionStatusObserver }
    public var ipcServerInfoObserver: any NetworkProtection.ConnectionServerInfoObserver { serverInfoObserver }
    public var ipcConnectionErrorObserver: any NetworkProtection.ConnectionErrorObserver { connectionErrorObserver }
}

final class NetworkProtectionNavBarPopoverManager: NetPPopoverManager {
    private var networkProtectionPopover: NetworkProtectionPopover?
    let ipcClient: NetworkProtectionIPCClient
    let networkProtectionFeatureDisabler: NetworkProtectionFeatureDisabling

    init(ipcClient: TunnelControllerIPCClient,
         networkProtectionFeatureDisabler: NetworkProtectionFeatureDisabling) {
        self.ipcClient = ipcClient
        self.networkProtectionFeatureDisabler = networkProtectionFeatureDisabler
    }

    var isShown: Bool {
        networkProtectionPopover?.isShown ?? false
    }

    // swiftlint:disable:next function_body_length
    func show(positionedBelow view: NSView, withDelegate delegate: NSPopoverDelegate) {
        let popover = networkProtectionPopover ?? {

            let controller = NetworkProtectionIPCTunnelController(ipcClient: ipcClient)

            let statusReporter = DefaultNetworkProtectionStatusReporter(
                statusObserver: ipcClient.ipcStatusObserver,
                serverInfoObserver: ipcClient.ipcServerInfoObserver,
                connectionErrorObserver: ipcClient.ipcConnectionErrorObserver,
                connectivityIssuesObserver: ConnectivityIssueObserverThroughDistributedNotifications(),
                controllerErrorMessageObserver: ControllerErrorMesssageObserverThroughDistributedNotifications()
            )

            let onboardingStatusPublisher = UserDefaults.netP.networkProtectionOnboardingStatusPublisher
            _ = VPNSettings(defaults: .netP)
            let appLauncher = AppLauncher(appBundleURL: Bundle.main.bundleURL)

            let popover = NetworkProtectionPopover(controller: controller,
                                                   onboardingStatusPublisher: onboardingStatusPublisher,
                                                   statusReporter: statusReporter,
                                                   appLauncher: appLauncher,
                                                   menuItems: {
                if UserDefaults.netP.networkProtectionOnboardingStatus == .completed {
                    return [
                        NetworkProtectionStatusView.Model.MenuItem(
                            name: UserText.networkProtectionNavBarStatusMenuVPNSettings, action: {
                                await appLauncher.launchApp(withCommand: .showSettings)
                            }),
                        NetworkProtectionStatusView.Model.MenuItem(
                            name: UserText.networkProtectionNavBarStatusMenuFAQ, action: {
                                await appLauncher.launchApp(withCommand: .showFAQ)
                            }),
                        NetworkProtectionStatusView.Model.MenuItem(
                            name: UserText.networkProtectionNavBarStatusViewShareFeedback,
                            action: {
                                await appLauncher.launchApp(withCommand: .shareFeedback)
                            })
                    ]
                } else {
                    return [
                        NetworkProtectionStatusView.Model.MenuItem(
                            name: UserText.networkProtectionNavBarStatusMenuFAQ, action: {
                                await appLauncher.launchApp(withCommand: .showFAQ)
                            }),
                        NetworkProtectionStatusView.Model.MenuItem(
                            name: UserText.networkProtectionNavBarStatusViewShareFeedback,
                            action: {
                                await appLauncher.launchApp(withCommand: .shareFeedback)
                            })
                    ]
                }
            },
                                                   agentLoginItem: LoginItem.vpnMenu,
                                                   isMenuBarStatusView: false,
                                                   userDefaults: .netP,
                                                   uninstallHandler: { [weak self] in
                _ = await self?.networkProtectionFeatureDisabler.disable(keepAuthToken: false, uninstallSystemExtension: true)
            })
            popover.delegate = delegate

            networkProtectionPopover = popover
            return popover
        }()

        show(popover, positionedBelow: view)
    }

    private func show(_ popover: NSPopover, positionedBelow view: NSView) {
        view.isHidden = false

        popover.show(positionedBelow: view.bounds.insetFromLineOfDeath(flipped: view.isFlipped), in: view)
    }

    func toggle(positionedBelow view: NSView, withDelegate delegate: NSPopoverDelegate) {
        if let networkProtectionPopover, networkProtectionPopover.isShown {
            networkProtectionPopover.close()
        } else {
            let featureVisibility = DefaultNetworkProtectionVisibility()

            if featureVisibility.isNetworkProtectionBetaVisible() {
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
