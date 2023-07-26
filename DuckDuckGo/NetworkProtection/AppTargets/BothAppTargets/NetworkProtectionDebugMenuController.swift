//
//  NetworkProtectionDebugMenuController.swift
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

#if !NETWORK_PROTECTION

/// App store placedholder.  Should be replaced with the actual thing once we enable NetP in App Store builds.
///
@objc
final class NetworkProtectionDebugMenuController: NSObject {
}

#else

/// Controller for the Network Protection debug menu.
///
@objc
final class NetworkProtectionDebugMenuController: NSObject {

    // MARK: - Outlets

    @IBOutlet weak var preferredServerMenu: NSMenu? {
        didSet {
            populateNetworkProtectionServerListMenuItems()
            preferredServerMenu?.delegate = self
        }
    }

    @IBOutlet weak var networkProtectionRegistrationKeyValidityMenuSeparatorItem: NSMenuItem?
    @IBOutlet weak var networkProtectionRegistrationKeyValidityMenuItem: NSMenuItem?

    @IBOutlet weak var registrationKeyValidityMenu: NSMenu? {
        didSet {
            populateNetworkProtectionRegistrationKeyValidityMenuItems()
            registrationKeyValidityMenu?.delegate = self
        }
    }

    // MARK: - Debug Logic

    private let debugUtilities = NetworkProtectionDebugUtilities()

    // MARK: - Debug Menu IBActions

    /// Resets all state for NetworkProtection.
    ///
    @IBAction
    func resetAllState(_ sender: Any?) {
        Task { @MainActor in
            guard case .alertFirstButtonReturn = await NSAlert.resetNetworkProtectionAlert().runModal() else { return }

            do {
                try await debugUtilities.resetAllState()
            } catch {
                await NSAlert(error: error).runModal()
            }
        }
    }

    /// Removes the system extension and agents for Network Protection.
    ///
    @IBAction
    func removeSystemExtensionAndAgents(_ sender: Any?) {
        Task { @MainActor in
            guard case .alertFirstButtonReturn = await NSAlert.removeSystemExtensionAndAgentsAlert().runModal() else { return }

            do {
                try await debugUtilities.removeSystemExtensionAndAgents()
            } catch {
                await NSAlert(error: error).runModal()
            }
        }
    }

    /// Sends a test user notification.
    ///
    @IBAction
    func sendTestNotification(_ sender: Any?) {
        Task { @MainActor in
            do {
                try await debugUtilities.sendTestNotificationRequest()
            } catch {
                await NSAlert(error: error).runModal()
            }
        }
    }

    /// Sets the selected server.
    ///
    @IBAction
    func setSelectedServer(_ menuItem: NSMenuItem?) {
        guard let title = menuItem?.title else {
            assertionFailure("\(#function): Failed to cast sender to NSMenuItem")
            return
        }

        let selectedServer: SelectedNetworkProtectionServer

        if title == "Automatic" {
            selectedServer = .automatic
        } else {
            let titleComponents = title.components(separatedBy: " ")
            selectedServer = .endpoint(titleComponents.first!)
        }

        debugUtilities.setSelectedServer(selectedServer: selectedServer)
    }

    /// Expires the registration key immediately.
    ///
    @IBAction
    func expireRegistrationKeyNow(_ sender: Any?) {
        Task {
            await debugUtilities.expireRegistrationKeyNow()
        }
    }

    /// Sets the registration key validity.
    ///
    @IBAction
    func setRegistrationKeyValidity(_ menuItem: NSMenuItem?) {
        guard let menuItem else {
            assertionFailure("\(#function): Failed to cast sender to NSMenuItem")
            return
        }

        // nil means automatic
        let validity = menuItem.representedObject as? TimeInterval

        debugUtilities.registrationKeyValidity = validity
    }

    /// Simulates a controller failure the next time Network Protection is started.
    ///
    @IBAction
    func simulateControllerFailure(_ menuItem: NSMenuItem?) {
        guard let menuItem else {
            assertionFailure("\(#function): Failed to cast sender to NSMenuItem")
            return
        }

        if menuItem.state == .on {
            menuItem.state = .off
        } else {
            menuItem.state = .on
        }

        NetworkProtectionTunnelController.simulationOptions.setEnabled(menuItem.state == .on, option: .controllerFailure)
    }

