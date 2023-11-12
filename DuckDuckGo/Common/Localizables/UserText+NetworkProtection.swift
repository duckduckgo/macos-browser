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

    // MARK: - Navigation Bar

    static let networkProtectionButtonTooltip = NSLocalizedString("network.protection.status.button.tooltip", value: "Network Protection", comment: "The tooltip for NetP's nav bar button")

    // MARK: - Invite Code

    static let networkProtectionInviteDialogTitle = NSLocalizedString("network.protection.invite.dialog.title", value: "You've unlocked a beta feature!", comment: "Title for the network protection invite dialog")
    static let networkProtectionInviteDialogMessage = NSLocalizedString("network.protection.invite.dialog.message", value: "Enter your invite code to get started.", comment: "Message for the network protection invite dialog")
    static let networkProtectionInviteFieldPrompt = NSLocalizedString("network.protection.invite.field.prompt", value: "Code", comment: "Prompt for the network protection invite code text field")
    static let networkProtectionInviteSuccessTitle = NSLocalizedString("network.protection.invite.success.title", value: "Success! You’re in.", comment: "Title for the network protection invite success view")
    static let networkProtectionInviteSuccessMessage = NSLocalizedString("network.protection.invite.success.title", value: "DuckDuckGo's VPN secures all of your device's Internet traffic anytime, anywhere.", comment: "Message for the network protection invite success view")

    // MARK: - Navigation Bar Status View

    static let networkProtectionNavBarStatusViewShareFeedback = NSLocalizedString("network.protection.navbar.status.view.share.feedback", value: "Share Feedback...", comment: "Menu item for 'Share Feedback' in the Network Protection status view that's shown in the navigation bar")

    // MARK: - System Extension Installation Messages

    private static let networkProtectionSystemSettingsLegacy = NSLocalizedString("network.protection.configuration.system-settings.legacy", value: "Go to Security & Privacy in System Preferences to allow Network Protection to activate", comment: "Text for a label in the Network Protection popover, displayed after attempting to enable Network Protection for the first time while using macOS 12 and below")
    private static let networkProtectionSystemSettingsModern = NSLocalizedString("network.protection.configuration.system-settings.modern", value: "Go to Privacy & Security in System Settings to allow Network Protection to activate", comment: "Text for a label in the Network Protection popover, displayed after attempting to enable Network Protection for the first time while using macOS 13 and above")

    static var networkProtectionSystemSettings: String {
        if #available(macOS 13.0, *) {
            return networkProtectionSystemSettingsModern
        } else {
            return networkProtectionSystemSettingsLegacy
        }
    }

    static let networkProtectionUnknownActivationError = NSLocalizedString("network.protection.system.extension.unknown.activation.error", value: "There as an unexpected error. Please try again.", comment: "Message shown to users when they try to enable NetP and there is an unexpected activation error.")
    static let networkProtectionPleaseReboot = NSLocalizedString("network.protection.system.extension.please.reboot", value: "Please reboot to activate Network Protection", comment: "Message shown to users when they try to enable NetP and they need to reboot the computer to complete the installation")

}

// MARK: - Network Protection Waitlist

extension UserText {

    static let networkProtectionWaitlistNotificationTitle = NSLocalizedString("network-protection.waitlist.notification.title", value: "Network Protection beta is ready!", comment: "Title for Network Protection waitlist notification")
    static let networkProtectionWaitlistNotificationText = NSLocalizedString("network-protection.waitlist.notification.text", value: "Open your invite", comment: "Title for Network Protection waitlist notification")

    static let networkProtectionWaitlistJoinTitle = NSLocalizedString("network-protection.waitlist.join.title", value: "Network Protection Beta", comment: "Title for Network Protection join waitlist screen")
    static let networkProtectionWaitlistJoinSubtitle1 = NSLocalizedString("network-protection.waitlist.join.subtitle.1", value: "Secure your connection anytime, anywhere with Network Protection, the VPN from DuckDuckGo.", comment: "First subtitle for Network Protection join waitlist screen")
    static let networkProtectionWaitlistJoinSubtitle2 = NSLocalizedString("network-protection.waitlist.join.subtitle.2", value: "Join the waitlist, and we’ll notify you when it’s your turn.", comment: "Second subtitle for Network Protection join waitlist screen")

