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

    // "network.protection.tunnel.name" - The name of the NetP VPN that will be visible in the system to the user
    static let networkProtectionTunnelName = "DuckDuckGo VPN"
    // "network.protection" - Menu item for opening the VPN
    static let networkProtection = "VPN"

    // MARK: - Navigation Bar
    // "network.protection.status.button.tooltip" - The tooltip for NetP's nav bar button
    static let networkProtectionButtonTooltip = "VPN"

    // MARK: - Invite Code
    // "network.protection.invite.dialog.title" - Title for the VPN invite dialog
    static let networkProtectionInviteDialogTitle = "Enter your invite code"
    // "network.protection.invite.dialog.message" - Message for the VPN invite dialog
    static let networkProtectionInviteDialogMessage = "Enter your invite code to get started."
    // "network.protection.invite.field.prompt" - Prompt for the VPN invite code text field
    static let networkProtectionInviteFieldPrompt = "Code"
    // "network.protection.invite.success.title" - Title for the VPN invite success view
    static let networkProtectionInviteSuccessTitle = "Success! You’re in."
    // "network.protection.invite.success.title" - Message for the VPN invite success view
    static let networkProtectionInviteSuccessMessage = "DuckDuckGo's VPN secures all of your device's Internet traffic anytime, anywhere."

    // MARK: - Navigation Bar Status View
    // "network.protection.navbar.status.view.share.feedback" - Menu item for 'Send VPN Feedback' in the VPN status view that's shown in the navigation bar
    static let networkProtectionNavBarStatusViewShareFeedback = "Send VPN Feedback…"
    // "network.protection.status.menu.vpn.settings" - The status menu 'VPN Settings' menu item
    static let networkProtectionNavBarStatusMenuVPNSettings = "VPN Settings…"
    // "network.protection.status.menu.faq" - The status menu 'FAQ' menu item
    static let networkProtectionNavBarStatusMenuFAQ = "Frequently Asked Questions…"

    // MARK: - System Extension Installation Messages
    // "network.protection.configuration.system-settings.legacy" - Text for a label in the VPN popover, displayed after attempting to enable the VPN for the first time while using macOS 12 and below
    private static let networkProtectionSystemSettingsLegacy = "Go to Security & Privacy in System Preferences to allow DuckDuckGo VPN to activate"
    // "network.protection.configuration.system-settings.modern" - Text for a label in the VPN popover, displayed after attempting to enable the VPN for the first time while using macOS 13 and above
    private static let networkProtectionSystemSettingsModern = "Go to Privacy & Security in System Settings to allow DuckDuckGo VPN to activate"

    // Dynamically selected based on macOS version, not directly convertible to static string
    static var networkProtectionSystemSettings: String {
        if #available(macOS 13.0, *) {
            return networkProtectionSystemSettingsModern
        } else {
            return networkProtectionSystemSettingsLegacy
        }
    }

    // "network.protection.system.extension.unknown.activation.error" - Message shown to users when they try to enable NetP and there is an unexpected activation error.
    static let networkProtectionUnknownActivationError = "There as an unexpected error. Please try again."
    // "network.protection.system.extension.please.reboot" - Message shown to users when they try to enable NetP and they need to reboot the computer to complete the installation
    static let networkProtectionPleaseReboot = "Please reboot to activate the VPN"
}

// MARK: - VPN Waitlist

extension UserText {

    // "network-protection.waitlist.notification.title" - Title for VPN waitlist notification
    static let networkProtectionWaitlistNotificationTitle = "DuckDuckGo VPN beta is ready!"
    // "network-protection.waitlist.notification.text" - Title for VPN waitlist notification
    static let networkProtectionWaitlistNotificationText = "Open your invite"

    // "network-protection.waitlist.join.title" - Title for VPN join waitlist screen
    static let networkProtectionWaitlistJoinTitle = "DuckDuckGo VPN Beta"
    // "network-protection.waitlist.join.subtitle.1" - First subtitle for VPN join waitlist screen
    static let networkProtectionWaitlistJoinSubtitle1 = "Secure your connection anytime, anywhere with DuckDuckGo VPN."
    // "network-protection.waitlist.join.subtitle.2" - Second subtitle for VPN join waitlist screen
    static let networkProtectionWaitlistJoinSubtitle2 = "Join the waitlist, and we’ll notify you when it’s your turn."

