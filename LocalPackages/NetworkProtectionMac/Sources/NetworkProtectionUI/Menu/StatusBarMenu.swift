//
//  StatusBarMenu.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import Foundation
import Combine
import Common
import LoginItems
import NetworkProtection
import NetworkProtectionProxy
import os.log
import SwiftUI

/// Abstraction of the the VPN status bar menu with a simple interface.
///
@objc
public final class StatusBarMenu: NSObject {
    public typealias MenuItem = NetworkProtectionStatusView.Model.MenuItem

    private let model: StatusBarMenuModel

    private let statusItem: NSStatusItem
    private var popover: NetworkProtectionPopover?

    private let controller: TunnelController
    private let statusReporter: NetworkProtectionStatusReporter
    private let onboardingStatusPublisher: OnboardingStatusPublisher
    private let uiActionHandler: VPNUIActionHandling
    private let menuItems: () -> [MenuItem]
    private let agentLoginItem: LoginItem?
    private let isMenuBarStatusView: Bool
    private let userDefaults: UserDefaults
    private let locationFormatter: VPNLocationFormatting
    private let uninstallHandler: () async -> Void

    // MARK: - NetP Icon publisher

    private let iconPublisher: NetworkProtectionIconPublisher
    private var iconPublisherCancellable: AnyCancellable?

    // MARK: - Initialization

    /// Default initializer
    ///
    /// - Parameters:
    ///     - statusItem: (meant for testing) this allows us to inject our own status `NSStatusItem` to make automated testing easier..
    ///
    @MainActor
    public init(model: StatusBarMenuModel,
                statusItem: NSStatusItem? = nil,
                onboardingStatusPublisher: OnboardingStatusPublisher,
                statusReporter: NetworkProtectionStatusReporter,
                controller: TunnelController,
                iconProvider: IconProvider,
                uiActionHandler: VPNUIActionHandling,
                menuItems: @escaping () -> [MenuItem],
                agentLoginItem: LoginItem?,
                isMenuBarStatusView: Bool,
                userDefaults: UserDefaults,
                locationFormatter: VPNLocationFormatting,
                uninstallHandler: @escaping () async -> Void) {

        self.model = model
        let statusItem = statusItem ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem
        self.iconPublisher = NetworkProtectionIconPublisher(statusReporter: statusReporter, iconProvider: iconProvider)

        self.controller = controller
        self.statusReporter = statusReporter
        self.onboardingStatusPublisher = onboardingStatusPublisher
        self.uiActionHandler = uiActionHandler
        self.menuItems = menuItems
        self.agentLoginItem = agentLoginItem
        self.isMenuBarStatusView = isMenuBarStatusView
        self.userDefaults = userDefaults
        self.locationFormatter = locationFormatter
        self.uninstallHandler = uninstallHandler

        super.init()

        statusItem.button?.image = .image(for: iconPublisher.icon)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusBarButtonTapped)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        subscribeToIconUpdates()
    }

    @objc
    private func statusBarButtonTapped() {
        let isOptionKeyPressed = NSApp.currentEvent?.modifierFlags.contains(.option) ?? false
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp

        guard !isRightClick else {
            showContextMenu()
            return
        }

        Task { @MainActor in
            togglePopover(isOptionKeyPressed: isOptionKeyPressed)
        }
    }

    private func subscribeToIconUpdates() {
        iconPublisherCancellable = iconPublisher.$icon
            .receive(on: DispatchQueue.main)
            .sink { [weak self] icon in

            self?.statusItem.button?.image = .image(for: icon)
        }
    }

    // MARK: - Popover

    @MainActor
    private func togglePopover(isOptionKeyPressed: Bool) {
        if let popover, popover.isShown {
            popover.close()
            self.popover = nil
        } else {
            guard let button = statusItem.button else {
                return
            }

            let connectionStatusPublisher = CurrentValuePublisher(
                initialValue: .disconnected,
                publisher: Just(NetworkProtection.ConnectionStatus.disconnected).eraseToAnyPublisher())

            let activeSitePublisher = CurrentValuePublisher(
                initialValue: ActiveSiteInfo?(nil),
                publisher: Just(nil).eraseToAnyPublisher())

            let siteTroubleshootingViewModel = SiteTroubleshootingView.Model(
                connectionStatusPublisher: connectionStatusPublisher,
                activeSitePublisher: activeSitePublisher,
                uiActionHandler: uiActionHandler)

            // We don't use tips in the status menu app.
            let tipsFeatureFlagPublisher = CurrentValuePublisher<Bool, Never>(
                initialValue: false,
                publisher: Just(false).eraseToAnyPublisher())

            let tipsModel = VPNTipsModel(featureFlagPublisher: tipsFeatureFlagPublisher,
                                         statusObserver: statusReporter.statusObserver,
                                         activeSitePublisher: activeSitePublisher,
                                         forMenuApp: true,
                                         vpnSettings: VPNSettings(defaults: userDefaults),
                                         proxySettings: TransparentProxySettings(defaults: userDefaults),
                                         logger: Logger(subsystem: "DuckDuckGo", category: "TipKit"))

            let debugInformationViewModel = DebugInformationViewModel(showDebugInformation: isOptionKeyPressed)

            let statusViewModel = NetworkProtectionStatusView.Model(
                controller: controller,
                onboardingStatusPublisher: onboardingStatusPublisher,
                statusReporter: statusReporter,
                uiActionHandler: uiActionHandler,
                menuItems: menuItems,
                agentLoginItem: agentLoginItem,
                isMenuBarStatusView: isMenuBarStatusView,
                userDefaults: userDefaults,
                locationFormatter: locationFormatter,
                uninstallHandler: uninstallHandler)

            popover = NetworkProtectionPopover(
                statusViewModel: statusViewModel,
                statusReporter: statusReporter,
                siteTroubleshootingViewModel: siteTroubleshootingViewModel,
                tipsModel: tipsModel,
                debugInformationViewModel: debugInformationViewModel)
            popover?.behavior = .transient

            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Context

    private func showContextMenu() {
        if let popover, popover.isShown {
            popover.close()
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.items = model.contextMenuItems

        // I'm not sure why +8 is needed, but that seems to be the right positioning to make this work well
        // across all systems.  I'm seeing an issue where the menu looks right for me but not for others testing
        // this, and this seems to fix it:
        // Ref: https://app.asana.com/0/0/1206318017787812/1206336583680668/f
        let yPosition = statusItem.statusBar!.thickness + 8

        menu.popUp(positioning: nil,
                   at: NSPoint(x: 0, y: yPosition),
                   in: statusItem.button)
    }

    // MARK: - Showing & Hiding the menu

    public func show() {
        statusItem.isVisible = true
    }

    public func hide() {
        statusItem.isVisible = false
    }
}

extension StatusBarMenu: NSMenuDelegate {
    public func menuDidClose(_ menu: NSMenu) {
        // We need to remove the context menu when it's closed because otherwise
        // macOS will bypass our custom click-handling code and will proceed directly
        // to always showing the context menu (ignoring if it's a left or right click).
        statusItem.menu = nil
    }
}