    /// Simulates a tunnel failure the next time Network Protection is started.
    ///
    @IBAction
    func simulateTunnelFailure(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem else {
            assertionFailure("\(#function): Failed to cast sender to NSMenuItem")
            return
        }

        if menuItem.state == .on {
            menuItem.state = .off
        } else {
            menuItem.state = .on
        }

        NetworkProtectionTunnelController.simulationOptions.setEnabled(menuItem.state == .on, option: .tunnelFailure)
    }

    // MARK: Populating Menu Items

    private func populateNetworkProtectionServerListMenuItems() {
        guard let submenu = preferredServerMenu,
              let automaticItem = submenu.items.first else {
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

    private static let networkProtectionRegistrationKeyValidityOptions: [NetworkProtectionKeyValidityOption] = [
        .init(title: "15 seconds", validity: .seconds(15)),
        .init(title: "30 seconds", validity: .seconds(30)),
        .init(title: "1 minute", validity: .minutes(1)),
        .init(title: "5 minutes", validity: .minutes(5)),
        .init(title: "30 minutes", validity: .minutes(30)),
        .init(title: "1 hour", validity: .hours(1))
    ]

    private func populateNetworkProtectionRegistrationKeyValidityMenuItems() {
        #if DEBUG
        guard let submenu = networkProtectionRegistrationKeyValidityMenuItem?.submenu,
              let automaticItem = submenu.items.first else {

            assertionFailure("\(#function): Failed to get submenu")
            return
        }

        if Self.networkProtectionRegistrationKeyValidityOptions.isEmpty {
            // Not likely to happen as it's hard-coded, but still...
            submenu.items = [automaticItem]
        } else {
            submenu.items = [automaticItem, NSMenuItem.separator()] + Self.networkProtectionRegistrationKeyValidityOptions.map { option in
                let menuItem = NSMenuItem(title: option.title,
                                          action: #selector(setRegistrationKeyValidity(_:)),
                                          target: self,
                                          keyEquivalent: "")

                menuItem.representedObject = option.validity
                return menuItem
            }
        }
        #else
        guard let separator = networkProtectionRegistrationKeyValidityMenuSeparatorItem,
              let validityMenu = networkProtectionRegistrationKeyValidityMenuItem else {
            assertionFailure("\(#function): Failed to get submenu")
            return
        }

        separator.isHidden = true
        validityMenu.isHidden = true
        #endif
    }

    // MARK: - Menu State Update

    func updatePreferredServerMenu(_ menu: NSMenu) {
        let selectedServerName = debugUtilities.selectedServerName()

        if selectedServerName == nil {
            menu.items.first?.state = .on
        } else {
            menu.items.first?.state = .off
        }

        // We're skipping the first two items because they're the automatic menu item and
        // the separator line.
        let serverItems = menu.items.suffix(menu.items.count - 2)

        for item in serverItems {
            if let selectedServerName,
               item.title.hasPrefix(selectedServerName) {
                item.state = .on
            } else {
                item.state = .off
            }
        }
    }

    func updateRekeyValidityMenu(_ menu: NSMenu) {
        let selectedValidity = debugUtilities.registrationKeyValidity

        if selectedValidity == nil {
            menu.items.first?.state = .on
        } else {
            menu.items.first?.state = .off
        }

        // We're skipping the first two items because they're the automatic menu item and
        // the separator line.
        let serverItems = menu.items.suffix(menu.items.count - 2)

        for item in serverItems {
            if item.representedObject as? TimeInterval == selectedValidity {
                item.state = .on
            } else {
                item.state = .off
            }
        }
    }
}

extension NetworkProtectionDebugMenuController: NSMenuDelegate {
    @MainActor func menuNeedsUpdate(_ menu: NSMenu) {
        switch menu {
        case preferredServerMenu:
            updatePreferredServerMenu(menu)
        case registrationKeyValidityMenu:
            updateRekeyValidityMenu(menu)
        default:
            break
        }
    }
}

#endif
