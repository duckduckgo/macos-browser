//
//  UserText+NetworkProtectionUI.swift
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

final class UserText {
    static let networkProtectionStatusHeaderMessageOff = NSLocalizedString("network.protection.status.header.message.off", value: "Connect to secure all of your device’s\nInternet traffic.", comment: "Message label text for the status view when VPN is disconnected")
    static let networkProtectionStatusHeaderMessageOn = NSLocalizedString("network.protection.status.header.message.on", value: "All device Internet traffic is being secured\nthrough the VPN.", comment: "Message label text for the status view when VPN is connected")
    static let networkProtectionStatusViewConnDetails = NSLocalizedString("network.protection.status.view.connection.details", value: "Connection Details", comment: "Connection details label shown in NetworkProtection's status view.")
    static let networkProtectionStatusViewConnLabel = NSLocalizedString("network.protection.status.view.connection.label", value: "VPN", comment: "Connection label shown in NetworkProtection's status view.")
    static let networkProtectionStatusViewLocation = NSLocalizedString("network.protection.status.view.location", value: "Location", comment: "Location label shown in NetworkProtection's status view.")
    static let networkProtectionStatusViewIPAddress = NSLocalizedString("network.protection.status.view.ip.address", value: "IP Address", comment: "IP Address label shown in NetworkProtection's status view.")
    static let networkProtectionStatusViewFeatureOff = NSLocalizedString("network.protection.status.view.feature.on", value: "DuckDuckGo VPN is OFF", comment: "Text shown in NetworkProtection's status view when NetP is OFF.")
    static let networkProtectionStatusViewFeatureOn = NSLocalizedString("network.protection.status.view.feature.on", value: "DuckDuckGo VPN is ON", comment: "Text shown in NetworkProtection's status view when NetP is ON.")
    static let networkProtectionStatusViewTimerZero = "00:00:00"

    static let netPVPNLocationNearest = NSLocalizedString("network.protection.vpn.location.nearest", value: "(Nearest)", comment: "Description of the location type in the VPN status view")
    static let vpnLocationConnected = NSLocalizedString("network.protection.vpn.location.connected", value: "Connected Location", comment: "Description of the location type in the VPN status view")
    static let vpnLocationSelected = NSLocalizedString("network.protection.vpn.location.selected", value: "Selected Location", comment: "Description of the location type in the VPN status view")
    static let vpnDataVolume = NSLocalizedString("network.protection.vpn.data-volume", value: "Data Volume", comment: "Title for the data volume section in the VPN status view")
    static let vpnShareFeedback = NSLocalizedString("network.protection.vpn.share-feedback", value: "Share VPN Feedback…", comment: "Action button title for the Share VPN feedback option")
    static let vpnOperationNotPermittedMessage = NSLocalizedString("network.protection.vpn.failure.operation-not-permitted", value: "Operation not permitted", comment: "Error message for the Operation Not Permitted error")
    static let vpnLoginItemVersionMismatchedMessage = NSLocalizedString("network.protection.vpn.failure.login-item-version-mismatched", value: "Login item version mismatched", comment: "Error message for the Login item version mismatched error")

    // MARK: - Onboarding

    static let networkProtectionOnboardingInstallExtensionTitle = NSLocalizedString("network.protection.onboarding.install.extension.title", value: "Install VPN System Extension", comment: "Title for the onboarding install-vpn-extension step")
    static let networkProtectionOnboardingAllowExtensionDescPrefix = NSLocalizedString("network.protection.onboarding.allow.extension.desc.prefix", value: "Open System Settings to Privacy & Security. Scroll and select ", comment: "Non-bold prefix for the onboarding allow-extension description")
    static let networkProtectionOnboardingAllowExtensionDescAllow = NSLocalizedString("network.protection.onboarding.allow.extension.desc.allow", value: "Allow", comment: "'Allow' word between the prefix and suffix for the onboarding allow-extension description")
    static let networkProtectionOnboardingAllowExtensionDescSuffix = NSLocalizedString("network.protection.onboarding.allow.extension.desc.suffix", value: " for DuckDuckGo software.", comment: "Non-bold suffix for the onboarding allow-extension description")
    static let networkProtectionOnboardingAllowExtensionAction = NSLocalizedString("network.protection.onboarding.allow.extension.action", value: "Open System Settings...", comment: "Action button title for the onboarding allow-extension view")