    static let networkProtectionWaitlistJoinedTitle = NSLocalizedString("network-protection.waitlist.joined.title", value: "You’re on the list!", comment: "Title for Network Protection joined waitlist screen")
    static let networkProtectionWaitlistJoinedWithNotificationsSubtitle1 = NSLocalizedString("network-protection.waitlist.joined.with-notifications.subtitle.1", value: "New invites are sent every few days, on a first come, first served basis.", comment: "Subtitle 1 for Network Protection joined waitlist screen when notifications are enabled")
    static let networkProtectionWaitlistJoinedWithNotificationsSubtitle2 = NSLocalizedString("network-protection.waitlist.joined.with-notifications.subtitle.2", value: "We’ll notify you when your invite is ready.", comment: "Subtitle 2 for Network Protection joined waitlist screen when notifications are enabled")
    static let networkProtectionWaitlistEnableNotifications = NSLocalizedString("network-protection.waitlist.enable-notifications", value: "Want to get a notification when your Network Protection invite is ready?", comment: "Enable notifications prompt for Network Protection joined waitlist screen")

    static let networkProtectionWaitlistInvitedTitle = NSLocalizedString("network-protection.waitlist.invited.title", value: "You’re invited to try\nNetwork Protection beta!", comment: "Title for Network Protection invited screen")
    static let networkProtectionWaitlistInvitedSubtitle = NSLocalizedString("network-protection.waitlist.invited.subtitle", value: "Get an extra layer of protection online with the VPN built for speed and simplicity. Encrypt your internet connection across your entire device and hide your location and IP address from sites you visit.", comment: "Subtitle for Network Protection invited screen")

    static let networkProtectionWaitlistInvitedSection1Title = NSLocalizedString("network-protection.waitlist.invited.section-1.title", value: "Full-device coverage", comment: "Title for section 1 of the Network Protection invited screen")
    static let networkProtectionWaitlistInvitedSection1Subtitle = NSLocalizedString("network-protection.waitlist.invited.section-1.subtitle", value: "Encrypt online traffic across your browsers and apps.", comment: "Subtitle for section 1 of the Network Protection invited screen")

    static let networkProtectionWaitlistInvitedSection2Title = NSLocalizedString("network-protection.waitlist.invited.section-2.title", value: "Fast, reliable, and easy to use", comment: "Title for section 2 of the Network Protection invited screen")
    static let networkProtectionWaitlistInvitedSection2Subtitle = NSLocalizedString("network-protection.waitlist.invited.section-2.subtitle", value: "No need for a separate app. Connect in one click and see your connection status at a glance.", comment: "Subtitle for section 2 of the Network Protection invited screen")

    static let networkProtectionWaitlistInvitedSection3Title = NSLocalizedString("network-protection.waitlist.invited.section-3.title", value: "Strict no-logging policy", comment: "Title for section 3 of the Network Protection invited screen")
    static let networkProtectionWaitlistInvitedSection3Subtitle = NSLocalizedString("network-protection.waitlist.invited.section-3.subtitle", value: "We do not log or save any data that can connect you to your online activity.", comment: "Subtitle for section 3 of the Network Protection invited screen")

    static let networkProtectionWaitlistEnableTitle = NSLocalizedString("network-protection.waitlist.enable.title", value: "Ready to enable Network Protection?", comment: "Title for Network Protection enable screen")
    static let networkProtectionWaitlistEnableSubtitle = NSLocalizedString("network-protection.waitlist.enable.subtitle", value: "Look for the globe icon in the browser toolbar or in the Mac menu bar.\n\nYou'll be asked to Allow a VPN connection once when setting up Network Protection the first time.", comment: "Subtitle for Network Protection enable screen")

