//
//  DataBrokerProtectionDebugMenu.swift
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

#if DBP

import DataBrokerProtection
import Foundation
import AppKit
import Common
import LoginItems

@MainActor
final class DataBrokerProtectionDebugMenu: NSMenu {

    private let waitlistTokenItem = NSMenuItem(title: "Waitlist Token:")
    private let waitlistTimestampItem = NSMenuItem(title: "Waitlist Timestamp:")
    private let waitlistInviteCodeItem = NSMenuItem(title: "Waitlist Invite Code:")
    private let waitlistTermsAndConditionsAcceptedItem = NSMenuItem(title: "T&C Accepted:")
    private let waitlistBypassItem = NSMenuItem(title: "Bypass Waitlist", action: #selector(DataBrokerProtectionDebugMenu.toggleBypassWaitlist))

    private let productionURLMenuItem = NSMenuItem(title: "Use Production URL", action: #selector(DataBrokerProtectionDebugMenu.useWebUIProductionURL))

    private let customURLMenuItem = NSMenuItem(title: "Use Custom URL", action: #selector(DataBrokerProtectionDebugMenu.useWebUICustomURL))

    private var databaseBrowserWindowController: NSWindowController?
    private let customURLLabelMenuItem = NSMenuItem(title: "")

    private let webUISettings = DataBrokerProtectionWebUIURLSettings(.dbp)

    // swiftlint:disable:next function_body_length
    init() {
        super.init(title: "Personal Information Removal")

        buildItems {
            NSMenuItem(title: "Waitlist") {
                NSMenuItem(title: "Reset Waitlist State", action: #selector(DataBrokerProtectionDebugMenu.resetWaitlistState))
                    .targetting(self)
                NSMenuItem(title: "Reset T&C Acceptance", action: #selector(DataBrokerProtectionDebugMenu.resetTermsAndConditionsAcceptance))
                    .targetting(self)

                NSMenuItem(title: "Send Notification", action: #selector(DataBrokerProtectionDebugMenu.sendWaitlistAvailableNotification))
                    .targetting(self)

                NSMenuItem(title: "Fetch Invite Code", action: #selector(DataBrokerProtectionDebugMenu.fetchInviteCode))
                    .targetting(self)

                NSMenuItem.separator()

                waitlistBypassItem
                    .targetting(self)

                NSMenuItem.separator()

                waitlistTokenItem
                waitlistTimestampItem
                waitlistInviteCodeItem
                waitlistTermsAndConditionsAcceptedItem
            }

            NSMenuItem(title: "Background Agent") {
                NSMenuItem(title: "Enable", action: #selector(DataBrokerProtectionDebugMenu.backgroundAgentEnable))
                    .targetting(self)

                NSMenuItem(title: "Disable", action: #selector(DataBrokerProtectionDebugMenu.backgroundAgentDisable))
                    .targetting(self)

                NSMenuItem(title: "Restart", action: #selector(DataBrokerProtectionDebugMenu.backgroundAgentRestart))
                    .targetting(self)
            }

            NSMenuItem(title: "Operations") {
                NSMenuItem(title: "Hidden WebView") {
                    menuItem(withTitle: "Run queued operations",
                             action: #selector(DataBrokerProtectionDebugMenu.runQueuedOperations(_:)),
                             representedObject: false)

                    menuItem(withTitle: "Run scan operations",
                             action: #selector(DataBrokerProtectionDebugMenu.runScanOperations(_:)),
                             representedObject: false)

                    menuItem(withTitle: "Run opt-out operations",
                             action: #selector(DataBrokerProtectionDebugMenu.runOptoutOperations(_:)),
                             representedObject: false)
                }

                NSMenuItem(title: "Visible WebView") {
                    menuItem(withTitle: "Run queued operations",
                             action: #selector(DataBrokerProtectionDebugMenu.runQueuedOperations(_:)),
                             representedObject: true)

                    menuItem(withTitle: "Run scan operations",
                             action: #selector(DataBrokerProtectionDebugMenu.runScanOperations(_:)),
                             representedObject: true)

                    menuItem(withTitle: "Run opt-out operations",
                             action: #selector(DataBrokerProtectionDebugMenu.runOptoutOperations(_:)),
                             representedObject: true)
                }
            }

            NSMenuItem(title: "Web UI") {
                productionURLMenuItem.targetting(self)
                customURLMenuItem.targetting(self)

                NSMenuItem.separator()

                NSMenuItem(title: "Set Custom URL", action: #selector(DataBrokerProtectionDebugMenu.setWebUICustomURL))
                    .targetting(self)
                NSMenuItem(title: "Reset Custom URL", action: #selector(DataBrokerProtectionDebugMenu.resetCustomURL))
                    .targetting(self)

                customURLLabelMenuItem
            }

            NSMenuItem.separator()

            NSMenuItem(title: "Show DB Browser", action: #selector(DataBrokerProtectionDebugMenu.showDatabaseBrowser))
                .targetting(self)
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Menu State Update

    override func update() {
        updateWaitlistItems()
        updateWebUIMenuItemsState()
    }

    // MARK: - Menu functions

    @objc private func useWebUIProductionURL() {
        webUISettings.setURLType(.production)
    }

    @objc private func useWebUICustomURL() {
        webUISettings.setURLType(.custom)
    }

    @objc private func resetCustomURL() {
        webUISettings.setURLType(.production)
        webUISettings.setCustomURL("")
    }

    @objc private func setWebUICustomURL() {
        showCustomURLAlert { [weak self] value in
            if let url = value {
                let modifiedURL = url.hasPrefix("https://") ? url : "https://\(url)"
                self?.webUISettings.setCustomURL(modifiedURL)
            }
        }
    }

    @objc private func runQueuedOperations(_ sender: NSMenuItem) {
        os_log("Running queued operations...", log: .dataBrokerProtection)
        let showWebView = sender.representedObject as? Bool ?? false

        DataBrokerProtectionManager.shared.scheduler.runQueuedOperations(showWebView: showWebView) { error in
            if let error = error {
                os_log("Queued operations finished,  error: %{public}@", log: .dataBrokerProtection, error.localizedDescription)
            } else {
                os_log("Queued operations finished", log: .dataBrokerProtection)
            }
        }
    }

    @objc private func runScanOperations(_ sender: NSMenuItem) {
        os_log("Running scan operations...", log: .dataBrokerProtection)
        let showWebView = sender.representedObject as? Bool ?? false

        DataBrokerProtectionManager.shared.scheduler.scanAllBrokers(showWebView: showWebView) { error in
            if let error = error {
                os_log("Scan operations finished,  error: %{public}@", log: .dataBrokerProtection, error.localizedDescription)
            } else {
                os_log("Scan operations finished", log: .dataBrokerProtection)
            }
        }
    }

    @objc private func runOptoutOperations(_ sender: NSMenuItem) {
        os_log("Running Optout operations...", log: .dataBrokerProtection)
        let showWebView = sender.representedObject as? Bool ?? false

        DataBrokerProtectionManager.shared.scheduler.optOutAllBrokers(showWebView: showWebView) { error in
            if let error = error {
                os_log("Optout operations finished,  error: %{public}@", log: .dataBrokerProtection, error.localizedDescription)
            } else {
                os_log("Optout operations finished", log: .dataBrokerProtection)
            }
        }
    }

    @objc private func backgroundAgentRestart() {
        LoginItemsManager().restartLoginItems([LoginItem.dbpBackgroundAgent], log: .dbp)
    }

    @objc private func backgroundAgentDisable() {
        LoginItemsManager().disableLoginItems([LoginItem.dbpBackgroundAgent])
    }

    @objc private func backgroundAgentEnable() {
        LoginItemsManager().enableLoginItems([LoginItem.dbpBackgroundAgent], log: .dbp)
    }

    @objc private func showDatabaseBrowser() {
        let viewController = DataBrokerDatabaseBrowserViewController()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered,
                              defer: false)

        window.contentViewController = viewController
        window.minSize = NSSize(width: 500, height: 400)
        window.center()
        databaseBrowserWindowController = NSWindowController(window: window)
        databaseBrowserWindowController?.showWindow(nil)
        window.delegate = self
    }

    @objc private func resetWaitlistState() {
        DataBrokerProtectionWaitlist().waitlistStorage.deleteWaitlistState()
        KeychainAuthenticationData().reset()

        UserDefaults().removeObject(forKey: UserDefaultsWrapper<Bool>.Key.shouldShowDBPWaitlistInvitedCardUI.rawValue)
        UserDefaults().removeObject(forKey: UserDefaultsWrapper<Bool>.Key.dataBrokerProtectionTermsAndConditionsAccepted.rawValue)
        NotificationCenter.default.post(name: .dataBrokerProtectionWaitlistAccessChanged, object: nil)
        os_log("DBP waitlist state cleaned", log: .dataBrokerProtection)
    }

    @objc private func toggleBypassWaitlist() {
        DefaultDataBrokerProtectionFeatureVisibility.bypassWaitlist.toggle()
    }

    @objc private func resetTermsAndConditionsAcceptance() {
        UserDefaults().removeObject(forKey: UserDefaultsWrapper<Bool>.Key.dataBrokerProtectionTermsAndConditionsAccepted.rawValue)
        NotificationCenter.default.post(name: .dataBrokerProtectionWaitlistAccessChanged, object: nil)
        os_log("DBP waitlist terms and conditions cleaned", log: .dataBrokerProtection)
    }

    @objc private func sendWaitlistAvailableNotification() {
        DataBrokerProtectionWaitlist().sendInviteCodeAvailableNotification(completion: nil)

        os_log("DBP waitlist notification sent", log: .dataBrokerProtection)
    }

    @objc private func fetchInviteCode() {
        os_log("Fetching invite code...", log: .dataBrokerProtection)

        Task {
            try? await DataBrokerProtectionWaitlist().redeemDataBrokerProtectionInviteCodeIfAvailable()
        }
    }

    // MARK: - Utility Functions

    func showCustomURLAlert(callback: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Enter URL"
        alert.addButton(withTitle: "Accept")
        alert.addButton(withTitle: "Cancel")

        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = inputTextField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            callback(inputTextField.stringValue)
        } else {
            callback(nil)
        }
    }

    private func updateWebUIMenuItemsState() {
        productionURLMenuItem.state = webUISettings.selectedURLType == .custom ? .off : .on
        customURLMenuItem.state = webUISettings.selectedURLType == .custom ? .on : .off

        customURLLabelMenuItem.title = "Custom URL: [\(webUISettings.customURL ?? "")]"
    }

    func menuItem(withTitle title: String, action: Selector, representedObject: Any?) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        menuItem.representedObject = representedObject
        return menuItem
    }

    private func updateWaitlistItems() {
        let waitlistStorage = WaitlistKeychainStore(waitlistIdentifier: DataBrokerProtectionWaitlist.identifier, keychainAppGroup: Bundle.main.appGroup(bundle: .dbp))
        waitlistTokenItem.title = "Waitlist Token: \(waitlistStorage.getWaitlistToken() ?? "N/A")"
        waitlistInviteCodeItem.title = "Waitlist Invite Code: \(waitlistStorage.getWaitlistInviteCode() ?? "N/A")"

        if let timestamp = waitlistStorage.getWaitlistTimestamp() {
            waitlistTimestampItem.title = "Waitlist Timestamp: \(String(describing: timestamp))"
        } else {
            waitlistTimestampItem.title = "Waitlist Timestamp: N/A"
        }

        let accepted = UserDefaults().bool(forKey: UserDefaultsWrapper<Bool>.Key.dataBrokerProtectionTermsAndConditionsAccepted.rawValue)
        waitlistTermsAndConditionsAcceptedItem.title = "T&C Accepted: \(accepted ? "Yes" : "No")"

        waitlistBypassItem.state = DefaultDataBrokerProtectionFeatureVisibility.bypassWaitlist ? .on : .off
    }
}

extension DataBrokerProtectionDebugMenu: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        databaseBrowserWindowController = nil
    }
}

#endif