    static let networkProtectionOnboardingAllowVPNTitle = NSLocalizedString("network.protection.onboarding.allow.vpn.title", value: "Add VPN Configuration", comment: "Title for the onboarding allow-VPN step")
    static let networkProtectionOnboardingAllowVPNDescPrefix = NSLocalizedString("network.protection.onboarding.allow.vpn.desc.prefix", value: "Select ", comment: "Non-bold prefix for the onboarding allow-VPN description")
    static let networkProtectionOnboardingAllowVPNDescAllow = NSLocalizedString("network.protection.onboarding.allow.vpn.desc.allow", value: "Allow", comment: "'Allow' word between the prefix and suffix for the onboarding allow-VPN description")
    static let networkProtectionOnboardingAllowVPNDescSuffix = NSLocalizedString("network.protection.onboarding.allow.vpn.desc.suffix", value: " when prompted to finish setting up VPN.", comment: "Non-bold suffix for the onboarding allow-VPN description")
    static let networkProtectionOnboardingAllowVPNDescExpandedSuffix = NSLocalizedString("network.protection.onboarding.allow.vpn.desc.expanded.suffix", value: " when prompted to finish setting up VPN.\n\nThis adds a shortcut in the menu bar so you can still access the VPN if the browser isn't running.", comment: "Non-bold suffix for the onboarding allow-VPN description")
    static let networkProtectionOnboardingAllowVPNAction = NSLocalizedString("network.protection.onboarding.allow.vpn.action", value: "Add VPN Configuration...", comment: "Action button title for the onboarding allow-VPN view")

    static let networkProtectionOnboardingMoveToApplicationsTitle = NSLocalizedString("network.protection.onboarding.move.to.applications.title", value: "Move DuckDuckGo App", comment: "Title for the onboarding move-app-to-applications step")
    static let networkProtectionOnboardingMoveToApplicationsDesc = NSLocalizedString("network.protection.onboarding.move.to.applications.desc", value: "To use the VPN, the DuckDuckGo app needs to be in the Applications folder on your Mac. Click the button below to move the app and restart the browser.", comment: "Description for the onboarding move-app-to-applications step")
    static let networkProtectionOnboardingMoveToApplicationsAction = NSLocalizedString("network.protection.onboarding.move.to.applications.action", value: "Move App for Me and Restart…", comment: "Action button title for the onboarding move-app-to-applications step")

    // MARK: - Connection Status

    static let networkProtectionStatusDisconnected = NSLocalizedString("network.protection.status.disconnected", value: "Not connected", comment: "The label for the NetP VPN when disconnected")
    static let networkProtectionStatusDisconnecting = NSLocalizedString("network.protection.status.disconnecting", value: "Disconnecting...", comment: "The label for the NetP VPN when disconnecting")
    static let networkProtectionStatusConnected = NSLocalizedString("network.protection.status.connected", value: "Connected", comment: "The label for the NetP VPN when connected")
    static let networkProtectionStatusConnecting = NSLocalizedString("network.protection.status.connected", value: "Connecting...", comment: "The label for the NetP VPN when connecting")

    // MARK: - Connection Issues

    static let networkProtectionInterruptedReconnecting = NSLocalizedString("network.protection.interrupted.reconnecting", value: "Your VPN connection was interrupted. Attempting to reconnect now...", comment: "The warning message shown in NetP's status view when the connection is interrupted and its attempting to reconnect.")
    static let networkProtectionInterrupted = NSLocalizedString("network.protection.interrupted", value: "The VPN was unable to connect at this time. Please try again later.", comment: "The warning message shown in NetP's status view when the connection is interrupted.")

    // MARK: - Connection Information

    static let networkProtectionServerAddressUnknown = NSLocalizedString("network.protection.server.address.unknown", value: "Unknown", comment: "When we can't tell the user the IP of the NetP server is")
    static let networkProtectionServerLocationUnknown = NSLocalizedString("network.protection.server.location.unknown", value: "Unknown...", comment: "When we can't tell the user the location of the NetP server")
    static func networkProtectionFormattedServerLocation(_ location: String) -> String {
        let localized = NSLocalizedString("network.protection.server.location.link", value: "%@...", comment: "Clickable text linking to the server location picker screen")
        return String(format: localized, location)
    }

    // MARK: Subscription Expired

    static let networkProtectionSubscriptionExpiredTitle = NSLocalizedString("network.protection.subscription.expired.title", value: "VPN disconnected", comment: "Title for the prompt that tells the user their subscription expired.")
    static let networkProtectionSubscriptionExpiredSubtitle = NSLocalizedString("network.protection.subscription.expired.subtitle", value: "Subscribe to Privacy Pro to reconnect DuckDuckGo VPN.", comment: "Subtitle for the prompt that tells the user their subscription expired.")
    static let networkProtectionSubscriptionExpiredResubscribeButton = NSLocalizedString("network.protection.subscription.expired.resubscribe.button", value: "Subscribe to Privacy Pro", comment: "Button for the prompt that takes the user to the page to resubscribe.")
    static let networkProtectionSubscriptionExpiredUninstallButton = NSLocalizedString("network.protection.subscription.expired.uninstall.button", value: "Uninstall DuckDuckGo VPN", comment: "Button for the prompt that uninstalls the VPN.")
}