    static let networkProtectionWaitlistAvailabilityDisclaimer = NSLocalizedString("network-protection.waitlist.availability-disclaimer", value: "Network Protection is free to use during the beta.", comment: "Availability disclaimer for Network Protection join waitlist screen")

    static let networkProtectionWaitlistButtonClose = NSLocalizedString("network-protection.waitlist.button.close", value: "Close", comment: "Close button for Network Protection join waitlist screen")
    static let networkProtectionWaitlistButtonDone = NSLocalizedString("network-protection.waitlist.button.done", value: "Done", comment: "Close button for Network Protection joined waitlist screen")
    static let networkProtectionWaitlistButtonDismiss = NSLocalizedString("network-protection.waitlist.button.dismiss", value: "Dismiss", comment: "Dismiss button for Network Protection join waitlist screen")
    static let networkProtectionWaitlistButtonCancel = NSLocalizedString("network-protection.waitlist.button.cancel", value: "Cancel", comment: "Cancel button for Network Protection join waitlist screen")
    static let networkProtectionWaitlistButtonNoThanks = NSLocalizedString("network-protection.waitlist.button.no-thanks", value: "No Thanks", comment: "No Thanks button for Network Protection joined waitlist screen")
    static let networkProtectionWaitlistButtonGetStarted = NSLocalizedString("network-protection.waitlist.button.get-started", value: "Get Started", comment: "Get Started button for Network Protection joined waitlist screen")
    static let networkProtectionWaitlistButtonGotIt = NSLocalizedString("network-protection.waitlist.button.got-it", value: "Got It", comment: "Got It button for Network Protection joined waitlist screen")
    static let networkProtectionWaitlistButtonEnableNotifications = NSLocalizedString("network-protection.waitlist.button.enable-notifications", value: "Enable Notifications", comment: "Enable Notifications button for Network Protection joined waitlist screen")
    static let networkProtectionWaitlistButtonJoinWaitlist = NSLocalizedString("network-protection.waitlist.button.join-waitlist", value: "Join the Waitlist", comment: "Join Waitlist button for Network Protection join waitlist screen")
    static let networkProtectionWaitlistButtonAgreeAndContinue = NSLocalizedString("network-protection.waitlist.button.agree-and-continue", value: "Agree and Continue", comment: "Agree and Continue button for Network Protection join waitlist screen")

}

// MARK: - Network Protection Terms of Service

extension UserText {

    static let networkProtectionPrivacyPolicyTitle = NSLocalizedString("network-protection.privacy-policy.title", value: "Privacy Policy", comment: "Privacy Policy title for Network Protection")

    static let networkProtectionPrivacyPolicySection1Title = NSLocalizedString("network-protection.privacy-policy.section.1.title", value: "We don’t ask for any personal information from you in order to use this beta service.", comment: "Privacy Policy title for Network Protection")
    static let networkProtectionPrivacyPolicySection1ListMarkdown = NSLocalizedString("network-protection.privacy-policy.section.1.list", value: "This Privacy Policy is for our limited waitlist beta VPN product.\n\nOur main [Privacy Policy](https://duckduckgo.com/privacy) also applies here.", comment: "Privacy Policy list for Network Protection")
    static let networkProtectionPrivacyPolicySection1ListNonMarkdown = NSLocalizedString("network-protection.privacy-policy.section.1.list", value: "This Privacy Policy is for our limited waitlist beta VPN product.\n\nOur main Privacy Policy also applies here.", comment: "Privacy Policy list for Network Protection")

    static let networkProtectionPrivacyPolicySection2Title = NSLocalizedString("network-protection.privacy-policy.section.2.title", value: "We don’t keep any logs of your online activity.", comment: "Privacy Policy title for Network Protection")
    static let networkProtectionPrivacyPolicySection2List = NSLocalizedString("network-protection.privacy-policy.section.2.list", value: "That means we have no way to tie what you do online to you as an individual and we don’t have any record of things like:\n    • Website visits\n    • DNS requests\n    • Connections made\n    • IP addresses used\n    • Session lengths", comment: "Privacy Policy list for Network Protection")