    // "network-protection.waitlist.joined.title" - Title for VPN joined waitlist screen
    static let networkProtectionWaitlistJoinedTitle = "You’re on the list!"
    // "network-protection.waitlist.joined.with-notifications.subtitle.1" - Subtitle 1 for VPN joined waitlist screen when notifications are enabled
    static let networkProtectionWaitlistJoinedWithNotificationsSubtitle1 = "New invites are sent every few days, on a first come, first served basis."
    // "network-protection.waitlist.joined.with-notifications.subtitle.2" - Subtitle 2 for VPN joined waitlist screen when notifications are enabled
    static let networkProtectionWaitlistJoinedWithNotificationsSubtitle2 = "We’ll notify you when your invite is ready."
    // "network-protection.waitlist.enable-notifications" - Enable notifications prompt for VPN joined waitlist screen
    static let networkProtectionWaitlistEnableNotifications = "Want to get a notification when your VPN invite is ready?"

    // "network-protection.waitlist.invited.title" - Title for VPN invited screen
    static let networkProtectionWaitlistInvitedTitle = "You’re invited to try\nDuckDuckGo VPN beta!"
    // "network-protection.waitlist.invited.subtitle" - Subtitle for VPN invited screen
    static let networkProtectionWaitlistInvitedSubtitle = "Get an extra layer of protection online with the VPN built for speed and simplicity. Encrypt your internet connection across your entire device and hide your location and IP address from sites you visit."

    // "network-protection.waitlist.invited.section-1.title" - Title for section 1 of the VPN invited screen
    static let networkProtectionWaitlistInvitedSection1Title = "Full-device coverage"
    // "network-protection.waitlist.invited.section-1.subtitle" - Subtitle for section 1 of the VPN invited screen
    static let networkProtectionWaitlistInvitedSection1Subtitle = "Encrypt online traffic across your browsers and apps."

    // "network-protection.waitlist.invited.section-2.title" - Title for section 2 of the VPN invited screen
    static let networkProtectionWaitlistInvitedSection2Title = "Fast, reliable, and easy to use"
    // "network-protection.waitlist.invited.section-2.subtitle" - Subtitle for section 2 of the VPN invited screen
    static let networkProtectionWaitlistInvitedSection2Subtitle = "No need for a separate app. Connect in one click and see your connection status at a glance."

    // "network-protection.waitlist.invited.section-3.title" - Title for section 3 of the VPN invited screen
    static let networkProtectionWaitlistInvitedSection3Title = "Strict no-logging policy"
    // "network-protection.waitlist.invited.section-3.subtitle" - Subtitle for section 3 of the VPN invited screen
    static let networkProtectionWaitlistInvitedSection3Subtitle = "We do not log or save any data that can connect you to your online activity."

    // "network-protection.waitlist.enable.title" - Title for VPN enable screen
    static let networkProtectionWaitlistEnableTitle = "Ready to enable DuckDuckGo VPN?"
    // "network-protection.waitlist.enable.subtitle" - Subtitle for VPN enable screen
    static let networkProtectionWaitlistEnableSubtitle = "Look for the globe icon in the browser toolbar or in the Mac menu bar.\n\nYou'll be asked to Allow a VPN connection once when setting up DuckDuckGo VPN the first time."

    // "network-protection.waitlist.availability-disclaimer" - Availability disclaimer for VPN join waitlist screen
    static let networkProtectionWaitlistAvailabilityDisclaimer = "DuckDuckGo VPN is free to use during the beta."

