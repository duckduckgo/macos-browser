//
//  UserText+NetworkProtection.swift
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

import Foundation

extension UserText {

    static let networkProtectionTunnelName = NSLocalizedString("network.protection.tunnel.name", value: "DuckDuckGo Network Protection", comment: "The name of the NetP VPN that will be visible in the system to the user")
    static let networkProtection = NSLocalizedString("network.protection", value: "Network Protection", comment: "Menu item for opening Network Protection")

    // MARK: - Configuration

    static let networkProtectionPleaseReboot = NSLocalizedString("network.protection.configuration.please-reboot", value: "Please reboot to activate Network Protection", comment: "Text for a label in the Network Protection popover, used in situations where the device needs to be rebooted after the extension was installed")

    private static let networkProtectionSystemSettingsLegacy = NSLocalizedString("network.protection.configuration.system-settings.legacy", value: "Go to Security & Privacy in System Preferences to allow Network Protection to activate", comment: "Text for a label in the Network Protection popover, displayed after attempting to enable Network Protection for the first time while using macOS 12 and below")
    private static let networkProtectionSystemSettingsModern = NSLocalizedString("network.protection.configuration.system-settings.modern", value: "Go to Privacy & Security in System Settings to allow Network Protection to activate", comment: "Text for a label in the Network Protection popover, displayed after attempting to enable Network Protection for the first time while using macOS 13 and above")

    static var networkProtectionSystemSettings: String {
        if #available(macOS 13.0, *) {
            return networkProtectionSystemSettingsModern
        } else {
            return networkProtectionSystemSettingsLegacy
        }
    }

    // MARK: - Navigation Bar

    static let networkProtectionButtonTooltip = NSLocalizedString("network.protection.status.button.tooltip", value: "Network Protection", comment: "The tooltip for NetP's nav bar button")

    // MARK: - Invite Code

    static let networkProtectionInviteDialogTitle = NSLocalizedString("network.protection.invite.dialog.title", value: "You've unlocked a beta feature!", comment: "Title for the network protection invite dialog")
    static let networkProtectionInviteDialogMessage = NSLocalizedString("network.protection.invite.dialog.message", value: "Enter your invite code to get started.", comment: "Message for the network protection invite dialog")
    static let networkProtectionInviteFieldPrompt = NSLocalizedString("network.protection.invite.field.prompt", value: "Code", comment: "Prompt for the network protection invite code text field")
    static let networkProtectionInviteSuccessTitle = NSLocalizedString("network.protection.invite.success.title", value: "Success! You’re in.", comment: "Title for the network protection invite success view")
    static let networkProtectionInviteSuccessMessage = NSLocalizedString("network.protection.invite.success.title", value: "Hide your location from websites and conceal your online activity from Internet providers and others on your network.", comment: "Message for the network protection invite success view")

    // MARK: - Navigation Bar Status View

    static let networkProtectionNavBarStatusViewShareFeedback = NSLocalizedString("network.protection.navbar.status.view.share.feedback", value: "Share Feedback...", comment: "Menu item for 'Share Feedback' in the Network Protection status view that's shown in the navigation bar")

}