    static let networkProtectionPrivacyPolicySection3Title = NSLocalizedString("network-protection.privacy-policy.section.3.title", value: "We only keep anonymous performance metrics that we cannot connect to your online activity.", comment: "Privacy Policy title for Network Protection")
    static let networkProtectionPrivacyPolicySection3List = NSLocalizedString("network-protection.privacy-policy.section.3.title", value: "Our servers store generic usage (for example, CPU load) and diagnostic data (for example, errors), but none of that data is connected to any individual’s activity.\n\nWe use this non-identifying information to monitor and ensure the performance and quality of the service, for example to make sure servers aren’t overloaded.", comment: "Privacy Policy list for Network Protection")

    static let networkProtectionPrivacyPolicySection4Title = NSLocalizedString("network-protection.privacy-policy.section.4.title", value: "We use dedicated servers for all VPN traffic.", comment: "Privacy Policy title for Network Protection")
    static let networkProtectionPrivacyPolicySection4List = NSLocalizedString("network-protection.privacy-policy.section.4.title", value: "Dedicated servers means they are not shared with anyone else.\n\nWe rent our servers from providers we carefully selected because they meet our privacy requirements.\n\nWe have strict access controls in place so that only limited DuckDuckGo team members have access to our servers.", comment: "Privacy Policy list for Network Protection")

    static let networkProtectionPrivacyPolicySection5Title = NSLocalizedString("network-protection.privacy-policy.section.5.title", value: "We protect and limit use of your data when you communicate directly with DuckDuckGo.", comment: "Privacy Policy title for Network Protection")
    static let networkProtectionPrivacyPolicySection5List = NSLocalizedString("network-protection.privacy-policy.section.5.title", value: "If you reach out to us for support by submitting a bug report or through email and agree to be contacted to troubleshoot the issue, we’ll contact you using the information you provide.\n\nIf you participate in a voluntary product survey or questionnaire and agree to provide further feedback, we may contact you using the information you provide.\n\nWe will permanently delete all personal information you provided to us (email, contact information), within 30 days after closing a support case or, in the case of follow up feedback, within 60 days after ending this beta service.", comment: "Privacy Policy list for Network Protection")

    static let networkProtectionTermsOfServiceTitle = NSLocalizedString("network-protection.terms-of-service.title", value: "Terms of Service", comment: "Terms of Service title for Network Protection")

    static let networkProtectionTermsOfServiceSection1Title = NSLocalizedString("network-protection.terms-of-service.section.1.title", value: "The service is for limited and personal use only.", comment: "Terms of Service title for Network Protection")
    static let networkProtectionTermsOfServiceSection1List = NSLocalizedString("network-protection.terms-of-service.section.1.list", value: "This service is provided for your personal use only.\n\nYou are responsible for all activity in the service that occurs on or through your device.\n\nThis service may only be used through the DuckDuckGo app on the device on which you are given access. If you delete the DuckDuckGo app, you will lose access to the service.\n\nYou may not use this service through a third-party client.", comment: "Terms of Service list for Network Protection")

    static let networkProtectionTermsOfServiceSection2Title = NSLocalizedString("network-protection.terms-of-service.section.2.title", value: "You agree to comply with all applicable laws, rules, and regulations.", comment: "Terms of Service title for Network Protection")
    static let networkProtectionTermsOfServiceSection2ListMarkdown = NSLocalizedString("network-protection.terms-of-service.section.2.list", value: "You agree that you will not use the service for any unlawful, illicit, criminal, or fraudulent purpose, or in any manner that could give rise to civil or criminal liability under applicable law.\n\nYou agree to comply with our [DuckDuckGo Terms of Service](https://duckduckgo.com/terms), which are incorporated by reference.", comment: "Terms of Service list for Network Protection")
    static let networkProtectionTermsOfServiceSection2ListNonMarkdown = NSLocalizedString("network-protection.terms-of-service.section.2.list", value: "You agree that you will not use the service for any unlawful, illicit, criminal, or fraudulent purpose, or in any manner that could give rise to civil or criminal liability under applicable law.\n\nYou agree to comply with our DuckDuckGo Terms of Service, which are incorporated by reference.", comment: "Terms of Service list for Network Protection")