    // "network-protection.waitlist.button.close" - Close button for VPN join waitlist screen
    static let networkProtectionWaitlistButtonClose = "Close"
    // "network-protection.waitlist.button.done" - Close button for VPN joined waitlist screen
    static let networkProtectionWaitlistButtonDone = "Done"
    // "network-protection.waitlist.button.dismiss" - Dismiss button for VPN join waitlist screen
    static let networkProtectionWaitlistButtonDismiss = "Dismiss"
    // "network-protection.waitlist.button.cancel" - Cancel button for VPN join waitlist screen
    static let networkProtectionWaitlistButtonCancel = "Cancel"
    // "network-protection.waitlist.button.no-thanks" - No Thanks button for VPN joined waitlist screen
    static let networkProtectionWaitlistButtonNoThanks = "No Thanks"
    // "network-protection.waitlist.button.get-started" - Get Started button for VPN joined waitlist screen
    static let networkProtectionWaitlistButtonGetStarted = "Get Started"
    // "network-protection.waitlist.button.got-it" - Got It button for VPN joined waitlist screen
    static let networkProtectionWaitlistButtonGotIt = "Got It"
    // "network-protection.waitlist.button.enable-notifications" - Enable Notifications button for VPN joined waitlist screen
    static let networkProtectionWaitlistButtonEnableNotifications = "Enable Notifications"
    // "network-protection.waitlist.button.join-waitlist" - Join Waitlist button for VPN join waitlist screen
    static let networkProtectionWaitlistButtonJoinWaitlist = "Join the Waitlist"
    // "network-protection.waitlist.button.agree-and-continue" - Agree and Continue button for VPN join waitlist screen
    static let networkProtectionWaitlistButtonAgreeAndContinue = "Agree and Continue"
}

// MARK: - VPN Terms of Service

extension UserText {

    // "network-protection.privacy-policy.title" - Privacy Policy title for VPN
    static let networkProtectionPrivacyPolicyTitle = "Privacy Policy"

    // "network-protection.privacy-policy.section.1.title" - Privacy Policy title for VPN
    static let networkProtectionPrivacyPolicySection1Title = "We don’t ask for any personal information from you in order to use this beta service."
    // "network-protection.privacy-policy.section.1.list" - Privacy Policy list for VPN (Markdown version)
    static let networkProtectionPrivacyPolicySection1ListMarkdown = "This Privacy Policy is for our limited waitlist beta VPN product.\n\nOur main [Privacy Policy](https://duckduckgo.com/privacy) also applies here."
    // "network-protection.privacy-policy.section.1.list" - Privacy Policy list for VPN (Non-Markdown version)
    static let networkProtectionPrivacyPolicySection1ListNonMarkdown = "This Privacy Policy is for our limited waitlist beta VPN product.\n\nOur main Privacy Policy also applies here."

    // "network-protection.privacy-policy.section.2.title" - Privacy Policy title for VPN
    static let networkProtectionPrivacyPolicySection2Title = "We don’t keep any logs of your online activity."
    // "network-protection.privacy-policy.section.2.list" - Privacy Policy list for VPN
    static let networkProtectionPrivacyPolicySection2List = "That means we have no way to tie what you do online to you as an individual and we don’t have any record of things like:\n    • Website visits\n    • DNS requests\n    • Connections made\n    • IP addresses used\n    • Session lengths"

    // "network-protection.privacy-policy.section.3.title" - Privacy Policy title for VPN
    static let networkProtectionPrivacyPolicySection3Title = "We only keep anonymous performance metrics that we cannot connect to your online activity."
    // "network-protection.privacy-policy.section.3.list" - Privacy Policy list for VPN
    static let networkProtectionPrivacyPolicySection3List = "Our servers store generic usage (for example, CPU load) and diagnostic data (for example, errors), but none of that data is connected to any individual’s activity.\n\nWe use this non-identifying information to monitor and ensure the performance and quality of the service, for example to make sure servers aren’t overloaded."

    // "network-protection.privacy-policy.section.4.title" - Privacy Policy title for VPN
    static let networkProtectionPrivacyPolicySection4Title = "We use dedicated servers for all VPN traffic."
    // "network-protection.privacy-policy.section.4.list" - Privacy Policy list for VPN
    static let networkProtectionPrivacyPolicySection4List = "Dedicated servers means they are not shared with anyone else.\n\nWe rent our servers from providers we carefully selected because they meet our privacy requirements.\n\nWe have strict access controls in place so that only limited DuckDuckGo team members have access to our servers."

