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
import NetworkProtectionProxy
import NetworkProtectionUI
import os.log
import Subscription
import SwiftUI
import VPNAppLauncher
import BrowserServicesKit
import FeatureFlags

protocol NetworkProtectionIPCClient {
    var ipcStatusObserver: ConnectionStatusObserver { get }
    var ipcServerInfoObserver: ConnectionServerInfoObserver { get }
    var ipcConnectionErrorObserver: ConnectionErrorObserver { get }
    var ipcDataVolumeObserver: DataVolumeObserver { get }

    func start(completion: @escaping (Error?) -> Void)
    func stop(completion: @escaping (Error?) -> Void)
    func command(_ command: VPNCommand) async throws
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
    private let vpnUIPresenting: VPNUIPresenting
    private let proxySettings: TransparentProxySettings

    @Published
    private var siteInfo: ActiveSiteInfo?
    private let activeSitePublisher: ActiveSiteInfoPublisher
    private let featureFlagger = NSApp.delegateTyped.featureFlagger
    private var cancellables = Set<AnyCancellable>()

    init(ipcClient: VPNControllerXPCClient,
         vpnUninstaller: VPNUninstalling,
         vpnUIPresenting: VPNUIPresenting,
         proxySettings: TransparentProxySettings = .init(defaults: .netP)) {

        self.ipcClient = ipcClient
        self.vpnUninstaller = vpnUninstaller
        self.vpnUIPresenting = vpnUIPresenting
        self.proxySettings = proxySettings

        let activeDomainPublisher = ActiveDomainPublisher(windowControllersManager: .shared)

        activeSitePublisher = ActiveSiteInfoPublisher(
            activeDomainPublisher: activeDomainPublisher.eraseToAnyPublisher(),
            proxySettings: proxySettings)

        subscribeToCurrentSitePublisher()
    }

    private func subscribeToCurrentSitePublisher() {
        activeSitePublisher
            .assign(to: \.siteInfo, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    var isShown: Bool {
        networkProtectionPopover?.isShown ?? false
    }

    @MainActor
    func manageExcludedApps() {
        vpnUIPresenting.showVPNAppExclusions()
    }

    @MainActor
    func manageExcludedSites() {
        vpnUIPresenting.showVPNDomainExclusions()
    }

    private func statusViewSubmenu() -> [StatusBarMenu.MenuItem] {
        let appLauncher = AppLauncher(appBundleURL: Bundle.main.bundleURL)

        var menuItems = [StatusBarMenu.MenuItem]()

        if UserDefaults.netP.networkProtectionOnboardingStatus == .completed {
            menuItems.append(
                .text(icon: Image(.settings16), title: UserText.vpnStatusViewVPNSettingsMenuItemTitle, action: {
                    try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.showSettings)
                }))
        }

        menuItems.append(contentsOf: [
            .textWithDetail(
                icon: Image(.window16),
                title: UserText.vpnStatusViewExcludedAppsMenuItemTitle,
                detail: "(\(proxySettings.excludedApps.count))",
                action: { [weak self] in
                    self?.manageExcludedApps()
            }),
            .textWithDetail(
                icon: Image(.globe16),
                title: UserText.vpnStatusViewExcludedDomainsMenuItemTitle,
                detail: "(\(proxySettings.excludedDomains.count))",
                action: { [weak self] in
                    self?.manageExcludedSites()
            }),
            .divider(),
            .text(icon: Image(.help16), title: UserText.vpnStatusViewFAQMenuItemTitle, action: {
                try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.showFAQ)
            }),
            .text(icon: Image(.support16), title: UserText.vpnStatusViewSendFeedbackMenuItemTitle, action: {
                try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.shareFeedback)
            })
        ])