    static let networkProtectionTermsOfServiceSection3Title = NSLocalizedString("network-protection.terms-of-service.section.3.title", value: "You must be eligible to use this service.", comment: "Terms of Service title for Network Protection")
    static let networkProtectionTermsOfServiceSection3List = NSLocalizedString("network-protection.terms-of-service.section.3.list", value: "Access to this beta is randomly awarded. You are responsible for ensuring eligibility.\n\nYou must be at least 18 years old and live in a location where use of a VPN is legal in order to be eligible to use this service.", comment: "Terms of Service list for Network Protection")

    static let networkProtectionTermsOfServiceSection4Title = NSLocalizedString("network-protection.terms-of-service.section.4.title", value: "We provide this beta service as-is and without warranty.", comment: "Terms of Service title for Network Protection")
    static let networkProtectionTermsOfServiceSection4List = NSLocalizedString("network-protection.terms-of-service.section.4.list", value: "This service is provided as-is and without warranties or guarantees of any kind.\n\nTo the extent possible under applicable law, DuckDuckGo will not be liable for any damage or loss arising from your use of the service. In any event, the total aggregate liability of DuckDuckGo shall not exceed $25 or the equivalent in your local currency.\n\nWe may in the future transfer responsibility for the service to a subsidiary of DuckDuckGo.  If that happens, you agree that references to “DuckDuckGo” will refer to our subsidiary, which will then become responsible for providing the service and for any liabilities relating to it.", comment: "Terms of Service list for Network Protection")

    static let networkProtectionTermsOfServiceSection5Title = NSLocalizedString("network-protection.terms-of-service.section.5.title", value: "We may terminate access at any time.", comment: "Terms of Service title for Network Protection")
    static let networkProtectionTermsOfServiceSection5List = NSLocalizedString("network-protection.terms-of-service.section.5.list", value: "We reserve the right to revoke access to the service at any time in our sole discretion.\n\nWe may also terminate access for violation of these terms, including for repeated infringement of the intellectual property rights of others.", comment: "Terms of Service list for Network Protection")

    static let networkProtectionTermsOfServiceSection6Title = NSLocalizedString("network-protection.terms-of-service.section.6.title", value: "The service is free during the beta period.", comment: "Terms of Service title for Network Protection")
    static let networkProtectionTermsOfServiceSection6List = NSLocalizedString("network-protection.terms-of-service.section.6.list", value: "Access to this service is currently free of charge, but that is limited to this beta period.\n\nYou understand and agree that this service is provided on a temporary, testing basis only.", comment: "Terms of Service list for Network Protection")

    static let networkProtectionTermsOfServiceSection7Title = NSLocalizedString("network-protection.terms-of-service.section.7.title", value: "We are continually updating the service.", comment: "Terms of Service title for Network Protection")
    static let networkProtectionTermsOfServiceSection7List = NSLocalizedString("network-protection.terms-of-service.section.7.list", value: "The service is in beta, and we are regularly changing it.\n\nService coverage, speed, server locations, and quality may vary without warning.", comment: "Terms of Service list for Network Protection")

    static let networkProtectionTermsOfServiceSection8Title = NSLocalizedString("network-protection.terms-of-service.section.8.title", value: "We need your feedback.", comment: "Terms of Service title for Network Protection")
    static let networkProtectionTermsOfServiceSection8List = NSLocalizedString("network-protection.terms-of-service.section.8.list", value: "You may be asked during the beta period to provide feedback about your experience. Doing so is optional and your feedback may be used to improve the service.\n\nIf you have enabled notifications for the DuckDuckGo app, we may use notifications to ask about your experience. You can disable notifications if you do not want to receive them.", comment: "Terms of Service list for Network Protection")

}

#if DBP
// MARK: - Data Broker Protection Waitlist
extension UserText {
    static let dataBrokerProtectionPrivacyPolicyTitle = NSLocalizedString("data-broker-protection.privacy-policy.title", value: "Privacy Policy", comment: "Privacy Policy title for Personal Information Removal")