    // "network-protection.privacy-policy.section.5.title" - Privacy Policy title for VPN
    static let networkProtectionPrivacyPolicySection5Title = "We protect and limit use of your data when you communicate directly with DuckDuckGo."
    // "network-protection.privacy-policy.section.5.list" - Privacy Policy list for VPN
    static let networkProtectionPrivacyPolicySection5List = "If you reach out to us for support by submitting a bug report or through email and agree to be contacted to troubleshoot the issue, we’ll contact you using the information you provide.\n\nIf you participate in a voluntary product survey or questionnaire and agree to provide further feedback, we may contact you using the information you provide.\n\nWe will permanently delete all personal information you provided to us (email, contact information), within 30 days after closing a support case or, in the case of follow up feedback, within 60 days after ending this beta service."

    // "network-protection.terms-of-service.title" - Terms of Service title for VPN
    static let networkProtectionTermsOfServiceTitle = "Terms of Service"

    // "network-protection.terms-of-service.section.1.title" - Terms of Service title for VPN
    static let networkProtectionTermsOfServiceSection1Title = "The service is for limited and personal use only."
    // "network-protection.terms-of-service.section.1.list" - Terms of Service list for VPN
    static let networkProtectionTermsOfServiceSection1List = "This service is provided for your personal use only.\n\nYou are responsible for all activity in the service that occurs on or through your device.\n\nThis service may only be used through the DuckDuckGo app on the device on which you are given access. If you delete the DuckDuckGo app, you will lose access to the service.\n\nYou may not use this service through a third-party client."

    // "network-protection.terms-of-service.section.2.title" - Terms of Service title for VPN
    static let networkProtectionTermsOfServiceSection2Title = "You agree to comply with all applicable laws, rules, and regulations."
    // "network-protection.terms-of-service.section.2.list" - Terms of Service list for VPN (Markdown version)
    static let networkProtectionTermsOfServiceSection2ListMarkdown = "You agree that you will not use the service for any unlawful, illicit, criminal, or fraudulent purpose, or in any manner that could give rise to civil or criminal liability under applicable law.\n\nYou agree to comply with our [DuckDuckGo Terms of Service](https://duckduckgo.com/terms), which are incorporated by reference."
    // "network-protection.terms-of-service.section.2.list" - Terms of Service list for VPN (Non-Markdown version)
    static let networkProtectionTermsOfServiceSection2ListNonMarkdown = "You agree that you will not use the service for any unlawful, illicit, criminal, or fraudulent purpose, or in any manner that could give rise to civil or criminal liability under applicable law.\n\nYou agree to comply with our DuckDuckGo Terms of Service, which are incorporated by reference."

    // "network-protection.terms-of-service.section.3.title" - Terms of Service title for VPN
    static let networkProtectionTermsOfServiceSection3Title = "You must be eligible to use this service."
    // "network-protection.terms-of-service.section.3.list" - Terms of Service list for VPN
    static let networkProtectionTermsOfServiceSection3List = "Access to this beta is randomly awarded. You are responsible for ensuring eligibility.\n\nYou must be at least 18 years old and live in a location where use of a VPN is legal in order to be eligible to use this service."

    // "network-protection.terms-of-service.section.4.title" - Terms of Service title for VPN
    static let networkProtectionTermsOfServiceSection4Title = "We provide this beta service as-is and without warranty."
    // "network-protection.terms-of-service.section.4.list" - Terms of Service list for VPN
    static let networkProtectionTermsOfServiceSection4List = "This service is provided as-is and without warranties or guarantees of any kind.\n\nTo the extent possible under applicable law, DuckDuckGo will not be liable for any damage or loss arising from your use of the service. In any event, the total aggregate liability of DuckDuckGo shall not exceed $25 or the equivalent in your local currency.\n\nWe may in the future transfer responsibility for the service to a subsidiary of DuckDuckGo. If that happens, you agree that references to “DuckDuckGo” will refer to our subsidiary, which will then become responsible for providing the service and for any liabilities relating to it."

    // "network-protection.terms-of-service.section.5.title" - Terms of Service title for VPN
    static let networkProtectionTermsOfServiceSection5Title = "We may terminate access at any time."
    // "network-protection.terms-of-service.section.5.list" - Terms of Service list for VPN
    static let networkProtectionTermsOfServiceSection5List = "We reserve the right to revoke access to the service at any time in our sole discretion.\n\nWe may also terminate access for violation of these terms, including for repeated infringement of the intellectual property rights of others."

