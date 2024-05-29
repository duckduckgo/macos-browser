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
    var ipcDataVolumeObserver: DataVolumeObserver { get }

    func start(completion: @escaping (Error?) -> Void)
    func stop(completion: @escaping (Error?) -> Void)
}

extension VPNControllerXPCClient: NetworkProtectionIPCClient {
    public var ipcStatusObserver: any NetworkProtection.ConnectionStatusObserver { connectionStatusObserver }
    public var ipcServerInfoObserver: any NetworkProtection.ConnectionServerInfoObserver { serverInfoObserver }
    public var ipcConnectionErrorObserver: any NetworkProtection.ConnectionErrorObserver { connectionErrorObserver }
    public var ipcDataVolumeObserver: any NetworkProtection.DataVolumeObserver { dataVolumeObserver }
}

final class NetworkProtectionNavBarPopoverManager: NetPPopoverManager {
    private var networkProtectionPopover: NetworkProtectionPopover?
    let ipcClient: NetworkProtectionIPCClient
    let vpnUninstaller: VPNUninstalling

    init(ipcClient: VPNControllerXPCClient,
         vpnUninstaller: VPNUninstalling) {
        self.ipcClient = ipcClient
        self.vpnUninstaller = vpnUninstaller
    }

    var isShown: Bool {
        networkProtectionPopover?.isShown ?? false
    }

    // swiftlint:disable:next function_body_length
    func show(positionedBelow view: NSView, withDelegate delegate: NSPopoverDelegate) -> NSPopover {
        let popover = {

            let controller = NetworkProtectionIPCTunnelController(ipcClient: ipcClient)

            let statusReporter = DefaultNetworkProtectionStatusReporter(
                statusObserver: ipcClient.ipcStatusObserver,
                serverInfoObserver: ipcClient.ipcServerInfoObserver,
                connectionErrorObserver: ipcClient.ipcConnectionErrorObserver,
                connectivityIssuesObserver: ConnectivityIssueObserverThroughDistributedNotifications(),
                controllerErrorMessageObserver: ControllerErrorMesssageObserverThroughDistributedNotifications(),
                dataVolumeObserver: ipcClient.ipcDataVolumeObserver
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
                                                   locationFormatter: DefaultVPNLocationFormatter(),
                                                   uninstallHandler: { [weak self] in
                _ = try? await self?.vpnUninstaller.uninstall(removeSystemExtension: true)
            })
            popover.delegate = delegate

            networkProtectionPopover = popover
            return popover
        }()

        show(popover, positionedBelow: view)
        return popover
    }

    private func show(_ popover: NSPopover, positionedBelow view: NSView) {
        view.isHidden = false

        popover.show(positionedBelow: view.bounds.insetFromLineOfDeath(flipped: view.isFlipped), in: view)
    }

    func toggle(positionedBelow view: NSView, withDelegate delegate: NSPopoverDelegate) -> NSPopover? {
        if let networkProtectionPopover, networkProtectionPopover.isShown {
            networkProtectionPopover.close()
            self.networkProtectionPopover = nil

            return nil
        } else {
            return show(positionedBelow: view, withDelegate: delegate)
        }
    }

    func close() {
        networkProtectionPopover?.close()
        networkProtectionPopover = nil
    }
}
