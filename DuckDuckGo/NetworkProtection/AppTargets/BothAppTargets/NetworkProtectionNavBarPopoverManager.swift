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

import AppLauncher
import AppKit
import Combine
import Common
import Foundation
import LoginItems
import NetworkProtection
import NetworkProtectionIPC
import NetworkProtectionUI
import Subscription
import VPNAppLauncher
import SwiftUI
import NetworkProtectionProxy

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

@MainActor
final class NetworkProtectionNavBarPopoverManager: NetPPopoverManager {
    private var networkProtectionPopover: NetworkProtectionPopover?
    let ipcClient: NetworkProtectionIPCClient
    let vpnUninstaller: VPNUninstalling

    @Published
    private var siteInfo: SiteTroubleshootingInfo?
    private let siteTroubleshootingInfoPublisher: SiteTroubleshootingInfoPublisher
    private var cancellables = Set<AnyCancellable>()

    init(ipcClient: VPNControllerXPCClient,
         vpnUninstaller: VPNUninstalling) {

        self.ipcClient = ipcClient
        self.vpnUninstaller = vpnUninstaller

        siteTroubleshootingInfoPublisher = SiteTroubleshootingInfoPublisher(
            windowControllerManager: .shared,
            proxySettings: TransparentProxySettings(defaults: .netP))

        subscribeToCurrentSitePublisher()
    }

    private func subscribeToCurrentSitePublisher() {
        siteTroubleshootingInfoPublisher
            .assign(to: \.siteInfo, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    var isShown: Bool {
        networkProtectionPopover?.isShown ?? false
    }

    func show(positionedBelow view: NSView, withDelegate delegate: NSPopoverDelegate) -> NSPopover {
        let popover: NSPopover = {
            let controller = NetworkProtectionIPCTunnelController(ipcClient: ipcClient)

            let statusReporter = DefaultNetworkProtectionStatusReporter(
                statusObserver: ipcClient.ipcStatusObserver,
                serverInfoObserver: ipcClient.ipcServerInfoObserver,
                connectionErrorObserver: ipcClient.ipcConnectionErrorObserver,
                connectivityIssuesObserver: ConnectivityIssueObserverThroughDistributedNotifications(),
                controllerErrorMessageObserver: ControllerErrorMesssageObserverThroughDistributedNotifications(),
                dataVolumeObserver: ipcClient.ipcDataVolumeObserver,
                knownFailureObserver: KnownFailureObserverThroughDistributedNotifications()
            )

            let onboardingStatusPublisher = UserDefaults.netP.networkProtectionOnboardingStatusPublisher
            _ = VPNSettings(defaults: .netP)
            let appLauncher = AppLauncher(appBundleURL: Bundle.main.bundleURL)
            let vpnURLEventHandler = VPNURLEventHandler()
            let proxySettings = TransparentProxySettings(defaults: .netP)
            let uiActionHandler = VPNUIActionHandler(vpnURLEventHandler: vpnURLEventHandler, proxySettings: proxySettings)

            // We need to force-refresh the current site as there's currently no easy mechanism
            // to observe active-tab changes.  We just force-refresh when the popover is shown.
            siteTroubleshootingInfoPublisher.refresh()

            let siteTroubleshootingFeatureFlagPublisher = NSApp.delegateTyped.internalUserDecider.isInternalUserPublisher.eraseToAnyPublisher()

            let siteTroubleshootingViewModel = SiteTroubleshootingView.Model(
                featureFlagPublisher: siteTroubleshootingFeatureFlagPublisher,
                connectionStatusPublisher: statusReporter.statusObserver.publisher,
                siteTroubleshootingInfoPublisher: $siteInfo.eraseToAnyPublisher(),
                uiActionHandler: uiActionHandler)

            let statusViewModel = NetworkProtectionStatusView.Model(controller: controller,
                                              onboardingStatusPublisher: onboardingStatusPublisher,
                                              statusReporter: statusReporter,
                                              uiActionHandler: uiActionHandler,
                                              menuItems: {
                if UserDefaults.netP.networkProtectionOnboardingStatus == .completed {
                    return [
                        NetworkProtectionStatusView.Model.MenuItem(
                            name: UserText.networkProtectionNavBarStatusMenuVPNSettings, action: {
                                try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.showSettings)
                            }),
                        NetworkProtectionStatusView.Model.MenuItem(
                            name: UserText.networkProtectionNavBarStatusMenuFAQ, action: {
                                try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.showFAQ)
                            }),
                        NetworkProtectionStatusView.Model.MenuItem(
                            name: UserText.networkProtectionNavBarStatusViewShareFeedback,
                            action: {
                                try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.shareFeedback)
                            })
                    ]
                } else {
                    return [
                        NetworkProtectionStatusView.Model.MenuItem(
                            name: UserText.networkProtectionNavBarStatusMenuFAQ, action: {
                                try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.showFAQ)
                            }),
                        NetworkProtectionStatusView.Model.MenuItem(
                            name: UserText.networkProtectionNavBarStatusViewShareFeedback,
                            action: {
                                try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.shareFeedback)
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

            let popover = NetworkProtectionPopover(
                statusViewModel: statusViewModel,
                statusReporter: statusReporter,
                siteTroubleshootingViewModel: siteTroubleshootingViewModel,
                debugInformationViewModel: DebugInformationViewModel(showDebugInformation: false))
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