    // "network-protection.terms-of-service.section.6.title" - Terms of Service title for VPN
    static let networkProtectionTermsOfServiceSection6Title = "The service is free during the beta period."
    // "network-protection.terms-of-service.section.6.list" - Terms of Service list for VPN
    static let networkProtectionTermsOfServiceSection6List = "Access to this service is currently free of charge, but that is limited to this beta period.\n\nYou understand and agree that this service is provided on a temporary, testing basis only."

    // "network-protection.terms-of-service.section.7.title" - Terms of Service title for VPN
    static let networkProtectionTermsOfServiceSection7Title = "We are continually updating the service."
    // "network-protection.terms-of-service.section.7.list" - Terms of Service list for VPN
    static let networkProtectionTermsOfServiceSection7List = "The service is in beta, and we are regularly changing it.\n\nService coverage, speed, server locations, and quality may vary without warning."

    // "network-protection.terms-of-service.section.8.title" - Terms of Service title for VPN
    static let networkProtectionTermsOfServiceSection8Title = "We need your feedback."
    // "network-protection.terms-of-service.section.8.list" - Terms of Service list for VPN
    static let networkProtectionTermsOfServiceSection8List = "You may be asked during the beta period to provide feedback about your experience. Doing so is optional and your feedback may be used to improve the service.\n\nIf you have enabled notifications for the DuckDuckGo app, we may use notifications to ask about your experience. You can disable notifications if you do not want to receive them."

    // MARK: - Feedback Form
    // "vpn.feedback-form.title" - Title for each screen of the VPN feedback form
    static let vpnFeedbackFormTitle = "Help Improve the DuckDuckGo VPN"
    // "vpn.feedback-form.category.select-category" - Title for the category selection state of the VPN feedback form
    static let vpnFeedbackFormCategorySelect = "Select a category"
    // "vpn.feedback-form.category.unable-to-install" - Title for the 'unable to install' category of the VPN feedback form
    static let vpnFeedbackFormCategoryUnableToInstall = "Unable to install VPN"
    // "vpn.feedback-form.category.fails-to-connect" - Title for the 'VPN fails to connect' category of the VPN feedback form
    static let vpnFeedbackFormCategoryFailsToConnect = "VPN fails to connect"
    // "vpn.feedback-form.category.too-slow" - Title for the 'VPN is too slow' category of the VPN feedback form
    static let vpnFeedbackFormCategoryTooSlow = "VPN connection is too slow"
    // "vpn.feedback-form.category.issues-with-apps" - Title for the category 'VPN causes issues with other apps or websites' category of the VPN feedback form
    static let vpnFeedbackFormCategoryIssuesWithApps = "VPN causes issues with other apps or websites"
    // "vpn.feedback-form.category.local-device-connectivity" - Title for the local device connectivity category of the VPN feedback form
    static let vpnFeedbackFormCategoryLocalDeviceConnectivity = "VPN won't let me connect to local device"
    // "vpn.feedback-form.category.browser-crash-or-freeze" - Title for the browser crash/freeze category of the VPN feedback form
    static let vpnFeedbackFormCategoryBrowserCrashOrFreeze = "VPN causes browser to crash or freeze"
    // "vpn.feedback-form.category.feature-request" - Title for the 'VPN feature request' category of the VPN feedback form
    static let vpnFeedbackFormCategoryFeatureRequest = "VPN feature request"
    // "vpn.feedback-form.category.other" - Title for the 'other VPN feedback' category of the VPN feedback form
    static let vpnFeedbackFormCategoryOther = "Other VPN feedback"

    // "vpn.feedback-form.text-1" - Text for the body of the VPN feedback form
    static let vpnFeedbackFormText1 = "Please describe what's happening, what you expected to happen, and the steps that led to the issue:"
    // "vpn.feedback-form.text-2" - Text for the body of the VPN feedback form
    static let vpnFeedbackFormText2 = "In addition to the details entered into this form, your app issue report will contain:"
    // "vpn.feedback-form.text-3" - Bullet text for the body of the VPN feedback form
    static let vpnFeedbackFormText3 = "• Whether specific DuckDuckGo features are enabled"
    // "vpn.feedback-form.text-4" - Bullet text for the body of the VPN feedback form
    static let vpnFeedbackFormText4 = "• Aggregate DuckDuckGo app diagnostics"
    // "vpn.feedback-form.text-5" - Text for the body of the VPN feedback form
    static let vpnFeedbackFormText5 = "By clicking \"Submit\" I agree that DuckDuckGo may use the information in this report for purposes of improving the app's features."

