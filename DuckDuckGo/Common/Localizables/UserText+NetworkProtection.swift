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
    // "network.protection.navbar.status.view.share.feedback" - Menu item for 'Share VPN Feedback' in the VPN status view that's shown in the navigation bar
    static let networkProtectionNavBarStatusViewShareFeedback = "Share VPN Feedback…"
    // "network.protection.status.menu.vpn.settings" - The status menu 'VPN Settings' menu item
    static let networkProtectionNavBarStatusMenuVPNSettings = "VPN Settings…"
    // "network.protection.status.menu.faq" - The status menu 'FAQ' menu item
    static let networkProtectionNavBarStatusMenuFAQ = "FAQs and Support…"

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
    static let networkProtectionUnknownActivationError = "There was an unexpected error. Please try again."
    // "network.protection.system.extension.please.reboot" - Message shown to users when they try to enable NetP and they need to reboot the computer to complete the installation
    static let networkProtectionPleaseReboot = "VPN update available. Restart your Mac to reconnect."
}

extension UserText {

    // MARK: - Feedback Form
    // "feedback-form.title" - Title for each screen of the feedback form
    static let feedbackFormTitle = "Help Improve Privacy Pro"
    // "general.feedback-form.category.select-feature" - Title for the feature selection state of the general feedback form
    static let generalFeedbackFormCategorySelect = "Select a category"
    // "general.feedback-form.category.ppro" - Description for the feedback form when the issue is related to subscription and payments
    static let generalFeedbackFormCategoryPPro = "Subscription and Payments"
    // "general.feedback-form.category.vpn" - Description for the feedback form when the issue is related to VPN
    static let generalFeedbackFormCategoryVPN = "VPN"
    // "general.feedback-form.category.pir" - Description for the feedback form when the issue is related to Personal Info Removal (PIR)
    static let generalFeedbackFormCategoryPIR = "Personal Info Removal"
    // "general.feedback-form.category.itr" - Description for the feedback form when the issue is related to Identity Theft Restoration (ITR)
    static let generalFeedbackFormCategoryITR = "Identity Theft Restoration"
    // "ppro.feedback-form.category.select-category" - Title for the category selection state of the feedback form
    static let pproFeedbackFormCategorySelect = "Select a category"
    // "ppro.feedback-form.category.otp" - Description for the feedback form when there is an issue with the one-time password
    static let pproFeedbackFormCategoryOTP = "Issue with one-time password"
    // "ppro.feedback-form.category.something-else" - Description for the feedback form when the user has an issue not categorized in other options
    static let pproFeedbackFormCategoryOther = "Something else"
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
    // "pir.feedback-form.category.select-category" - Title for the category selection state of the PIR feedback form
    static let pirFeedbackFormCategorySelect = "Select a category"
    // "pir.feedback-form.category.no-info-on-specific-site" - Description for the feedback form when the scan didn't find user's info on a specific site
    static let pirFeedbackFormCategoryNothingOnSpecificSite = "The scan didn't find my info on a specific site"
    // "pir.feedback-form.category.not-me" - Description for the feedback form when the scan found records that don’t belong to the user
    static let pirFeedbackFormCategoryNotMe = "The scan found records which aren't me"
    // "pir.feedback-form.category.scan-stuck" - Description for the feedback form when the scan process is stuck
    static let pirFeedbackFormCategoryScanStuck = "The scan for records is stuck"
    // "pir.feedback-form.category.removal-stuck" - Description for the feedback form when the removal process is stuck
    static let pirFeedbackFormCategoryRemovalStuck = "The removal process is stuck"
    // "itr.feedback-form.category.select-category" - Title for the category selection state of the ITR feedback form
    static let itrFeedbackFormCategorySelect = "Select a category"
    // "itr.feedback-form.category.access-code" - Description for the feedback form when there is an issue with the access code
    static let itrFeedbackFormCategoryAccessCode = "Issue with access code"
    // "itr.feedback-form.category.contact-advisor" - Description for the feedback form when the user is unable to contact an advisor
    static let itrFeedbackFormCategoryCantContactAdvisor = "Unable to contact advisor"
    // "itr.feedback-form.category.unhelpful" - Description for the feedback form when the call to an advisor was unhelpful
    static let itrFeedbackFormCategoryUnhelpful = "Call to Advisor was unhelpful"
    // "itr.feedback-form.category.something-else" - Description for the feedback form when the user has an issue not categorized in other options
    static let itrFeedbackFormCategorySomethingElse = "Something else"

