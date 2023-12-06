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

#if NETWORK_PROTECTION

import AppKit
import Common
import Foundation
import NetworkProtection
import SwiftUI

/// Controller for the Network Protection debug menu.
///
@MainActor
final class NetworkProtectionDebugMenu: NSMenu {

    private let environmentMenu = NSMenu()

    private let preferredServerMenu: NSMenu
    private let preferredServerAutomaticItem = NSMenuItem(title: "Automatic", action: #selector(NetworkProtectionDebugMenu.setSelectedServer))

    private let registrationKeyValidityMenu: NSMenu
    private let registrationKeyValidityAutomaticItem = NSMenuItem(title: "Automatic", action: #selector(NetworkProtectionDebugMenu.setRegistrationKeyValidity))

    private let resetToDefaults = NSMenuItem(title: "Reset Settings to defaults", action: #selector(NetworkProtectionDebugMenu.resetSettings))

    private let exclusionsMenu = NSMenu()

    private let shouldEnforceRoutesMenuItem = NSMenuItem(title: "Kill Switch (enforceRoutes)", action: #selector(NetworkProtectionDebugMenu.toggleEnforceRoutesAction))
    private let shouldIncludeAllNetworksMenuItem = NSMenuItem(title: "includeAllNetworks", action: #selector(NetworkProtectionDebugMenu.toggleIncludeAllNetworks))
    private let connectOnLogInMenuItem = NSMenuItem(title: "Connect on Log In", action: #selector(NetworkProtectionDebugMenu.toggleConnectOnLogInAction))
    private let disableRekeyingMenuItem = NSMenuItem(title: "Disable Rekeying", action: #selector(NetworkProtectionDebugMenu.toggleRekeyingDisabled))

    private let excludeLocalNetworksMenuItem = NSMenuItem(title: "excludeLocalNetworks", action: #selector(NetworkProtectionDebugMenu.toggleShouldExcludeLocalRoutes))

    private let enterWaitlistInviteCodeItem = NSMenuItem(title: "Enter Waitlist Invite Code", action: #selector(NetworkProtectionDebugMenu.showNetworkProtectionInviteCodePrompt))

    private let waitlistTokenItem = NSMenuItem(title: "Waitlist Token:")
    private let waitlistTimestampItem = NSMenuItem(title: "Waitlist Timestamp:")
    private let waitlistInviteCodeItem = NSMenuItem(title: "Waitlist Invite Code:")
    private let waitlistTermsAndConditionsAcceptedItem = NSMenuItem(title: "T&C Accepted:")

    // swiftlint:disable:next function_body_length
    init() {
        preferredServerMenu = NSMenu { [preferredServerAutomaticItem] in
            preferredServerAutomaticItem
        }
        registrationKeyValidityMenu = NSMenu { [registrationKeyValidityAutomaticItem] in
            registrationKeyValidityAutomaticItem
        }
        super.init(title: "Network Protection")

        buildItems {
            NSMenuItem(title: "Reset") {
                NSMenuItem(title: "Reset All State Keeping Invite", action: #selector(NetworkProtectionDebugMenu.resetAllKeepingInvite))
                    .targetting(self)

                NSMenuItem(title: "Reset All State", action: #selector(NetworkProtectionDebugMenu.resetAllState))
                    .targetting(self)

                resetToDefaults
                    .targetting(self)

                NSMenuItem(title: "Remove System Extension and Login Items", action: #selector(NetworkProtectionDebugMenu.removeSystemExtensionAndAgents))
                    .targetting(self)

                NSMenuItem(title: "Reset Remote Messages", action: #selector(NetworkProtectionDebugMenu.resetNetworkProtectionRemoteMessages))
                    .targetting(self)
            }

            NSMenuItem.separator()

            connectOnLogInMenuItem
                .targetting(self)
            shouldEnforceRoutesMenuItem
                .targetting(self)
            NSMenuItem(title: "Excluded Routes").submenu(exclusionsMenu)
            NSMenuItem.separator()

            NSMenuItem(title: "Send Test Notification", action: #selector(NetworkProtectionDebugMenu.sendTestNotification))
                .targetting(self)

            NSMenuItem(title: "Onboarding")
                .submenu(NetworkProtectionOnboardingMenu())

            NSMenuItem(title: "Environment")
                .submenu(environmentMenu)

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

            NSMenuItem(title: "Override NetP Activation Date") {
                NSMenuItem(title: "Reset Activation Date", action: #selector(NetworkProtectionDebugMenu.resetNetworkProtectionActivationDate))
                    .targetting(self)
                NSMenuItem(title: "Set Activation Date to Now", action: #selector(NetworkProtectionDebugMenu.overrideNetworkProtectionActivationDateToNow))
                    .targetting(self)
                NSMenuItem(title: "Set Activation Date to 5 Days Ago", action: #selector(NetworkProtectionDebugMenu.overrideNetworkProtectionActivationDateTo5DaysAgo))
                    .targetting(self)
                NSMenuItem(title: "Set Activation Date to 10 Days Ago", action: #selector(NetworkProtectionDebugMenu.overrideNetworkProtectionActivationDateTo10DaysAgo))
                    .targetting(self)
            }

            NSMenuItem(title: "NetP Waitlist") {
                NSMenuItem(title: "Reset Waitlist State", action: #selector(NetworkProtectionDebugMenu.resetNetworkProtectionWaitlistState))
                    .targetting(self)
                NSMenuItem(title: "Reset T&C Acceptance", action: #selector(NetworkProtectionDebugMenu.resetNetworkProtectionTermsAndConditionsAcceptance))
                    .targetting(self)

                enterWaitlistInviteCodeItem
                    .targetting(self)

                NSMenuItem(title: "Send Waitlist Notification", action: #selector(NetworkProtectionDebugMenu.sendNetworkProtectionWaitlistAvailableNotification))
                    .targetting(self)
                NSMenuItem.separator()

                waitlistTokenItem
                waitlistTimestampItem
                waitlistInviteCodeItem
                waitlistTermsAndConditionsAcceptedItem
            }

            NSMenuItem(title: "NetP Waitlist Feature Flag Overrides")
                .submenu(NetworkProtectionWaitlistFeatureFlagOverridesMenu())

            NSMenuItem.separator()

            NSMenuItem(title: "Kill Switch (alternative approach)") {
                shouldIncludeAllNetworksMenuItem
                    .targetting(self)
                excludeLocalNetworksMenuItem
                    .targetting(self)
            }

            NSMenuItem(title: "Open App Container in Finder", action: #selector(NetworkProtectionDebugMenu.openAppContainerInFinder))
                .targetting(self)
        }

        preferredServerMenu.autoenablesItems = false
        populateNetworkProtectionEnvironmentListMenuItems()
        populateNetworkProtectionServerListMenuItems()
        populateNetworkProtectionRegistrationKeyValidityMenuItems()

        exclusionsMenu.delegate = self
        exclusionsMenu.autoenablesItems = false
        populateExclusionsMenuItems()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Tunnel Settings

    private let settings = VPNSettings(defaults: .netP)

    // MARK: - Debug Logic

    private let debugUtilities = NetworkProtectionDebugUtilities()

    // MARK: - Debug Menu Actions

    /// Resets all state for NetworkProtection.
    ///
    @objc func resetAllState(_ sender: Any?) {
        Task { @MainActor in
            guard case .alertFirstButtonReturn = await NSAlert.resetNetworkProtectionAlert().runModal() else { return }
            await debugUtilities.resetAllState(keepAuthToken: false)
        }
    }

    /// Resets all state for NetworkProtection.
    ///
    @objc func resetAllKeepingInvite(_ sender: Any?) {
        Task { @MainActor in
            guard case .alertFirstButtonReturn = await NSAlert.resetNetworkProtectionAlert().runModal() else { return }
            await debugUtilities.resetAllState(keepAuthToken: true)
        }
    }

    @objc func resetSettings(_ sender: Any?) {
        settings.resetToDefaults()
    }

    /// Removes the system extension and agents for Network Protection.
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
    }

    @objc func toggleIncludeAllNetworks(_ sender: Any?) {
        settings.includeAllNetworks.toggle()
    }

    @objc func toggleShouldExcludeLocalRoutes(_ sender: Any?) {
        settings.excludeLocalNetworks.toggle()
    }

    @objc func toggleConnectOnLogInAction(_ sender: Any?) {
        // Temporarily disabled: https://app.asana.com/0/0/1205766100762904/f
    }

    @objc func toggleExclusionAction(_ sender: NSMenuItem) {
        // Temporarily disabled: https://app.asana.com/0/0/1205766100762904/f
        /*
        guard let addressRange = sender.representedObject as? String else {
            assertionFailure("Unexpected representedObject")
            return
        }

        NetworkProtectionTunnelController().setExcludedRoute(addressRange, enabled: sender.state == .off)*/
    }

    @objc func openAppContainerInFinder(_ sender: Any?) {
        let containerURL = URL.sandboxApplicationSupportURL
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: containerURL.path)
    }

    // MARK: Populating Menu Items

    private func populateNetworkProtectionEnvironmentListMenuItems() {
        environmentMenu.items = [
            NSMenuItem(title: "Production", action: #selector(setSelectedEnvironment(_:)), target: self, keyEquivalent: ""),
            NSMenuItem(title: "Staging", action: #selector(setSelectedEnvironment(_:)), target: self, keyEquivalent: ""),
        ]
    }

    private func populateNetworkProtectionServerListMenuItems() {
        let networkProtectionServerStore = NetworkProtectionServerListFileSystemStore(errorEvents: nil)
        let servers = (try? networkProtectionServerStore.storedNetworkProtectionServerList()) ?? []

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

    private func populateExclusionsMenuItems() {
        exclusionsMenu.removeAllItems()

        for item in settings.excludedRoutes {
            let menuItem: NSMenuItem
            switch item {
            case .section(let title):
                menuItem = NSMenuItem(title: title, action: nil, target: nil)
                menuItem.isEnabled = false

            case .range(let range, let description):
                menuItem = NSMenuItem(title: "\(range)\(description != nil ? " (\(description!))" : "")",
                                      action: #selector(toggleExclusionAction),
                                      target: self,
                                      representedObject: range.stringRepresentation)
            }
            exclusionsMenu.addItem(menuItem)
        }

        // Only allow testers to enter a custom code if they're on the waitlist, to simulate the correct path through the flow
        let waitlist = NetworkProtectionWaitlist()
        enterWaitlistInviteCodeItem.isEnabled = waitlist.waitlistStorage.isOnWaitlist || waitlist.waitlistStorage.isInvited

    }

    // MARK: - Menu State Update

    override func update() {
        updateEnvironmentMenu()
        updatePreferredServerMenu()
        updateRekeyValidityMenu()
        updateNetworkProtectionMenuItemsState()
        updateNetworkProtectionItems()
    }

    private func updateEnvironmentMenu() {
        let selectedEnvironment = settings.selectedEnvironment

        switch selectedEnvironment {
        case .production:
            environmentMenu.items.first?.state = .on
            environmentMenu.items.last?.state = .off
        case .staging:
            environmentMenu.items.first?.state = .off
            environmentMenu.items.last?.state = .on
        }
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

    private func updateNetworkProtectionItems() {
        let waitlistStorage = WaitlistKeychainStore(waitlistIdentifier: NetworkProtectionWaitlist.identifier, keychainAppGroup: NetworkProtectionWaitlist.keychainAppGroup)
        waitlistTokenItem.title = "Waitlist Token: \(waitlistStorage.getWaitlistToken() ?? "N/A")"
        waitlistInviteCodeItem.title = "Waitlist Invite Code: \(waitlistStorage.getWaitlistInviteCode() ?? "N/A")"

        if let timestamp = waitlistStorage.getWaitlistTimestamp() {
            waitlistTimestampItem.title = "Waitlist Timestamp: \(String(describing: timestamp))"
        } else {
            waitlistTimestampItem.title = "Waitlist Timestamp: N/A"
        }

        let accepted = UserDefaults().bool(forKey: UserDefaultsWrapper<Bool>.Key.networkProtectionTermsAndConditionsAccepted.rawValue)
        waitlistTermsAndConditionsAcceptedItem.title = "T&C Accepted: \(accepted ? "Yes" : "No")"
    }

    // MARK: Waitlist

    @objc func sendNetworkProtectionWaitlistAvailableNotification(_ sender: Any?) {
        NetworkProtectionWaitlist().sendInviteCodeAvailableNotification(completion: nil)
    }

    @objc func resetNetworkProtectionActivationDate(_ sender: Any?) {
        overrideNetworkProtectionActivationDate(to: nil)
    }

    @objc func resetNetworkProtectionRemoteMessages(_ sender: Any?) {
        DefaultNetworkProtectionRemoteMessagingStorage().removeStoredAndDismissedMessages()
        DefaultNetworkProtectionRemoteMessaging(minimumRefreshInterval: 0).resetLastRefreshTimestamp()
    }

    @objc func overrideNetworkProtectionActivationDateToNow(_ sender: Any?) {
        overrideNetworkProtectionActivationDate(to: Date())
    }

    @objc func overrideNetworkProtectionActivationDateTo5DaysAgo(_ sender: Any?) {
        overrideNetworkProtectionActivationDate(to: Date.daysAgo(5))
    }

    @objc func overrideNetworkProtectionActivationDateTo10DaysAgo(_ sender: Any?) {
        overrideNetworkProtectionActivationDate(to: Date.daysAgo(10))
    }

    private func overrideNetworkProtectionActivationDate(to date: Date?) {
        let store = DefaultWaitlistActivationDateStore()

        if let date {
            store.updateActivationDate(date)
        } else {
            store.removeDates()
        }
    }

    @objc func resetNetworkProtectionWaitlistState(_ sender: Any?) {
        NetworkProtectionWaitlist().waitlistStorage.deleteWaitlistState()
        UserDefaults().removeObject(forKey: UserDefaultsWrapper<Bool>.Key.networkProtectionTermsAndConditionsAccepted.rawValue)
        UserDefaults().removeObject(forKey: UserDefaultsWrapper<Bool>.Key.networkProtectionWaitlistSignUpPromptDismissed.rawValue)
        NotificationCenter.default.post(name: .networkProtectionWaitlistAccessChanged, object: nil)
    }

    @objc func resetNetworkProtectionTermsAndConditionsAcceptance(_ sender: Any?) {
        UserDefaults().removeObject(forKey: UserDefaultsWrapper<Bool>.Key.networkProtectionTermsAndConditionsAccepted.rawValue)
        NotificationCenter.default.post(name: .networkProtectionWaitlistAccessChanged, object: nil)
    }

    @objc func showNetworkProtectionInviteCodePrompt(_ sender: Any?) {
        let code = getInviteCode()

        Task {
            do {
                let redeemer = NetworkProtectionCodeRedemptionCoordinator()
                try await redeemer.redeem(code)
                NetworkProtectionWaitlist().waitlistStorage.store(inviteCode: code)
                NotificationCenter.default.post(name: .networkProtectionWaitlistAccessChanged, object: nil)
            } catch {
                // Do nothing here, this is just a debug menu
            }
        }
    }

    private func getInviteCode() -> String {
        let alert = NSAlert()
        alert.addButton(withTitle: "Use Invite Code")
        alert.addButton(withTitle: "Cancel")
        alert.messageText = "Enter Invite Code"
        alert.informativeText = "Please grab a Network Protection invite code from Asana and enter it here."

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = textField

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            return textField.stringValue
        } else {
            return ""
        }
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
            await MainActor.run {
                populateNetworkProtectionServerListMenuItems()
            }
            settings.selectedServer = .automatic
        }
    }
}

extension NetworkProtectionDebugMenu: NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        // Temporarily disabled: https://app.asana.com/0/0/1205766100762904/f
        /*
        if menu === exclusionsMenu {
            let controller = NetworkProtectionTunnelController()
            for item in menu.items {
                guard let route = item.representedObject as? String else { continue }
                item.state = controller.isExcludedRouteEnabled(route) ? .on : .off
                // TO BE fixed: see NetworkProtectionTunnelController.excludedRoutes()
                item.isEnabled = !(controller.shouldEnforceRoutes && route == "10.0.0.0/8")
            }
        }
         */
    }
}

#if DEBUG
#Preview {
    return MenuPreview(menu: NetworkProtectionDebugMenu())
}
#endif

#endif