    // "vpn.feedback-form.sending-confirmation.title" - Title for the feedback sent view title of the VPN feedback form
    static let vpnFeedbackFormSendingConfirmationTitle = "Thank you!"
    // "vpn.feedback-form.sending-confirmation.description" - Title for the feedback sent view description of the VPN feedback form
    static let vpnFeedbackFormSendingConfirmationDescription = "Your feedback will help us improve the DuckDuckGo VPN."
    // "vpn.feedback-form.sending-confirmation.error" - Title for the feedback sending error text of the VPN feedback form
    static let vpnFeedbackFormSendingConfirmationError = "We couldn't send your feedback right now, please try again."

    // "vpn.feedback-form.button.done" - Title for the Done button of the VPN feedback form
    static let vpnFeedbackFormButtonDone = "Done"
    // "vpn.feedback-form.button.cancel" - Title for the Cancel button of the VPN feedback form
    static let vpnFeedbackFormButtonCancel = "Cancel"
    // "vpn.feedback-form.button.submit" - Title for the Submit button of the VPN feedback form
    static let vpnFeedbackFormButtonSubmit = "Submit"
    // "vpn.feedback-form.button.submitting" - Title for the Submitting state of the VPN feedback form
    static let vpnFeedbackFormButtonSubmitting = "Submitting…"

    // MARK: - Setting Titles
    // "vpn.location.title" - Location section title in VPN settings
    static let vpnLocationTitle = "Location"
    // "vpn.general.title" - General section title in VPN settings
    static let vpnGeneralTitle = "General"
    // "vpn.notifications.settings.title" - Notifications section title in VPN settings
    static let vpnNotificationsSettingsTitle = "Notifications"
    // "vpn.advanced.settings.title" - VPN Advanced section title in VPN settings
    static let vpnAdvancedSettingsTitle = "Advanced"

    // MARK: - Location
    // "vpn.location.change.button.title" - Title of the VPN location preference change button
    static let vpnLocationChangeButtonTitle = "Change..."
    // "vpn.location.list.title" - Title of the VPN location list screen
    static let vpnLocationListTitle = "VPN Location"
    // "vpn.location.recommended.section.title" - Title of the VPN location list recommended section
    static let vpnLocationRecommendedSectionTitle = "Recommended"
    // "vpn.location.custom.section.title" - Title of the VPN location list custom section
    static let vpnLocationCustomSectionTitle = "Custom"
    // "vpn.location.submit.button.title" - Title of the VPN location list submit button
    static let vpnLocationSubmitButtonTitle = "Submit"
    // "vpn.location.custom.section.title" - Title of the VPN location list cancel button (Note: seems like a duplicate key with a different purpose, please check)
    static let vpnLocationCancelButtonTitle = "Cancel"
    // "vpn.location.description.nearest" - Nearest city setting description
    static let vpnLocationNearest = "Nearest"
    // "vpn.location.description.nearest.available" - Nearest available location setting description
    static let vpnLocationNearestAvailable = "Nearest available"
    // "vpn.location.nearest.available.title" - Subtitle underneath the nearest available vpn location preference text.
    static let vpnLocationNearestAvailableSubtitle = "Automatically connect to the nearest server we can find."

    // "network.protection.vpn.location.country.item.formatted.cities.count" - Subtitle of countries item when there are multiple cities, example :
    static func vpnLocationCountryItemFormattedCitiesCount(_ count: Int) -> String {
        let message = "%d cities"
        return String(format: message, count)
    }

