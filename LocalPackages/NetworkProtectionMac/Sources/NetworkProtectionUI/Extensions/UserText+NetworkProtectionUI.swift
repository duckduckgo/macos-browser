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
    static let networkProtectionStatusHeaderMessageOff = NSLocalizedString("network.protection.status.header.message.off", bundle: Bundle.module, value: "Connect to secure all of your device’s\nInternet traffic.", comment: "Message label text for the status view when VPN is disconnected")
    static let networkProtectionStatusHeaderMessageOn = NSLocalizedString("network.protection.status.header.message.on", bundle: Bundle.module, value: "All device Internet traffic is being secured\nthrough the VPN.", comment: "Message label text for the status view when VPN is connected")
    static let networkProtectionStatusViewConnDetails = NSLocalizedString("network.protection.status.view.connection.details", bundle: Bundle.module, value: "Connection Details", comment: "Connection details label shown in NetworkProtection's status view.")
    static let networkProtectionStatusViewConnLabel = NSLocalizedString("network.protection.status.view.connection.label", bundle: Bundle.module, value: "VPN", comment: "Connection label shown in NetworkProtection's status view.")
    static let networkProtectionStatusViewLocation = NSLocalizedString("network.protection.status.view.location", bundle: Bundle.module, value: "Location", comment: "Location label shown in NetworkProtection's status view.")
    static let networkProtectionStatusViewIPAddress = NSLocalizedString("network.protection.status.view.ip.address", bundle: Bundle.module, value: "IP Address", comment: "IP Address label shown in NetworkProtection's status view.")
    static let networkProtectionStatusViewFeatureOff = NSLocalizedString("network.protection.status.view.feature.isoff", bundle: Bundle.module, value: "DuckDuckGo VPN is OFF", comment: "Text shown in NetworkProtection's status view when NetP is OFF.")
    static let networkProtectionStatusViewFeatureOn = NSLocalizedString("network.protection.status.view.feature.ison", bundle: Bundle.module, value: "DuckDuckGo VPN is ON", comment: "Text shown in NetworkProtection's status view when NetP is ON.")
    static let networkProtectionStatusViewTimerZero = "00:00:00"

    static let vpnLocationConnected = NSLocalizedString("network.protection.vpn.location.connected", bundle: Bundle.module, value: "Connected Location", comment: "Description of the location type in the VPN status view")
    static let vpnLocationSelected = NSLocalizedString("network.protection.vpn.location.selected", bundle: Bundle.module, value: "Selected Location", comment: "Description of the location type in the VPN status view")
    static let vpnDnsServer = NSLocalizedString("network.protection.vpn.dns-server", bundle: Bundle.module, value: "DNS Server", comment: "Title for the DNS server section in the VPN status view")
    static let vpnDataVolume = NSLocalizedString("network.protection.vpn.data-volume", bundle: Bundle.module, value: "Data Volume", comment: "Title for the data volume section in the VPN status view")
    static let vpnSendFeedback = NSLocalizedString("network.protection.vpn.send-feedback", bundle: Bundle.module, value: "Send Feedback…", comment: "Action button title for the Send feedback option")
    static let vpnOperationNotPermittedMessage = NSLocalizedString("network.protection.vpn.failure.operation-not-permitted", bundle: Bundle.module, value: "Unable to connect due to an unexpected error. Restarting your Mac can usually fix the issue.", comment: "Error message for the Operation not permitted error")
    static let vpnLoginItemVersionMismatchedMessage = NSLocalizedString("network.protection.vpn.failure.login-item-version-mismatched", bundle: Bundle.module, value: "Unable to connect due to versioning conflict. If you have multiple versions of the browser installed, remove all but the most recent version of DuckDuckGo and restart your Mac.", comment: "Error message for the Login item version mismatched error")
    static let vpnRegisteredServerFetchingFailedMessage = NSLocalizedString("network.protection.vpn.failure.registered-server-fetching-failed", bundle: Bundle.module, value: "Unable to connect. Double check your internet connection. Make sure other software or services aren't blocking DuckDuckGo VPN servers.", comment: "Error message for the Failed to fetch registered server error")

    // MARK: - Onboarding

    static let networkProtectionOnboardingInstallExtensionTitle = NSLocalizedString("network.protection.onboarding.install.extension.title", bundle: Bundle.module, value: "Install VPN System Extension", comment: "Title for the onboarding install-vpn-extension step")
    static let networkProtectionOnboardingAllowExtensionDescPrefixForSequoia = NSLocalizedString("network.protection.onboarding.allow.extension.desc.sequoia.prefix", bundle: Bundle.module, value: "Click ", comment: "Non-bold description for the onboarding allow-extension description")
    static let networkProtectionOnboardingAllowExtensionDescEmphasized = NSLocalizedString("network.protection.onboarding.allow.extension.desc.sequoia.emphasized", bundle: Bundle.module, value: "Open System Settings", comment: "'Allow' word between the prefix and suffix for the onboarding allow-extension description")
    static let networkProtectionOnboardingAllowExtensionDescSuffixForSequoia = NSLocalizedString("network.protection.onboarding.allow.extension.desc.sequoia.suffix", bundle: Bundle.module, value: ", then enable the DuckDuckGo VPN network extension.", comment: "Non-bold description for the onboarding allow-extension description")
    static let networkProtectionOnboardingAllowExtensionDescPrefix = NSLocalizedString("network.protection.onboarding.allow.extension.desc.prefix", bundle: Bundle.module, value: "Open System Settings to Privacy & Security. Scroll and select ", comment: "Non-bold prefix for the onboarding allow-extension description")
    static let networkProtectionOnboardingAllowExtensionDescAllow = NSLocalizedString("network.protection.onboarding.allow.extension.desc.allow", bundle: Bundle.module, value: "Allow", comment: "'Allow' word between the prefix and suffix for the onboarding allow-extension description")
    static let networkProtectionOnboardingAllowExtensionDescSuffix = NSLocalizedString("network.protection.onboarding.allow.extension.desc.suffix", bundle: Bundle.module, value: " for DuckDuckGo software.", comment: "Non-bold suffix for the onboarding allow-extension description")
    static let networkProtectionOnboardingAllowExtensionAction = NSLocalizedString("network.protection.onboarding.allow.extension.action", bundle: Bundle.module, value: "Open System Settings...", comment: "Action button title for the onboarding allow-extension view")

    static let networkProtectionOnboardingAllowVPNTitle = NSLocalizedString("network.protection.onboarding.allow.vpn.title", bundle: Bundle.module, value: "Add VPN Configuration", comment: "Title for the onboarding allow-VPN step")
    static let networkProtectionOnboardingAllowVPNDescPrefix = NSLocalizedString("network.protection.onboarding.allow.vpn.desc.prefix", bundle: Bundle.module, value: "Select ", comment: "Non-bold prefix for the onboarding allow-VPN description")
    static let networkProtectionOnboardingAllowVPNDescAllow = NSLocalizedString("network.protection.onboarding.allow.vpn.desc.allow", bundle: Bundle.module, value: "Allow", comment: "'Allow' word between the prefix and suffix for the onboarding allow-VPN description")
    static let networkProtectionOnboardingAllowVPNDescSuffix = NSLocalizedString("network.protection.onboarding.allow.vpn.desc.suffix", bundle: Bundle.module, value: " when prompted to finish setting up VPN.", comment: "Non-bold suffix for the onboarding allow-VPN description")
    static let networkProtectionOnboardingAllowVPNDescExpandedSuffix = NSLocalizedString("network.protection.onboarding.allow.vpn.desc.expanded.suffix", bundle: Bundle.module, value: " when prompted to finish setting up VPN.\n\nThis adds a shortcut in the menu bar so you can still access the VPN if the browser isn't running.", comment: "Non-bold suffix for the onboarding allow-VPN description")
    static let networkProtectionOnboardingAllowVPNAction = NSLocalizedString("network.protection.onboarding.allow.vpn.action", bundle: Bundle.module, value: "Add VPN Configuration...", comment: "Action button title for the onboarding allow-VPN view")

    static let networkProtectionOnboardingMoveToApplicationsTitle = NSLocalizedString("network.protection.onboarding.move.to.applications.title", bundle: Bundle.module, value: "Move DuckDuckGo App", comment: "Title for the onboarding move-app-to-applications step")
    static let networkProtectionOnboardingMoveToApplicationsDesc = NSLocalizedString("network.protection.onboarding.move.to.applications.desc", bundle: Bundle.module, value: "To use the VPN, the DuckDuckGo app needs to be in the Applications folder on your Mac. Click the button below to move the app and restart the browser.", comment: "Description for the onboarding move-app-to-applications step")
    static let networkProtectionOnboardingMoveToApplicationsAction = NSLocalizedString("network.protection.onboarding.move.to.applications.action", bundle: Bundle.module, value: "Move App for Me and Restart…", comment: "Action button title for the onboarding move-app-to-applications step")

    // MARK: - Connection Status

    static let networkProtectionStatusDisconnected = NSLocalizedString("network.protection.status.disconnected", bundle: Bundle.module, value: "Not connected", comment: "The label for the NetP VPN when disconnected")
    static let networkProtectionStatusDisconnecting = NSLocalizedString("network.protection.status.disconnecting", bundle: Bundle.module, value: "Disconnecting...", comment: "The label for the NetP VPN when disconnecting")
    static let networkProtectionStatusConnected = NSLocalizedString("network.protection.status.connected", bundle: Bundle.module, value: "Connected", comment: "The label for the NetP VPN when connected")
    static let networkProtectionStatusConnecting = NSLocalizedString("network.protection.status.connecting", bundle: Bundle.module, value: "Connecting...", comment: "The label for the NetP VPN when connecting")

    // MARK: - Connection Issues

    static let networkProtectionInterruptedReconnecting = NSLocalizedString("network.protection.interrupted.reconnecting", bundle: Bundle.module, value: "Your VPN connection was interrupted. Attempting to reconnect now...", comment: "The warning message shown in NetP's status view when the connection is interrupted and its attempting to reconnect.")
    static let networkProtectionInterrupted = NSLocalizedString("network.protection.interrupted", bundle: Bundle.module, value: "The VPN was unable to connect at this time. Please try again later.", comment: "The warning message shown in NetP's status view when the connection is interrupted.")

    // MARK: - Connection Information

    static let networkProtectionServerAddressUnknown = NSLocalizedString("network.protection.server.address.unknown", bundle: Bundle.module, value: "Unknown", comment: "When we can't tell the user the IP of the NetP server is")
    static let networkProtectionServerLocationUnknown = NSLocalizedString("network.protection.server.location.unknown", bundle: Bundle.module, value: "Unknown...", comment: "When we can't tell the user the location of the NetP server")
    static func networkProtectionFormattedServerLocation(_ location: String) -> String {
        let localized = NSLocalizedString("network.protection.server.location.link", bundle: Bundle.module, value: "%@...", comment: "Clickable text linking to the server location picker screen")
        return String(format: localized, location)
    }

    // MARK: Subscription Expired

    static let networkProtectionSubscriptionExpiredTitle = NSLocalizedString("network.protection.subscription.expired.title", bundle: Bundle.module, value: "VPN disconnected", comment: "Title for the prompt that tells the user their subscription expired.")
    static let networkProtectionSubscriptionExpiredSubtitle = NSLocalizedString("network.protection.subscription.expired.subtitle", bundle: Bundle.module, value: "Subscribe to Privacy Pro to reconnect DuckDuckGo VPN.", comment: "Subtitle for the prompt that tells the user their subscription expired.")
    static let networkProtectionSubscriptionExpiredResubscribeButton = NSLocalizedString("network.protection.subscription.expired.resubscribe.button", bundle: Bundle.module, value: "Subscribe to Privacy Pro", comment: "Button for the prompt that takes the user to the page to resubscribe.")
    static let networkProtectionSubscriptionExpiredUninstallButton = NSLocalizedString("network.protection.subscription.expired.uninstall.button", bundle: Bundle.module, value: "Uninstall DuckDuckGo VPN", comment: "Button for the prompt that uninstalls the VPN.")

    // MARK: Tool tips

    static let networkProtectionGeoswitchingTipTitle = NSLocalizedString("network.protection.geoswitching.tip.title", bundle: Bundle.module, value: "Change Your Location", comment: "Title for tooltip about geoswitching")
    static let networkProtectionGeoswitchingTipMessage = NSLocalizedString("network.protection.geoswitching.tip.message", bundle: Bundle.module, value: "Connect to any of our servers worldwide to customize the VPN location.", comment: "Message for tooltip about geoswitching")

    static let networkProtectionAutoconnectTipTitle = NSLocalizedString("network.protection.autoconnect.tip.title", bundle: Bundle.module, value: "Connect Automatically", comment: "Title for tooltip about auto-connect")
    static let networkProtectionAutoconnectTipMessage = NSLocalizedString("network.protection.autoconnect.tip.message", bundle: Bundle.module, value: "The VPN can connect on its own when you log in to your computer.", comment: "Message for tooltip about auto-connect")
    static let networkProtectionAutoconnectTipEnableAction = NSLocalizedString("network.protection.autoconnect.tip.enable", bundle: Bundle.module, value: "Enable", comment: "Action to enable auto-connect")

    static let networkProtectionDomainExclusionsTipTitle = NSLocalizedString("network.protection.domain.exclusion.tip.title", bundle: Bundle.module, value: "Website not working?", comment: "Title for tooltip about domain exclusion")
    static let networkProtectionDomainExclusionsTipMessage = NSLocalizedString("network.protection.domain.exclusion.tip.message", bundle: Bundle.module, value: "Exclude websites that block VPN traffic so you can use them without turning the VPN off.", comment: "Message for tooltip about domain exclusion")

    // MARK: Report site issues

    static let networkProtectionReportSiteIssuesViewTitle = NSLocalizedString("network.protection.report.site.issues.title", bundle: Bundle.module, value: "Report an issue with %@?", comment: "Title for report site issues view for website “%@”")
    static let networkProtectionReportSiteIssuesViewDescription = NSLocalizedString("network.protection.report.site.issues.description", bundle: Bundle.module, value: "Please let us know if you excluded %@ from the VPN because you experienced issues.", comment: "Description for report site issues view for website “%@”")
    static let networkProtectionReportSiteIssuesViewFooter = NSLocalizedString("network.protection.report.site.issues.footer", bundle: Bundle.module, value: "Reports only include the domain of the affected website.", comment: "Footer for report site issues view")

    static let networkProtectionReportSiteIssuesViewButtonCancel = NSLocalizedString("network.protection.report.site.issues.button.cancel", bundle: Bundle.module, value: "Not Now", comment: "Report site issues view cancel button")
    static let networkProtectionReportSiteIssuesViewButtonReport = NSLocalizedString("network.protection.report.site.issues.button.report", bundle: Bundle.module, value: "Report", comment: "Report site issues confirmation button to send report")
    static let networkProtectionReportSiteIssuesViewButtonDontAsk = NSLocalizedString("network.protection.report.site.issues.button.dontask", bundle: Bundle.module, value: "Don't Ask Again", comment: "Report site issues view button not to ask again")

    // MARK: Site troubleshooting

    static let networkProtectionSiteTroubleShootingViewTitle = NSLocalizedString("network.protection.site.troubleshooting.title", bundle: Bundle.module, value: "Website Preferences", comment: "Title for VPN website preferences view")
    static let networkProtectionSiteTroubleShootingViewExcludeWebsite = NSLocalizedString("network.protection.site.troubleshooting.exclude", bundle: Bundle.module, value: "Exclude %@ from VPN", comment: "Option to exclude a “%@” website from the VPN")
}
