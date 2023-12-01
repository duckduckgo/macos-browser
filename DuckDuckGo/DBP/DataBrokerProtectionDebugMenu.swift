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

@MainActor
final class DataBrokerProtectionDebugMenu: NSMenu {

    private let waitlistTokenItem = NSMenuItem(title: "Waitlist Token:")
    private let waitlistTimestampItem = NSMenuItem(title: "Waitlist Timestamp:")
    private let waitlistInviteCodeItem = NSMenuItem(title: "Waitlist Invite Code:")
    private let waitlistTermsAndConditionsAcceptedItem = NSMenuItem(title: "T&C Accepted:")
    private let waitlistBypassItem = NSMenuItem(title: "Bypass Waitlist", action: #selector(DataBrokerProtectionDebugMenu.toggleBypassWaitlist))

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

#endif
