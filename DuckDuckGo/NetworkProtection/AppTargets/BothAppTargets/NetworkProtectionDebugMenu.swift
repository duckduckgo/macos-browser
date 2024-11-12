//
//  NetworkProtectionDebugMenu.swift
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
import NetworkProtectionProxy
import SwiftUI
import os.log

/// Controller for the VPN debug menu.
///
final class NetworkProtectionDebugMenu: NSMenu {

    private let transparentProxySettings = TransparentProxySettings(defaults: .netP)

    // MARK: - Menus

    private let environmentMenu = NSMenu()

    private let preferredServerMenu: NSMenu
    private let preferredServerAutomaticItem = NSMenuItem(title: "Automatic", action: #selector(NetworkProtectionDebugMenu.setSelectedServer))

    private let registrationKeyValidityMenu: NSMenu
    private let registrationKeyValidityAutomaticItem = NSMenuItem(title: "Automatic", action: #selector(NetworkProtectionDebugMenu.setRegistrationKeyValidity))

    private let resetToDefaults = NSMenuItem(title: "Reset Settings to defaults", action: #selector(NetworkProtectionDebugMenu.resetSettings))

    private let excludeDDGBrowserTrafficFromVPN = NSMenuItem(title: "DDG Browser", action: #selector(toggleExcludeDDGBrowser))
    private let excludeDBPTrafficFromVPN = NSMenuItem(title: "DBP Background Agent", action: #selector(toggleExcludeDBPBackgroundAgent))

    private let shouldEnforceRoutesMenuItem = NSMenuItem(title: "enforceRoutes", action: #selector(NetworkProtectionDebugMenu.toggleEnforceRoutesAction))
    private let shouldIncludeAllNetworksMenuItem = NSMenuItem(title: "includeAllNetworks", action: #selector(NetworkProtectionDebugMenu.toggleIncludeAllNetworks))
    private let disableRekeyingMenuItem = NSMenuItem(title: "Disable Rekeying", action: #selector(NetworkProtectionDebugMenu.toggleRekeyingDisabled))

    private let excludeLocalNetworksMenuItem = NSMenuItem(title: "excludeLocalNetworks", action: #selector(NetworkProtectionDebugMenu.toggleShouldExcludeLocalRoutes))

    init() {
        preferredServerMenu = NSMenu { [preferredServerAutomaticItem] in
            preferredServerAutomaticItem
        }
        registrationKeyValidityMenu = NSMenu { [registrationKeyValidityAutomaticItem] in
            registrationKeyValidityAutomaticItem
        }
        super.init(title: "VPN")

        buildItems {
            NSMenuItem(title: "Reset") {

                NSMenuItem(title: "Reset All State Keeping Invite", action: #selector(NetworkProtectionDebugMenu.resetAllKeepingInvite))
                    .targetting(self)

                NSMenuItem(title: "Reset All State", action: #selector(NetworkProtectionDebugMenu.resetAllState))
                    .targetting(self)

                NSMenuItem.separator() // Resetting single components should go below this point

                NSMenuItem(title: "Remove Network Extension and Login Items", action: #selector(NetworkProtectionDebugMenu.removeSystemExtensionAndAgents))
                    .targetting(self)

                NSMenuItem(title: "Remove VPN configuration", action: #selector(NetworkProtectionDebugMenu.removeVPNConfiguration(_:)))
                    .targetting(self)

                resetToDefaults
                    .targetting(self)

                NSMenuItem.separator() // Resetting VPN subfeatures should go below this point

                NSMenuItem(title: "Reset Site Issue Alert", action: #selector(NetworkProtectionDebugMenu.resetSiteIssuesAlert(_:)))
                    .targetting(self)
            }

            NSMenuItem.separator()

            NSMenuItem(title: "Adapter") {
                NSMenuItem(title: "Restart Adapter", action: #selector(NetworkProtectionDebugMenu.restartAdapter(_:)))
                    .targetting(self)

                NSMenuItem(title: "Re-create Adapter", action: #selector(NetworkProtectionDebugMenu.restartAdapter(_:)))
                    .targetting(self)
            }

            NSMenuItem(title: "Tunnel Settings") {
                shouldIncludeAllNetworksMenuItem
                    .targetting(self)

                excludeLocalNetworksMenuItem
                    .targetting(self)

                shouldEnforceRoutesMenuItem
                    .targetting(self)
            }

            NSMenuItem.separator()

            NSMenuItem(title: "Send Test Notification", action: #selector(NetworkProtectionDebugMenu.sendTestNotification))
                .targetting(self)

            NSMenuItem(title: "Log Feedback Metadata to Console", action: #selector(NetworkProtectionDebugMenu.logFeedbackMetadataToConsole))
                .targetting(self)

            NSMenuItem(title: "Onboarding")
                .submenu(NetworkProtectionOnboardingMenu())

            NSMenuItem(title: "Environment")
                .submenu(environmentMenu)

            NSMenuItem(title: "Excluded Apps") {
                excludeDDGBrowserTrafficFromVPN.targetting(self)
                excludeDBPTrafficFromVPN.targetting(self)
            }

            NSMenuItem(title: "Preferred Server").submenu(preferredServerMenu)

            NSMenuItem(title: "Registration Key") {
                NSMenuItem(title: "Expire Now", action: #selector(NetworkProtectionDebugMenu.expireRegistrationKeyNow))
                    .targetting(self)
                disableRekeyingMenuItem
                    .targetting(self)

#if DEBUG
                NSMenuItem.separator()
                NSMenuItem(title: "Validity").submenu(registrationKeyValidityMenu)
#endif
            }

            NSMenuItem(title: "Simulate Failure")
                .submenu(NetworkProtectionSimulateFailureMenu())

            NSMenuItem.separator()

            NSMenuItem(title: "Open App Container in Finder", action: #selector(NetworkProtectionDebugMenu.openAppContainerInFinder))
                .targetting(self)
        }

        preferredServerMenu.autoenablesItems = false
        populateNetworkProtectionEnvironmentListMenuItems()
        Task {
            try? await populateNetworkProtectionServerListMenuItems()
        }
        populateNetworkProtectionRegistrationKeyValidityMenuItems()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Tunnel Settings

    private var settings: VPNSettings {
        Application.appDelegate.vpnSettings
    }

    // MARK: - Debug Logic

    private let debugUtilities = NetworkProtectionDebugUtilities()

    // MARK: - Debug Menu Actions

    /// Resets all state for NetworkProtection.
    ///
    @objc func resetAllState(_ sender: Any?) {
        Task { @MainActor in
            guard case .alertFirstButtonReturn = await NSAlert.resetNetworkProtectionAlert().runModal() else { return }

            do {
                try await debugUtilities.resetAllState(keepAuthToken: false)
            } catch {
                Logger.networkProtection.error("Error in resetAllState: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    @objc func resetSiteIssuesAlert(_ sender: Any?) {
        debugUtilities.resetSiteIssuesAlert()
    }

    /// Resets all state for NetworkProtection.
    ///
    @objc func resetAllKeepingInvite(_ sender: Any?) {
        Task { @MainActor in
            guard case .alertFirstButtonReturn = await NSAlert.resetNetworkProtectionAlert().runModal() else { return }
            do {
                try await debugUtilities.resetAllState(keepAuthToken: true)
            } catch {
                Logger.networkProtection.error("Error in resetAllState: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    @objc func resetSettings(_ sender: Any?) {
        settings.resetToDefaults()
    }

    /// Removes the system extension and agents for DuckDuckGo VPN.
    ///
    @objc func removeSystemExtensionAndAgents(_ sender: Any?) {
        Task { @MainActor in
            guard case .alertFirstButtonReturn = await NSAlert.removeSystemExtensionAndAgentsAlert().runModal() else { return }

            do {
                try await debugUtilities.removeSystemExtensionAndAgents()
            } catch {
                await NSAlert(error: error).runModal()
            }
        }
    }

    /// Removes the system extension and agents for DuckDuckGo VPN.
    ///
    @objc func removeVPNConfiguration(_ sender: Any?) {
        Task { @MainActor in
            guard case .alertFirstButtonReturn = await NSAlert.removeVPNConfigurationAlert().runModal() else { return }

            do {
                try await debugUtilities.removeVPNConfiguration()
            } catch {
                await NSAlert(error: error).runModal()
            }
        }
    }

    /// Removes the system extension and agents for DuckDuckGo VPN.
    ///
    @objc func restartAdapter(_ sender: Any?) {
        Task { @MainActor in
            do {
                try await debugUtilities.restartAdapter()
            } catch {
                await NSAlert(error: error).runModal()
            }
        }
    }

    /// Sends a test user notification.
    ///
    @objc func sendTestNotification(_ sender: Any?) {
        Task { @MainActor in
            do {
                try await debugUtilities.sendTestNotificationRequest()
            } catch {
                await NSAlert(error: error).runModal()
            }
        }
    }

    /// Prints feedback collector metadata to the console. This is to facilitate easier iteration of the metadata collector, without having to go through the feedback form flow every time.
    ///
    @objc func logFeedbackMetadataToConsole(_ sender: Any?) {
        Task { @MainActor in
            let collector = DefaultVPNMetadataCollector(accountManager: Application.appDelegate.subscriptionManager.accountManager)
            let metadata = await collector.collectMetadata()

            print(metadata.toPrettyPrintedJSON()!)
        }
    }

    /// Sets the selected server.
    ///
    @objc func setSelectedServer(_ menuItem: NSMenuItem) {
        let title = menuItem.title
        let selectedServer: VPNSettings.SelectedServer

        if title == "Automatic" {
            selectedServer = .automatic
        } else {
            let titleComponents = title.components(separatedBy: " ")
            selectedServer = .endpoint(titleComponents.first!)
        }

        settings.selectedServer = selectedServer
    }

    /// Expires the registration key immediately.
    ///
    @objc func expireRegistrationKeyNow(_ sender: Any?) {
        Task {
            try? await debugUtilities.expireRegistrationKeyNow()
        }
    }

    @objc func toggleRekeyingDisabled(_ sender: Any?) {
        settings.disableRekeying.toggle()
    }

    /// Sets the registration key validity.
    ///
    @objc func setRegistrationKeyValidity(_ menuItem: NSMenuItem) {
        guard let timeInterval = menuItem.representedObject as? TimeInterval else {
            settings.registrationKeyValidity = .automatic
            return
        }

        settings.registrationKeyValidity = .custom(timeInterval)
    }

    @objc func toggleEnforceRoutesAction(_ sender: Any?) {
        settings.enforceRoutes.toggle()

        Task {
            try await Task.sleep(interval: 0.1)
            try await debugUtilities.restartAdapter()
        }
    }

    @objc func toggleIncludeAllNetworks(_ sender: Any?) {
        settings.includeAllNetworks.toggle()

        Task {
            try await Task.sleep(interval: 0.1)
            try await debugUtilities.restartAdapter()
        }
    }

    @objc func toggleShouldExcludeLocalRoutes(_ sender: Any?) {
        settings.excludeLocalNetworks.toggle()

        Task {
            try await Task.sleep(interval: 0.1)
            try await debugUtilities.restartAdapter()
        }
    }

    @objc func openAppContainerInFinder(_ sender: Any?) {
        let containerURL = URL.sandboxApplicationSupportURL
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: containerURL.path)
    }

    // MARK: Populating Menu Items

    private func populateNetworkProtectionEnvironmentListMenuItems() {
        environmentMenu.items = [
            NSMenuItem(title: "⚠️ A staging subscription can be used for the staging VPN environment, a production subscription can be used for both", action: nil, target: nil),
            NSMenuItem(title: "⚠️ Please restart the browser after changing environment", action: nil, target: nil),
            NSMenuItem.separator(),
            NSMenuItem(title: "Production", action: #selector(setSelectedEnvironment(_:)), target: self, keyEquivalent: ""),
            NSMenuItem(title: "Staging", action: #selector(setSelectedEnvironment(_:)), target: self, keyEquivalent: ""),
        ]
    }

    @MainActor
    private func populateNetworkProtectionServerListMenuItems() async throws {
        let servers = try await NetworkProtectionDeviceManager.create().refreshServerList()

        preferredServerAutomaticItem.target = self
        if servers.isEmpty {
            preferredServerMenu.items = [preferredServerAutomaticItem]
        } else {
            preferredServerMenu.items = [preferredServerAutomaticItem, NSMenuItem.separator()] + servers.map({ server in
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
        registrationKeyValidityAutomaticItem.target = self
        if Self.registrationKeyValidityOptions.isEmpty {
            // Not likely to happen as it's hard-coded, but still...
            registrationKeyValidityMenu.items = [registrationKeyValidityAutomaticItem]
        } else {
            registrationKeyValidityMenu.items = [registrationKeyValidityAutomaticItem, NSMenuItem.separator()] + Self.registrationKeyValidityOptions.map { option in
                let menuItem = NSMenuItem(title: option.title,
                                          action: #selector(setRegistrationKeyValidity(_:)),
                                          target: self,
                                          keyEquivalent: "")

                menuItem.representedObject = option.validity
                return menuItem
            }
        }
#endif
    }

    func menuItem(title: String, action: Selector, representedObject: Any?) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        menuItem.representedObject = representedObject
        return menuItem
    }

    // MARK: - Menu State Update

    override func update() {
        updateEnvironmentMenu()
        updateExclusionsMenu()
        updatePreferredServerMenu()
        updateRekeyValidityMenu()
        updateNetworkProtectionMenuItemsState()
    }

    private func updateEnvironmentMenu() {
        let selectedEnvironment = settings.selectedEnvironment
        guard environmentMenu.items.count == 5 else { return }

        environmentMenu.items[3].state = selectedEnvironment == .production ? .on : .off
        environmentMenu.items[4].state = selectedEnvironment == .staging ? .on : .off
    }

    private func updatePreferredServerMenu() {
        let selectedServer = settings.selectedServer

        switch selectedServer {
        case .automatic:
            preferredServerMenu.items.first?.state = .on
        case .endpoint(let selectedServerName):
            preferredServerMenu.items.first?.state = .off

            // We're skipping the first two items because they're the automatic menu item and
            // the separator line.
            let serverItems = preferredServerMenu.items.dropFirst(2)

            for item in serverItems {
                if item.title.hasPrefix(selectedServerName) {
                    item.state = .on
                } else {
                    item.state = .off
                }
            }
        }
    }

    private func updateRekeyValidityMenu() {
        switch settings.registrationKeyValidity {
        case .automatic:
            registrationKeyValidityMenu.items.first?.state = .on
        case .custom(let timeInterval):
            registrationKeyValidityMenu.items.first?.state = .off

            // We're skipping the first two items because they're the automatic menu item and
            // the separator line.
            let serverItems = registrationKeyValidityMenu.items.dropFirst(2)

            for item in serverItems {
                if item.representedObject as? TimeInterval == timeInterval {
                    item.state = .on
                } else {
                    item.state = .off
                }
            }
        }
    }

    private func updateNetworkProtectionMenuItemsState() {
        shouldEnforceRoutesMenuItem.state = settings.enforceRoutes ? .on : .off
        shouldIncludeAllNetworksMenuItem.state = settings.includeAllNetworks ? .on : .off
        excludeLocalNetworksMenuItem.state = settings.excludeLocalNetworks ? .on : .off
        disableRekeyingMenuItem.state = settings.disableRekeying ? .on : .off
    }

    // MARK: - Exclusions

    private let dbpBackgroundAppIdentifier = Bundle.main.dbpBackgroundAgentBundleId
    private let ddgBrowserAppIdentifier = Bundle.main.bundleIdentifier!

    private func updateExclusionsMenu() {
        excludeDBPTrafficFromVPN.state = transparentProxySettings.isExcluding(appIdentifier: dbpBackgroundAppIdentifier) ? .on : .off
        excludeDDGBrowserTrafficFromVPN.state = transparentProxySettings.isExcluding(appIdentifier: ddgBrowserAppIdentifier) ? .on : .off
    }

    @objc private func toggleExcludeDBPBackgroundAgent() {
        transparentProxySettings.toggleExclusion(for: dbpBackgroundAppIdentifier)
    }

    @objc private func toggleExcludeDDGBrowser() {
        transparentProxySettings.toggleExclusion(for: ddgBrowserAppIdentifier)
    }

    // MARK: Environment

    @objc func setSelectedEnvironment(_ menuItem: NSMenuItem) {
        let title = menuItem.title
        let selectedEnvironment: VPNSettings.SelectedEnvironment

        if title == "Staging" {
            selectedEnvironment = .staging
        } else {
            selectedEnvironment = .production
        }

        settings.selectedEnvironment = selectedEnvironment

        Task {
            _ = try await NetworkProtectionDeviceManager.create().refreshServerList()
            try? await populateNetworkProtectionServerListMenuItems()

            settings.selectedServer = .automatic
        }
    }
}

#if DEBUG
#Preview {
    return MenuPreview(menu: NetworkProtectionDebugMenu())
}
#endif
