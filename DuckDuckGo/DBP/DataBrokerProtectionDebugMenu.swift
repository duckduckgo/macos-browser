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

    private var databaseBrowserWindowController: NSWindowController?

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
                NSMenuItem(title: "Run queued operations", action: #selector(DataBrokerProtectionDebugMenu.runQueuedOperations))
                    .targetting(self)

                NSMenuItem(title: "Run scan operations", action: #selector(DataBrokerProtectionDebugMenu.runScanOperations))
                    .targetting(self)

                NSMenuItem(title: "Run opt-out operations", action: #selector(DataBrokerProtectionDebugMenu.runScanOperations))
                    .targetting(self)
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
    }

    // MARK: - Menu functions

    @objc private func runQueuedOperations() {
        os_log("Running queued operations...", log: .dataBrokerProtection)
        DataBrokerProtectionManager.shared.scheduler.runQueuedOperations(showWebView: false) { error in
            if let error = error {
                os_log("Queued operations finished,  error: %{public}@", log: .dataBrokerProtection, error.localizedDescription)
            } else {
                os_log("Queued operations finished", log: .dataBrokerProtection)
            }
        }
    }

    @objc private func runScanOperations() {
        os_log("Running scan operations...", log: .dataBrokerProtection)
        DataBrokerProtectionManager.shared.scheduler.scanAllBrokers(showWebView: false) { error in
            if let error = error {
                os_log("Scan operations finished,  error: %{public}@", log: .dataBrokerProtection, error.localizedDescription)
            } else {
                os_log("Scan operations finished", log: .dataBrokerProtection)
            }
        }
    }

    @objc private func runOptoutOperations() {
        os_log("Running Optout operations...", log: .dataBrokerProtection)
        DataBrokerProtectionManager.shared.scheduler.optOutAllBrokers(showWebView: false) { error in
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