    // "ppro.feedback-form.text-1" - Text for the body of the PPro feedback form
    static let pproFeedbackFormText1 = "Found an issue not cover in our [help center](duck://)? We definitely want to know about it.\n\nTell us what's going on:"
    // "ppro.feedback-form.text-2" - Text for the body of the PPro feedback form
    static let pproFeedbackFormText2 = "In addition to the details entered above, we send some anonymized info with your feedback:"
    // "ppro.feedback-form.text-3" - Bullet text for the body of the PPro feedback form
    static let pproFeedbackFormText3 = "• Whether specific browser features are active"
    // "ppro.feedback-form.text-4" - Bullet text for the body of the PPro feedback form
    static let pproFeedbackFormText4 = "• Aggregate app diagnostics (e.g., error codes)"
    // "ppro.feedback-form.text-5" - Text for the body of the PPro feedback form
    static let pproFeedbackFormText5 = "By clicking \"Submit\" you agree that DuckDuckGo may use information submitted to improve the app."
    // "ppro.feedback-form.disclaimer" - Text for the disclaimer of the PPro feedback form
    static let pproFeedbackFormDisclaimer = "Reports are anonymous and sent to DuckDuckGo to help improve our service"

    // "ppro.feedback-form.sending-confirmation.title" - Title for the feedback sent view title of the feedback form
    static let pproFeedbackFormSendingConfirmationTitle = "Thank you!"
    // "ppro.feedback-form.sending-confirmation.description" - Title for the feedback sent view description of the feedback form
    static let pproFeedbackFormSendingConfirmationDescription = "Your Feedback will help us improve Privacy Pro."
    // "ppro.feedback-form.sending-confirmation.error" - Title for the feedback sending error text of the feedback form
    static let pproFeedbackFormSendingConfirmationError = "We couldn't send your feedback right now, please try again."

    // "ppro.feedback-form.button.done" - Title for the Done button of the PPro feedback form
    static let pproFeedbackFormButtonDone = "Done"
    // "ppro.feedback-form.button.cancel" - Title for the Cancel button of the PPro feedback form
    static let pproFeedbackFormButtonCancel = "Cancel"
    // "ppro.feedback-form.button.submit" - Title for the Submit button of the PPro feedback form
    static let pproFeedbackFormButtonSubmit = "Submit"
    // "ppro.feedback-form.button.submitting" - Title for the Submitting state of the PPro feedback form
    static let pproFeedbackFormButtonSubmitting = "Submitting…"

    // "ppro.feedback-form.general-feedback.placeholder" - Placeholder for the General Feedback step in the Privacy Pro feedback form
    static let pproFeedbackFormGeneralFeedbackPlaceholder = "Please give us your feedback:"
    // "ppro.feedback-form.request-feature.placeholder" - Placeholder for the Feature Request step in the Privacy Pro feedback form
    static let pproFeedbackFormRequestFeaturePlaceholder = "What feature would you like to see?"

    // "pir.feedback-form.category.other" - Description for the feedback form when the user has an issue not categorized in other options
    static let pirFeedbackFormCategoryOther = "Something else"
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
    // "vpn.shortcuts.settings.title" - Shortcuts section title in VPN settings
    static let vpnShortcutsSettingsTitle = "Shortcuts"
    // "vpn.notifications.settings.title" - Notifications section title in VPN settings
    static let vpnNotificationsSettingsTitle = "Notifications"
    // "vpn.advanced.settings.title" - VPN Advanced section title in VPN settings
    static let vpnAdvancedSettingsTitle = "Advanced"
    // "vpn.notifications.connection.drops.or.status.changes.title" - Title of the VPN notification option
    static let vpnNotificationsConnectionDropsOrStatusChangesTitle = "VPN connection drops or status changes"

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
    static let vpnLocationNearestAvailable = "Nearest Location"
    // "vpn.location.nearest.available.title" - Subtitle underneath the nearest available vpn location preference text.
    static let vpnLocationNearestAvailableSubtitle = "Automatically connect to the nearest server we can find."

