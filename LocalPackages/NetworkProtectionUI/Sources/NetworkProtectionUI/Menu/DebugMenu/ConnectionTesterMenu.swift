//
//  NetworkProtectionConnectionTesterMenu.swift
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
import Common
import Foundation
import NetworkProtection

/// The model that handles the logic for the debug menu.
///
public protocol ConnectionTesterMenuModel {
    /// Whether the connection tester can disable the Network Protection tester.
    ///
    var canDisableNetworkProtection: Bool { get set }

    /// Resets all settings to their default values
    ///
    func resetToDefaults()
}

/// Controller for the Network Protection debug menu.
///
@objc
@MainActor
public final class ConnectionTesterMenu: NSMenu {

    private var model: ConnectionTesterMenuModel

    private let resetToDefaultsMenuItem = NSMenuItem(title: "Reset to Defaults", action: #selector(resetToDefaults), keyEquivalent: "")
    private let canDisableNetworkProtectionMenuItem = NSMenuItem(title: "Can disable NetP", action: #selector(toggleCanDisableNetworkProtection), keyEquivalent: "")

    public init(title: String, model: ConnectionTesterMenuModel) {
        self.model = model

        super.init(title: title)

        self.items = [
            resetToDefaultsMenuItem,
            .separator(),
            canDisableNetworkProtectionMenuItem
        ]
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    func resetToDefaults() {
        model.resetToDefaults()
    }

    @objc
    func toggleCanDisableNetworkProtection() {
        model.canDisableNetworkProtection.toggle()
    }

    /*

    // MARK: Populating Menu Items

    private func populateNetworkProtectionServerListMenuItems() {
        guard let submenu = preferredServerMenu,
              let automaticItem = preferredServerAutomaticItem else {
            assertionFailure("\(#function): Failed to get submenu")
            return
        }

        let networkProtectionServerStore = NetworkProtectionServerListFileSystemStore(errorEvents: nil)
        let servers = (try? networkProtectionServerStore.storedNetworkProtectionServerList()) ?? []

        if servers.isEmpty {
            submenu.items = [automaticItem]
        } else {
            submenu.items = [automaticItem, NSMenuItem.separator()] + servers.map({ server in
                let title: String

                if server.isRegistered {
                    title = "\(server.serverInfo.name) (\(server.serverInfo.serverLocation) – Public Key Registered)"
                } else {
                    title = "\(server.serverInfo.name) (\(server.serverInfo.serverLocation))"
                }

                return NSMenuItem(title: title,
                                  action: #selector(setSelectedServer(_:)),
                                  target: self,
                                  keyEquivalent: "")

            })
        }
    }

    private struct NetworkProtectionKeyValidityOption {
        let title: String
        let validity: TimeInterval
    }

    private static let registrationKeyValidityOptions: [NetworkProtectionKeyValidityOption] = [
        .init(title: "15 seconds", validity: .seconds(15)),
        .init(title: "30 seconds", validity: .seconds(30)),
        .init(title: "1 minute", validity: .minutes(1)),
        .init(title: "5 minutes", validity: .minutes(5)),
        .init(title: "30 minutes", validity: .minutes(30)),
        .init(title: "1 hour", validity: .hours(1))
    ]

    private func populateNetworkProtectionRegistrationKeyValidityMenuItems() {
#if DEBUG
        guard let menu = registrationKeyValidityMenu,
              let automaticItem = registrationKeyValidityAutomaticItem else {

            assertionFailure("\(#function): Failed to get menu or automatic item")
            return
        }

        if Self.registrationKeyValidityOptions.isEmpty {
            // Not likely to happen as it's hard-coded, but still...
            menu.items = [automaticItem]
        } else {
            menu.items = [automaticItem, NSMenuItem.separator()] + Self.registrationKeyValidityOptions.map { option in
                let menuItem = NSMenuItem(title: option.title,
                                          action: #selector(setRegistrationKeyValidity(_:)),
                                          target: self,
                                          keyEquivalent: "")

                menuItem.representedObject = option.validity
                return menuItem
            }
        }
#else
        guard let separator = registrationKeyValidityMenuSeparatorItem,
              let validityMenu = registrationKeyValidityMenuItem else {
            assertionFailure("\(#function): Failed to get menu or automatic item")
            return
        }

        separator.isHidden = true
        validityMenu.isHidden = true
#endif
    }

    private func populateExclusionsMenuItems() {
        exclusionsMenu.removeAllItems()

        for item in NetworkProtectionTunnelController.exclusionList {
            let menuItem: NSMenuItem
            switch item {
            case .section(let title):
                menuItem = NSMenuItem(title: title, action: nil, target: nil)
                menuItem.isEnabled = false

            case .exclusion(range: let range, description: let description, default: _):
                menuItem = NSMenuItem(title: "\(range)\(description != nil ? " (\(description!))" : "")",
                                      action: #selector(toggleExclusionAction),
                                      target: self,
                                      representedObject: range.stringRepresentation)
            }
            exclusionsMenu.addItem(menuItem)
        }
    }*/

    // MARK: - Menu State Update

    override func update() {
        //updateRekeyValidityMenu()
        canDisableNetworkProtectionMenuItem.state = model.canDisableNetworkProtection ? .on : .off
    }
/*
    private func updateRekeyValidityMenu() {
        guard let menu = registrationKeyValidityMenu else {
            assertionFailure("Outlet not connected for preferredServerMenu")
            return
        }

        let selectedValidity = debugUtilities.registrationKeyValidity

        if selectedValidity == nil {
            menu.items.first?.state = .on
        } else {
            menu.items.first?.state = .off
        }

        // We're skipping the first two items because they're the automatic menu item and
        // the separator line.
        let serverItems = menu.items.dropFirst(2)

        for item in serverItems {
            if item.representedObject as? TimeInterval == selectedValidity {
                item.state = .on
            } else {
                item.state = .off
            }
        }
    }

    private func updateNetworkProtectionMenuItemsState() {
        let controller = NetworkProtectionTunnelController()

        shouldEnforceRoutesMenuItem.state = controller.shouldEnforceRoutes ? .on : .off
        shouldIncludeAllNetworksMenuItem.state = controller.shouldIncludeAllNetworks ? .on : .off
        connectOnLogInMenuItem.state = controller.shouldAutoConnectOnLogIn ? .on : .off

        excludeLocalNetworksMenuItem.state = controller.shouldExcludeLocalRoutes ? .on : .off
        connectionTesterEnabledMenuItem.state = controller.isConnectionTesterEnabled ? .on : .off
    }*/
}
/*
extension NetworkProtectionDebugMenu: NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === exclusionsMenu {
            let controller = NetworkProtectionTunnelController()
            for item in menu.items {
                guard let route = item.representedObject as? String else { continue }
                item.state = controller.isExcludedRouteEnabled(route) ? .on : .off
                // TO BE fixed: see NetworkProtectionTunnelController.excludedRoutes()
                item.isEnabled = !(controller.shouldEnforceRoutes && route == "10.0.0.0/8")
            }
        }
    }

}*/