    // MARK: - Settings
    // "vpn.setting.title.connect.on.login" - Connect on Login setting title
    static let vpnConnectOnLoginSettingTitle = "Connect on login"
    // "vpn.setting.title.connect.on.login" - Display VPN status in the menu bar.
    static let vpnShowInMenuBarSettingTitle = "Show VPN in menu bar"
    // "vpn.setting.description.always.on" - Always ON setting description
    static let vpnAlwaysOnSettingDescription = "Automatically restores the VPN connection after interruption. For your security, this setting cannot be disabled."
    // "vpn.setting.title.exclude.local.networks" - Exclude Local Networks setting title
    static let vpnExcludeLocalNetworksSettingTitle = "Exclude local networks"
    // "vpn.setting.description.exclude.local.networks" - Exclude Local Networks setting description
    static let vpnExcludeLocalNetworksSettingDescription = "Bypass the VPN for local network connections, like to a printer."
    // "vpn.setting.description.secure.dns" - Secure DNS setting description
    static let vpnSecureDNSSettingDescription = "Our VPN uses Secure DNS to keep your online activity private, so that your Internet provider can't see what websites you visit."
    // "vpn.button.title.uninstall.vpn" - Uninstall VPN button title
    static let uninstallVPNButtonTitle = "Uninstall DuckDuckGo VPN..."

    // MARK: - VPN Settings Alerts
    // "vpn.uninstall.alert.title" - Alert title when the user selects to uninstall our VPN
    static let uninstallVPNAlertTitle = "Are you sure you want to uninstall the VPN?"
    // "vpn.uninstall.alert.informative.text" - Informative text for the alert that comes up when the user decides to uninstall our VPN
    static let uninstallVPNInformativeText = "Uninstalling the DuckDuckGo VPN will disconnect the VPN and remove it from your device."
}