    // "network.protection.vpn.location.country.item.formatted.cities.count" - Subtitle of countries item when there are multiple cities, example :
    static func vpnLocationCountryItemFormattedCitiesCount(_ count: Int) -> String {
        let message = "%d cities"
        return String(format: message, count)
    }

    // MARK: - DNS
    // "vpn.dns.server.title" - Title of the DNS Server section
    static let vpnDnsServerTitle = "DNS Server"
    // "vpn.dns.server.picker.default.title" - Title of the default DNS server option
    static let vpnDnsServerPickerDefaultTitle = "DuckDuckGo (Recommended)"
    // "vpn.dns.server.picker.custom.title" = Title of the custom DNS server option
    static let vpnDnsServerPickerCustomTitle = "Custom"
    // "vpn.dns.server.picker.custom.button.title" = Button title of the custom DNS server option
    static let vpnDnsServerPickerCustomButtonTitle = "Change…"
    // "vpn.setting.description.secure.dns" - Secure DNS description
    static let vpnSecureDNSSettingDescription = "DuckDuckGo routes DNS queries through our DNS servers so your internet provider can't see what websites you visit."

    // "vpn.dns.server.sheet.title" - Title of the DNS Server sheet
    static let vpnDnsServerSheetTitle = "Custom DNS Server"
    // "vpn.dns.server.ipv4.description" - Description of the IPv4 text field
    static let vpnDnsServerIPv4Description = "IPv4 Address:"
    // "vpn.dns.server.disclaimer" - Disclaimer for the custom DNS server option
    static let vpnDnsServerIPv4Disclaimer = "Using a custom DNS server can impact browsing speeds and expose your activity to third parties if the server isn't secure or reliable."
    // "vpn.dns.server.apply.button.title" - Title for the Apply custom DNS server button
    static let vpnDnsServerApplyButtonTitle = "Apply"

    // MARK: - Settings
    // "vpn.setting.title.connect.on.login" - Connect on Login setting title
    static let vpnConnectOnLoginSettingTitle = "Connect to VPN when logging in to your computer"
    // "vpn.setting.title.show.in.menu.bar" - Display VPN status in the menu bar
    static let vpnShowInMenuBarSettingTitle = "Show VPN in menu bar"
    // "vpn.setting.title.show.in.browser.toolbar" - Display VPN status in the browser toolbar
    static let vpnShowInBrowserToolbarSettingTitle = "Show VPN in browser toolbar"
    // "vpn.setting.description.always.on" - Always ON setting description
    static let vpnAlwaysOnSettingDescription = "Automatically restores the VPN connection after interruption. For your security, this setting cannot be disabled."
    // "vpn.setting.title.exclude.local.networks" - Exclude Local Networks setting title
    static let vpnExcludeLocalNetworksSettingTitle = "Exclude local networks"
    // "vpn.setting.description.exclude.local.networks" - Exclude Local Networks setting description
    static let vpnExcludeLocalNetworksSettingDescription = "Bypass the VPN for local network connections, like to a printer."
    // "vpn.button.title.uninstall.vpn" - Uninstall VPN button title
    static let openVPNButtonTitle = "Open VPN…"
    static let uninstallVPNButtonTitle = "Uninstall DuckDuckGo VPN…"

    // MARK: - VPN Settings Alerts
    // "vpn.uninstall.alert.title" - Alert title when the user selects to uninstall our VPN
    static let uninstallVPNAlertTitle = "Are you sure you want to uninstall the VPN?"
    // "vpn.uninstall.alert.informative.text" - Informative text for the alert that comes up when the user decides to uninstall our VPN
    static let uninstallVPNInformativeText = "Uninstalling the DuckDuckGo VPN will disconnect the VPN and remove it from your device."

    // MARK: - VPN Screen
    // "network.protection.vpn.location.nearest" - Description of the location type in the VPN status view
    static let netPVPNLocationNearest = "(Nearest)"

    // "network.protection.vpn.location.subtitle.formatted.city.and.country" - Subtitle for the preferred location item that formats a city and country. E.g Chicago, United States
    static func netPVPNSettingsLocationSubtitleFormattedCityAndCountry(city: String, country: String) -> String {
        return "\(city), \(country)"
    }
}

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