    static let dataBrokerProtectionWaitlistNotificationTitle = NSLocalizedString("data-broker-protection.waitlist.notification.title", value: "Personal Information Removal beta is ready!", comment: "Title for Personal Information Removal waitlist notification")
    static let dataBrokerProtectionWaitlistNotificationText = NSLocalizedString("data-broker-protection.waitlist.notification.text", value: "Open your invite", comment: "Title for Personal Information Removal waitlist notification")

    static let dataBrokerProtectionWaitlistJoinTitle = NSLocalizedString("data-broker-protection.waitlist.join.title", value: "Personal Information Removal Beta", comment: "Title for Personal Information Removal join waitlist screen")
    static let dataBrokerProtectionWaitlistJoinSubtitle1 = NSLocalizedString("data-broker-protection.waitlist.join.subtitle.1", value: "Automatically scan and remove your data from 17+ sites that sell personal information with DuckDuckGo’s Personal Information Removal.", comment: "First subtitle for Personal Information Removal join waitlist screen")
    static let dataBrokerProtectionWaitlistJoinSubtitle2 = NSLocalizedString("data-broker-protection.waitlist.join.subtitle.2", value: "Join the waitlist, and we’ll notify you when it’s your turn.", comment: "Second subtitle for Personal Information Removal join waitlist screen")

    static let dataBrokerProtectionWaitlistJoinedTitle = NSLocalizedString("data-broker-protection.waitlist.joined.title", value: "You’re on the list!", comment: "Title for Personal Information Removal joined waitlist screen")
    static let dataBrokerProtectionWaitlistJoinedWithNotificationsSubtitle1 = NSLocalizedString("data-broker-protection.waitlist.joined.with-notifications.subtitle.1", value: "New invites are sent every few days, on a first come, first served basis.", comment: "Subtitle 1 for Personal Information Removal joined waitlist screen when notifications are enabled")
    static let dataBrokerProtectionWaitlistJoinedWithNotificationsSubtitle2 = NSLocalizedString("data-broker-protection.waitlist.joined.with-notifications.subtitle.2", value: "We’ll notify you when your invite is ready.", comment: "Subtitle 2 for Personal Information Removal joined waitlist screen when notifications are enabled")
    static let dataBrokerProtectionWaitlistEnableNotifications = NSLocalizedString("data-broker-protection.waitlist.enable-notifications", value: "Want to get a notification when your Personal Information Removal invite is ready?", comment: "Enable notifications prompt for Personal Information Removal joined waitlist screen")

    static let dataBrokerProtectionWaitlistInvitedTitle = NSLocalizedString("data-broker-protection.waitlist.invited.title", value: "You’re invited to try\nPersonal Information Removal beta!", comment: "Title for Personal Information Removal invited screen")
    static let dataBrokerProtectionWaitlistInvitedSubtitle = NSLocalizedString("data-broker-protection.waitlist.invited.subtitle", value: "Automatically find and remove your personal information – such as your name and address – from 17+ sites that store and sell it, reducing the risk of identity theft and spam.", comment: "Subtitle for Personal Information Removal invited screen")

    static let dataBrokerProtectionWaitlistInvitedSection1Title = NSLocalizedString("data-broker-protection.waitlist.invited.section-1.title", value: "Continuous Scan and Removal", comment: "Title for section 1 of the Personal Information Removal invited screen")
    static let dataBrokerProtectionWaitlistInvitedSection1Subtitle = NSLocalizedString("data-broker-protection.waitlist.invited.section-1.subtitle", value: "Automatically scans for your info, requests its removal, and re-scans regularly to ensure it doesn’t reappear.", comment: "Subtitle for section 1 of the Personal Information Removal invited screen")

    static let dataBrokerProtectionWaitlistInvitedSection2Title = NSLocalizedString("data-broker-protection.waitlist.invited.section-2.title", value: "Private by Design", comment: "Title for section 2 of the Personal Information Removal invited screen")
    static let dataBrokerProtectionWaitlistInvitedSection2Subtitle = NSLocalizedString("data-broker-protection.waitlist.invited.section-2.subtitle", value: "The removal process is initiated on your device, and the info you provide during setup is stored on your device only.", comment: "Subtitle for section 2 of the Personal Information Removal invited screen")