        return menuItems
    }

    /// Only used if the .networkProtectionAppExclusions feature flag is disabled
    ///
    private func legacyStatusViewSubmenu() -> [StatusBarMenu.MenuItem] {
        let appLauncher = AppLauncher(appBundleURL: Bundle.main.bundleURL)

        if UserDefaults.netP.networkProtectionOnboardingStatus == .completed {
            return [
                .text(title: UserText.networkProtectionNavBarStatusViewVPNSettings, action: {
                    try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.showSettings)
                }),
                .text(title: UserText.networkProtectionNavBarStatusViewFAQ, action: {
                    try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.showFAQ)
                }),
                .text(title: UserText.networkProtectionNavBarStatusViewSendFeedback, action: {
                    try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.shareFeedback)
                })
            ]
        } else {
            return [
                .text(title: UserText.networkProtectionNavBarStatusViewFAQ, action: {
                    try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.showFAQ)
                }),
                .text(title: UserText.networkProtectionNavBarStatusViewSendFeedback, action: {
                    try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.shareFeedback)
                })
            ]
        }
    }

    func show(positionedBelow view: NSView, withDelegate delegate: NSPopoverDelegate) -> NSPopover {

        /// Since the favicon doesn't have a publisher we force refreshing here
        activeSitePublisher.refreshActiveSiteInfo()

        let popover: NSPopover = {
            let vpnSettings = VPNSettings(defaults: .netP)
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
            let vpnURLEventHandler = VPNURLEventHandler()
            let uiActionHandler = VPNUIActionHandler(vpnURLEventHandler: vpnURLEventHandler, proxySettings: proxySettings)

            let connectionStatusPublisher = CurrentValuePublisher(
                initialValue: statusReporter.statusObserver.recentValue,
                publisher: statusReporter.statusObserver.publisher)

            let activeSitePublisher = CurrentValuePublisher(
                initialValue: siteInfo,
                publisher: $siteInfo.eraseToAnyPublisher())

            let siteTroubleshootingViewModel = SiteTroubleshootingView.Model(
                connectionStatusPublisher: connectionStatusPublisher,
                activeSitePublisher: activeSitePublisher,
                uiActionHandler: uiActionHandler)

            let statusViewModel = NetworkProtectionStatusView.Model(controller: controller,
                                              onboardingStatusPublisher: onboardingStatusPublisher,
                                              statusReporter: statusReporter,
                                              uiActionHandler: uiActionHandler,
                                              menuItems: { [weak self] in

                guard let self else { return [] }

                guard featureFlagger.isFeatureOn(.networkProtectionAppExclusions) else {
                    return legacyStatusViewSubmenu()
                }

                return statusViewSubmenu()
            },
                                              agentLoginItem: LoginItem.vpnMenu,
                                              isMenuBarStatusView: false,
                                              userDefaults: .netP,
                                              locationFormatter: DefaultVPNLocationFormatter(),
                                              uninstallHandler: { [weak self] in
                _ = try? await self?.vpnUninstaller.uninstall(removeSystemExtension: true)
            })

            let tipsFeatureFlagInitialValue = featureFlagger.isFeatureOn(.networkProtectionUserTips)
            let tipsFeatureFlagPublisher: CurrentValuePublisher<Bool, Never>

            if let overridesHandler = featureFlagger.localOverrides?.actionHandler as? FeatureFlagOverridesPublishingHandler<FeatureFlag> {

                let featureFlagPublisher = overridesHandler.flagDidChangePublisher
                    .filter { $0.0 == .networkProtectionUserTips }

                tipsFeatureFlagPublisher = CurrentValuePublisher(
                    initialValue: tipsFeatureFlagInitialValue,
                    publisher: Just(tipsFeatureFlagInitialValue).eraseToAnyPublisher())
            } else {
                tipsFeatureFlagPublisher = CurrentValuePublisher(
                    initialValue: tipsFeatureFlagInitialValue,
                    publisher: Just(tipsFeatureFlagInitialValue).eraseToAnyPublisher())
            }

            let tipsModel = VPNTipsModel(featureFlagPublisher: tipsFeatureFlagPublisher,
                                         statusObserver: statusReporter.statusObserver,
                                         activeSitePublisher: activeSitePublisher,
                                         forMenuApp: false,
                                         vpnSettings: vpnSettings,
                                         proxySettings: proxySettings,
                                         logger: Logger(subsystem: "DuckDuckGo", category: "TipKit"))

            let popover = NetworkProtectionPopover(
                statusViewModel: statusViewModel,
                statusReporter: statusReporter,
                siteTroubleshootingViewModel: siteTroubleshootingViewModel,
                tipsModel: tipsModel,
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
