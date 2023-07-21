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

import Common
import Foundation
import NetworkProtection

/// Controller for the Network Protection debug menu.
///
@objc
final class NetworkProtectionDebugMenuController: NSObject {

    // MARK: - Debug Logic

#if NETWORK_PROTECTION
    private let debugUtilities = NetworkProtectionDebugUtilities()
#endif

    // MARK: - Debug Menu IBActions

    /// Resets all state for NetworkProtection.
    ///
    @IBAction
    func resetAllState(_ sender: Any?) {
#if NETWORK_PROTECTION
        Task { @MainActor in
            guard case .alertFirstButtonReturn = await NSAlert.resetNetworkProtectionAlert().runModal() else { return }

            do {
                try await debugUtilities.resetAllState()
            } catch {
                await NSAlert(error: error).runModal()
            }
        }
#endif
    }

    /// Removes the system extension and agents for Network Protection.
    ///
    @IBAction
    func removeSystemExtensionAndAgents(_ sender: Any?) {
#if NETWORK_PROTECTION
        Task { @MainActor in
            guard case .alertFirstButtonReturn = await NSAlert.removeSystemExtensionAndAgentsAlert().runModal() else { return }

            do {
                try await debugUtilities.removeSystemExtensionAndAgents()
            } catch {
                await NSAlert(error: error).runModal()
            }
        }
#endif
    }

    /// Sends a test user notification.
    ///
    @IBAction
    func sendTestNotification(_ sender: Any?) {
#if NETWORK_PROTECTION
        Task { @MainActor in
            do {
                try await debugUtilities.sendTestNotificationRequest()
            } catch {
                await NSAlert(error: error).runModal()
            }
        }
#endif
    }

    /// Sets the selected server.
    ///
    @IBAction
    func setSelectedServer(_ sender: Any?) {
#if NETWORK_PROTECTION
        guard let title = (sender as? NSMenuItem)?.title else {
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
#endif
    }

    /// Expires the registration key immediately.
    ///
    @IBAction
    func expireRegistrationKeyNow(_ sender: Any?) {
#if NETWORK_PROTECTION
        Task {
            try? await debugUtilities.expireRegistrationKeyNow()
        }
#endif
    }

    /// Sets the registration key validity.
    ///
    @IBAction
    func setRegistrationKeyValidity(_ sender: Any?) {
#if NETWORK_PROTECTION
        guard let menuItem = sender as? NSMenuItem else {
            assertionFailure("\(#function): Failed to cast sender to NSMenuItem")
            return
        }

        // nil means automatic
        let validity = menuItem.representedObject as? TimeInterval

        Task {
            do {
                try await debugUtilities.setRegistrationKeyValidity(validity)
            } catch {
                assertionFailure("Could not override the key validity due to an error: \(error.localizedDescription)")
                os_log("Could not override the key validity due to an error: %{public}@", log: .networkProtection, type: .error, error.localizedDescription)
            }
        }
#endif
    }

    /// Simulates a controller failure the next time Network Protection is started.
    ///
    @IBAction
    func simulateControllerFailure(_ sender: Any?) {
#if NETWORK_PROTECTION
        guard let menuItem = sender as? NSMenuItem else {
            assertionFailure("\(#function): Failed to cast sender to NSMenuItem")
            return
        }

        if menuItem.state == .on {
            menuItem.state = .off
        } else {
            menuItem.state = .on
        }

        NetworkProtectionTunnelController.simulationOptions.setEnabled(menuItem.state == .on, option: .controllerFailure)
#endif
    }

    /// Simulates a tunnel failure the next time Network Protection is started.
    ///
    @IBAction
    func simulateTunnelFailure(_ sender: Any?) {
#if NETWORK_PROTECTION
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
#endif
    }
}

extension NetworkProtectionDebugMenuController: NSMenuItemValidation {

    // swiftlint:disable:next cyclomatic_complexity
    // swiftlint:disable:next function_body_length
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(NetworkProtectionDebugMenuController.setSelectedServer(_:)):
#if NETWORK_PROTECTION
            let selectedServerName = debugUtilities.selectedServerName()

            switch menuItem.title {
            case "Automatic":
                menuItem.state = selectedServerName == nil ? .on : .off
            default:
                guard let selectedServerName = selectedServerName else {
                    menuItem.state = .off
                    break
                }

                menuItem.state = (menuItem.title.hasPrefix("\(selectedServerName) ")) ? .on : .off
            }

            return true
#else
            return false
#endif

        case #selector(NetworkProtectionDebugMenuController.expireRegistrationKeyNow(_:)):
            return true

        case #selector(NetworkProtectionDebugMenuController.setRegistrationKeyValidity(_:)):
#if NETWORK_PROTECTION
            let selectedValidity = debugUtilities.registrationKeyValidity()

            switch menuItem.title {
            case "Automatic":
                menuItem.state = selectedValidity == nil ? .on : .off
            default:
                guard let selectedValidity = selectedValidity,
                      let menuItemValidity = menuItem.representedObject as? TimeInterval,
                      selectedValidity == menuItemValidity else {

                    menuItem.state = .off
                    break
                }

                menuItem.state =  .on
            }

            return true
#else
            return false
#endif

        case #selector(NetworkProtectionDebugMenuController.simulateControllerFailure(_:)):
#if NETWORK_PROTECTION
            menuItem.state = NetworkProtectionTunnelController.simulationOptions.isEnabled(.controllerFailure) ? .on : .off
            return true
#else
            return false
#endif

        case #selector(NetworkProtectionDebugMenuController.simulateTunnelFailure(_:)):
#if NETWORK_PROTECTION
            menuItem.state = NetworkProtectionTunnelController.simulationOptions.isEnabled(.tunnelFailure) ? .on : .off
            return true
#else
            return false
#endif

        default:
            return true
        }
    }
}