#if DBP
// MARK: - Data Broker Protection Waitlist
extension UserText {
    // "data-broker-protection.privacy-policy.title" - Privacy Policy title for Personal Information Removal
    static let dataBrokerProtectionPrivacyPolicyTitle = "Privacy Policy"
    // "data-broker-protection.waitlist.notification.title" - Title for Personal Information Removal waitlist notification
    static let dataBrokerProtectionWaitlistNotificationTitle = "Personal Information Removal beta is ready!"
    // "data-broker-protection.waitlist.notification.text" - Title for Personal Information Removal waitlist notification
    static let dataBrokerProtectionWaitlistNotificationText = "Open your invite"
    // "data-broker-protection.waitlist.join.title" - Title for Personal Information Removal join waitlist screen
    static let dataBrokerProtectionWaitlistJoinTitle = "Personal Information Removal Beta"
    // "data-broker-protection.waitlist.join.subtitle.1" - First subtitle for Personal Information Removal join waitlist screen
    static let dataBrokerProtectionWaitlistJoinSubtitle1 = "Automatically scan and remove your data from 17+ sites that sell personal information with DuckDuckGo’s Personal Information Removal."
    // "data-broker-protection.waitlist.joined.title" - Title for Personal Information Removal joined waitlist screen
    static let dataBrokerProtectionWaitlistJoinedTitle = "You’re on the list!"
    // "data-broker-protection.waitlist.joined.with-notifications.subtitle.1" - Subtitle 1 for Personal Information Removal joined waitlist screen when notifications are enabled
    static let dataBrokerProtectionWaitlistJoinedWithNotificationsSubtitle1 = "New invites are sent every few days, on a first come, first served basis."
    // "data-broker-protection.waitlist.joined.with-notifications.subtitle.2" - Subtitle 2 for Personal Information Removal joined waitlist screen when notifications are enabled
    static let dataBrokerProtectionWaitlistJoinedWithNotificationsSubtitle2 = "We’ll notify you when your invite is ready."
    // "data-broker-protection.waitlist.enable-notifications" - Enable notifications prompt for Personal Information Removal joined waitlist screen
    static let dataBrokerProtectionWaitlistEnableNotifications = "Want to get a notification when your Personal Information Removal invite is ready?"
    // "data-broker-protection.waitlist.invited.title" - Title for Personal Information Removal invited screen
    static let dataBrokerProtectionWaitlistInvitedTitle = "You’re invited to try\nPersonal Information Removal beta!"
    // "data-broker-protection.waitlist.invited.subtitle" - Subtitle for Personal Information Removal invited screen
    static let dataBrokerProtectionWaitlistInvitedSubtitle = "Automatically find and remove your personal information – such as your name and address – from 17+ sites that store and sell it, reducing the risk of identity theft and spam."
    // "data-broker-protection.waitlist.enable.title" - Title for Personal Information Removal enable screen
    static let dataBrokerProtectionWaitlistEnableTitle = "Let’s get started"
    // "data-broker-protection.waitlist.enable.subtitle" - Subtitle for Personal Information Removal enable screen
    static let dataBrokerProtectionWaitlistEnableSubtitle = "We’ll need your name, address and the year you were born in order to find your personal information on data broker sites\n\nThis info is stored securely on your device, and is never sent to DuckDuckGo."
    // "data-broker-protection.waitlist.availability-disclaimer" - Availability disclaimer for Personal Information Removal join waitlist screen
    static let dataBrokerProtectionWaitlistAvailabilityDisclaimer = "Personal Information Removal is free during the beta.\nJoin the waitlist and we'll notify you when ready."
    // "data-broker-protection.waitlist.button.close" - Close button for Personal Information Removal join waitlist screen
    static let dataBrokerProtectionWaitlistButtonClose = "Close"
    // "data-broker-protection.waitlist.button.done" - Close button for Personal Information Removal joined waitlist screen
    static let dataBrokerProtectionWaitlistButtonDone = "Done"
    // "data-broker-protection.waitlist.button.dismiss" - Dismiss button for Personal Information Removal join waitlist screen
    static let dataBrokerProtectionWaitlistButtonDismiss = "Dismiss"
    // "data-broker-protection.waitlist.button.cancel" - Cancel button for Personal Information Removal join waitlist screen
    static let dataBrokerProtectionWaitlistButtonCancel = "Cancel"
    // "data-broker-protection.waitlist.button.no-thanks" - No Thanks button for Personal Information Removal joined waitlist screen
    static let dataBrokerProtectionWaitlistButtonNoThanks = "No Thanks"
    // "data-broker-protection.waitlist.button.get-started" - Get Started button for Personal Information Removal joined waitlist screen
    static let dataBrokerProtectionWaitlistButtonGetStarted = "Get Started"
    // "data-broker-protection.waitlist.button.got-it" - Get started button for Personal Information Removal joined waitlist screen
    static let dataBrokerProtectionWaitlistButtonGotIt = "Get started"
    // "data-broker-protection.waitlist.button.enable-notifications" - Enable Notifications button for Personal Information Removal joined waitlist screen
    static let dataBrokerProtectionWaitlistButtonEnableNotifications = "Enable Notifications"
    // "data-broker-protection.waitlist.button.join-waitlist" - Join Waitlist button for Personal Information Removal join waitlist screen
    static let dataBrokerProtectionWaitlistButtonJoinWaitlist = "Join the Waitlist"
    // "data-broker-protection.waitlist.button.agree-and-continue" - Agree and Continue button for Personal Information Removal join waitlist screen
    static let dataBrokerProtectionWaitlistButtonAgreeAndContinue = "Agree and Continue"
}
#endif

// MARK: - Thank You Modals

extension UserText {
    static let dbpThankYouTitle = "Personal Information Removal early access is over"
    static let dbpThankYouSubtitle = "Thank you for being a tester!"
    static let dbpThankYouBody1 = "To continue using Personal Information Removal, subscribe to DuckDuckGo Privacy Pro and get 40% off with promo code THANKYOU"

    static let vpnThankYouTitle = "DuckDuckGo VPN early access is over"
    static let vpnThankYouSubtitle = "Thank you for being a tester!"
    static let vpnThankYouBody1 = "To continue using the VPN, subscribe to DuckDuckGo Privacy Pro and get 40% off with promo code THANKYOU"

#if APPSTORE
    static let dbpThankYouBody2 = "Offer redeemable for a limited time only in the desktop version of the DuckDuckGo browser by U.S. testers when you download from duckduckgo.com/app"
    static let vpnThankYouBody2 = "Offer redeemable for a limited time only in the desktop version of the DuckDuckGo browser by U.S. testers when you download from duckduckgo.com/app"
#else
    static let dbpThankYouBody2 = "Offer redeemable for a limited time in the desktop version of the DuckDuckGo browser by U.S. beta testers only."
    static let vpnThankYouBody2 = "Offer redeemable for a limited time in the desktop version of the DuckDuckGo browser by U.S. beta testers only."
#endif
}