    static let dataBrokerProtectionWaitlistInvitedSection3Title = NSLocalizedString("data-broker-protection.waitlist.invited.section-3.title", value: "Real-Time Progress Updates", comment: "Title for section 3 of the Personal Information Removal invited screen")
    static let dataBrokerProtectionWaitlistInvitedSection3Subtitle = NSLocalizedString("data-broker-protection.waitlist.invited.section-3.subtitle", value: "See what information has been removed, and monitor progress of ongoing removals from your dashboard.", comment: "Subtitle for section 3 of the Personal Information Removal invited screen")

    static let dataBrokerProtectionWaitlistEnableTitle = NSLocalizedString("data-broker-protection.waitlist.enable.title", value: "Let’s get started", comment: "Title for Personal Information Removal enable screen")
    static let dataBrokerProtectionWaitlistEnableSubtitle = NSLocalizedString("data-broker-protection.waitlist.enable.subtitle", value: "We’ll need your name, address and the year you were born in order to find your personal information on data broker sites\n\nThis info is stored securely on your device, and is never sent to DuckDuckGo.", comment: "Subtitle for Personal Information Removal enable screen")

    static let dataBrokerProtectionWaitlistAvailabilityDisclaimer = NSLocalizedString("data-broker-protection.waitlist.availability-disclaimer", value: "Personal Information Removal is free to use during the beta.", comment: "Availability disclaimer for Personal Information Removal join waitlist screen")

    static let dataBrokerProtectionWaitlistButtonClose = NSLocalizedString("data-broker-protection.waitlist.button.close", value: "Close", comment: "Close button for Personal Information Removal join waitlist screen")
    static let dataBrokerProtectionWaitlistButtonDone = NSLocalizedString("data-broker-protection.waitlist.button.done", value: "Done", comment: "Close button for Personal Information Removal joined waitlist screen")
    static let dataBrokerProtectionWaitlistButtonDismiss = NSLocalizedString("data-broker-protection.waitlist.button.dismiss", value: "Dismiss", comment: "Dismiss button for Personal Information Removal join waitlist screen")
    static let dataBrokerProtectionWaitlistButtonCancel = NSLocalizedString("data-broker-protection.waitlist.button.cancel", value: "Cancel", comment: "Cancel button for Personal Information Removal join waitlist screen")
    static let dataBrokerProtectionWaitlistButtonNoThanks = NSLocalizedString("data-broker-protection.waitlist.button.no-thanks", value: "No Thanks", comment: "No Thanks button for Personal Information Removal joined waitlist screen")
    static let dataBrokerProtectionWaitlistButtonGetStarted = NSLocalizedString("data-broker-protection.waitlist.button.get-started", value: "Get Started", comment: "Get Started button for Personal Information Removal joined waitlist screen")
    static let dataBrokerProtectionWaitlistButtonGotIt = NSLocalizedString("data-broker-protection.waitlist.button.got-it", value: "Get started", comment: "Get started button for Personal Information Removal joined waitlist screen")

    static let dataBrokerProtectionWaitlistButtonEnableNotifications = NSLocalizedString("data-broker-protection.waitlist.button.enable-notifications", value: "Enable Notifications", comment: "Enable Notifications button for Personal Information Removal joined waitlist screen")
    static let dataBrokerProtectionWaitlistButtonJoinWaitlist = NSLocalizedString("data-broker-protection.waitlist.button.join-waitlist", value: "Join the Waitlist", comment: "Join Waitlist button for Personal Information Removal join waitlist screen")
    static let dataBrokerProtectionWaitlistButtonAgreeAndContinue = NSLocalizedString("data-broker-protection.waitlist.button.agree-and-continue", value: "Agree and Continue", comment: "Agree and Continue button for Personal Information Removal join waitlist screen")
}

#endif
