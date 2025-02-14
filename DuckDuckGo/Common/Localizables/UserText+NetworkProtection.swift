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

///
/// Copy related to VPN used only in both main app targets
///
extension UserText {
    static let networkProtection = NSLocalizedString("network.protection", value: "VPN", comment: "Menu item for opening the VPN")

    // MARK: - Navigation Bar

    static let networkProtectionButtonTooltip = NSLocalizedString("network.protection.status.button.tooltip", value: "VPN", comment: "The tooltip for NetP's nav bar button")

    // MARK: - Invite Code

    static let networkProtectionInviteDialogTitle = NSLocalizedString("network.protection.invite.dialog.title", value: "Enter your invite code", comment: "Title for the VPN invite dialog")

    static let networkProtectionInviteDialogMessage = NSLocalizedString("network.protection.invite.dialog.message", value: "Enter your invite code to get started.", comment: "Message for the VPN invite dialog")

    static let networkProtectionInviteFieldPrompt = NSLocalizedString("network.protection.invite.field.prompt", value: "Code", comment: "Prompt for the VPN invite code text field")

    static let networkProtectionInviteSuccessTitle = NSLocalizedString("network.protection.invite.success.title", value: "Success! You’re in.", comment: "Title for the VPN invite success view")

    static let networkProtectionInviteSuccessMessage = NSLocalizedString("network.protection.invite.success.title", value: "DuckDuckGo's VPN secures all of your device's Internet traffic anytime, anywhere.", comment: "Message for the VPN invite success view")

    // MARK: - VPN Status View submenu (legacy)

    static let networkProtectionNavBarStatusViewSendFeedback = NSLocalizedString("network.protection.navbar.status.view.send.feedback", value: "Send Feedback…", comment: "Menu item for 'Send Feedback' in the VPN status view that's shown in the navigation bar")

    static let networkProtectionNavBarStatusViewVPNSettings = NSLocalizedString("network.protection.navbar.status.view.vpn.settings", value: "VPN Settings…", comment: "The status menu 'VPN Settings' menu item")

    static let networkProtectionNavBarStatusViewFAQ = NSLocalizedString("network.protection.navbar.status.view.faq", value: "FAQs and Support…", comment: "The status menu 'FAQ' menu item")

    // MARK: - VPN Status View submenu

    static let vpnStatusViewVPNSettingsMenuItemTitle = NSLocalizedString(
        "vpn.status-view.vpn-settings.menu-item.title",
        value: "VPN Settings",
        comment: "The VPN status view's 'VPN Settings' menu item for our main app. The number shown is how many Apps are excluded.")

    static let vpnStatusViewExcludedAppsMenuItemTitle = NSLocalizedString(
        "vpn.status-view.excluded-apps.menu-item.title",
        value: "Excluded Apps",
        comment: "The VPN status view's 'Excluded Apps' menu item for our main app.")

    static let vpnStatusViewExcludedDomainsMenuItemTitle = NSLocalizedString(
        "vpn.status-view.excluded-domains.menu-item.title",
        value: "Excluded Websites",
        comment: "The VPN status view's 'Excluded Websites' menu item for our main app.")

    static let vpnStatusViewSendFeedbackMenuItemTitle = NSLocalizedString(
        "vpn.status-view.send-feedback.menu-item.title",
        value: "Send Feedback",
        comment: "The VPN status view's 'Send Feedback' menu item for our main app")

    static let vpnStatusViewFAQMenuItemTitle = NSLocalizedString(
        "vpn.status-view.faq.menu-item.title",
        value: "FAQs and Support",
        comment: "The VPN status view's 'FAQ' menu item for our main app")
}

extension UserText {

    // MARK: - Feedback Form

    static let feedbackFormTitle = NSLocalizedString("feedback-form.title", value: "Help Improve Privacy Pro", comment: "Title for each screen of the feedback form")

    static let generalFeedbackFormCategorySelect = NSLocalizedString("general.feedback-form.category.select-feature", value: "Select a category", comment: "Title for the feature selection state of the general feedback form")

    static let generalFeedbackFormCategoryPPro = NSLocalizedString("general.feedback-form.category.ppro", value: "Subscription and Payments", comment: "Description for the feedback form when the issue is related to subscription and payments")

    static let generalFeedbackFormCategoryVPN = NSLocalizedString("general.feedback-form.category.vpn", value: "VPN", comment: "Description for the feedback form when the issue is related to VPN")

    static let generalFeedbackFormCategoryPIR = NSLocalizedString("general.feedback-form.category.pir", value: "Personal Information Removal", comment: "Description for the feedback form when the issue is related to Personal Info Removal (PIR)")

    static let generalFeedbackFormCategoryITR = NSLocalizedString("general.feedback-form.category.itr", value: "Identity Theft Restoration", comment: "Description for the feedback form when the issue is related to Identity Theft Restoration (ITR)")

    static let pproFeedbackFormCategorySelect = NSLocalizedString("ppro.feedback-form.category.select-category", value: "Select a category", comment: "Title for the category selection state of the feedback form")

    static let pproFeedbackFormCategoryOTP = NSLocalizedString("ppro.feedback-form.category.otp", value: "Issue with one-time password", comment: "Description for the feedback form when there is an issue with the one-time password")

    static let pproFeedbackFormCategoryOther = NSLocalizedString("ppro.feedback-form.category.something-else", value: "Something else", comment: "Description for the feedback form when the user has an issue not categorized in other options")

    static let vpnFeedbackFormTitle = NSLocalizedString("vpn.feedback-form.title", value: "Help Improve the DuckDuckGo VPN", comment: "Title for each screen of the VPN feedback form")

    static let vpnFeedbackFormCategorySelect = NSLocalizedString("vpn.feedback-form.category.select-category", value: "Select a category", comment: "Title for the category selection state of the VPN feedback form")

    static let vpnFeedbackFormCategoryUnableToInstall = NSLocalizedString("vpn.feedback-form.category.unable-to-install", value: "Unable to install VPN", comment: "Title for the 'unable to install' category of the VPN feedback form")

    static let vpnFeedbackFormCategoryFailsToConnect = NSLocalizedString("vpn.feedback-form.category.fails-to-connect", value: "VPN fails to connect", comment: "Title for the 'VPN fails to connect' category of the VPN feedback form")

    static let vpnFeedbackFormCategoryTooSlow = NSLocalizedString("vpn.feedback-form.category.too-slow", value: "VPN connection is too slow", comment: "Title for the 'VPN is too slow' category of the VPN feedback form")

    static let vpnFeedbackFormCategoryIssuesWithApps = NSLocalizedString("vpn.feedback-form.category.issues-with-apps", value: "VPN causes issues with other apps or websites", comment: "Title for the category 'VPN causes issues with other apps or websites' category of the VPN feedback form")

    static let vpnFeedbackFormCategoryLocalDeviceConnectivity = NSLocalizedString("vpn.feedback-form.category.local-device-connectivity", value: "VPN won't let me connect to local device", comment: "Title for the local device connectivity category of the VPN feedback form")

    static let vpnFeedbackFormCategoryBrowserCrashOrFreeze = NSLocalizedString("vpn.feedback-form.category.browser-crash-or-freeze", value: "VPN causes browser to crash or freeze", comment: "Title for the browser crash/freeze category of the VPN feedback form")

    static let vpnFeedbackFormCategoryFeatureRequest = NSLocalizedString("vpn.feedback-form.category.feature-request", value: "VPN feature request", comment: "Title for the 'VPN feature request' category of the VPN feedback form")

    static let vpnFeedbackFormCategoryOther = NSLocalizedString("vpn.feedback-form.category.other", value: "Other VPN feedback", comment: "Title for the 'other VPN feedback' category of the VPN feedback form")

    static let pirFeedbackFormCategorySelect = NSLocalizedString("pir.feedback-form.category.select-category", value: "Select a category", comment: "Title for the category selection state of the PIR feedback form")

    static let pirFeedbackFormCategoryNothingOnSpecificSite = NSLocalizedString("pir.feedback-form.category.no-info-on-specific-site", value: "The scan didn't find my info on a specific site", comment: "Description for the feedback form when the scan didn't find user's info on a specific site")

    static let pirFeedbackFormCategoryNotMe = NSLocalizedString("pir.feedback-form.category.not-me", value: "The scan found records which aren't me", comment: "Description for the feedback form when the scan found records that don’t belong to the user")

    static let pirFeedbackFormCategoryScanStuck = NSLocalizedString("pir.feedback-form.category.scan-stuck", value: "The scan for records is stuck", comment: "Description for the feedback form when the scan process is stuck")

    static let pirFeedbackFormCategoryRemovalStuck = NSLocalizedString("pir.feedback-form.category.removal-stuck", value: "The removal process is stuck", comment: "Description for the feedback form when the removal process is stuck")

    static let itrFeedbackFormCategorySelect = NSLocalizedString("itr.feedback-form.category.select-category", value: "Select a category", comment: "Title for the category selection state of the ITR feedback form")

    static let itrFeedbackFormCategoryAccessCode = NSLocalizedString("itr.feedback-form.category.access-code", value: "Issue with access code", comment: "Description for the feedback form when there is an issue with the access code")

    static let itrFeedbackFormCategoryCantContactAdvisor = NSLocalizedString("itr.feedback-form.category.contact-advisor", value: "Unable to contact advisor", comment: "Description for the feedback form when the user is unable to contact an advisor")

    static let itrFeedbackFormCategoryUnhelpful = NSLocalizedString("itr.feedback-form.category.unhelpful", value: "Call to Advisor was unhelpful", comment: "Description for the feedback form when the call to an advisor was unhelpful")

    static let itrFeedbackFormCategorySomethingElse = NSLocalizedString("itr.feedback-form.category.something-else", value: "Something else", comment: "Description for the feedback form when the user has an issue not categorized in other options")

    static let pproFeedbackFormText1 = NSLocalizedString("ppro.feedback-form.text-1", value: "Found an issue not covered in our [help center](duck://)? We definitely want to know about it.\n\nTell us what's going on:", comment: "Text for the body of the PPro feedback form")

    static let pproFeedbackFormText2 = NSLocalizedString("ppro.feedback-form.text-2", value: "In addition to the details entered into this form, your app issue report will contain:", comment: "Text for the body of the PPro feedback form")

    static let pproFeedbackFormText3 = NSLocalizedString("ppro.feedback-form.text-3", value: "• Whether specific DuckDuckGo features are enabled", comment: "Bullet text for the body of the PPro feedback form")

    static let pproFeedbackFormText4 = NSLocalizedString("ppro.feedback-form.text-4", value: "• Aggregate DuckDuckGo app diagnostics", comment: "Bullet text for the body of the PPro feedback form")

    static let pproFeedbackFormText5 = NSLocalizedString("ppro.feedback-form.text-5", value: "By clicking \"Submit\" I agree that DuckDuckGo may use the information in this report for purposes of improving the app's features.", comment: "Text for the body of the PPro feedback form")

    static let pproFeedbackFormDisclaimer = NSLocalizedString("ppro.feedback-form.disclaimer", value: "Reports are anonymous and sent to DuckDuckGo to help improve our service", comment: "Text for the disclaimer of the PPro feedback form")

    static let pproFeedbackFormEmailLabel = NSLocalizedString("ppro.feedback-form.email.label", value: "Provide an email if you’d like us to contact you about this issue (we may not be able to respond to all issues):", comment: "Label for the email field of the PPro feedback form")

    static let pproFeedbackFormEmailPlaceholder = NSLocalizedString("ppro.feedback-form.email.placeholder", value: "Email (optional)", comment: "Placeholder for the email field of the PPro feedback form")

    static let pproFeedbackFormSendingConfirmationTitle = NSLocalizedString("ppro.feedback-form.sending-confirmation.title", value: "Thank you!", comment: "Title for the feedback sent view title of the feedback form")

    static let pproFeedbackFormSendingConfirmationDescription = NSLocalizedString("ppro.feedback-form.sending-confirmation.description", value: "Your Feedback will help us improve Privacy Pro.", comment: "Title for the feedback sent view description of the feedback form")

    static let pproFeedbackFormSendingConfirmationError = NSLocalizedString("ppro.feedback-form.sending-confirmation.error", value: "We couldn't send your feedback right now, please try again.", comment: "Title for the feedback sending error text of the feedback form")

    static let pproFeedbackFormButtonDone = NSLocalizedString("ppro.feedback-form.button.done", value: "Done", comment: "Title for the Done button of the PPro feedback form")

    static let pproFeedbackFormButtonCancel = NSLocalizedString("ppro.feedback-form.button.cancel", value: "Cancel", comment: "Title for the Cancel button of the PPro feedback form")

    static let pproFeedbackFormButtonSubmit = NSLocalizedString("ppro.feedback-form.button.submit", value: "Submit", comment: "Title for the Submit button of the PPro feedback form")

    static let pproFeedbackFormButtonSubmitting = NSLocalizedString("ppro.feedback-form.button.submitting", value: "Submitting…", comment: "Title for the Submitting state of the PPro feedback form")

    static let pproFeedbackFormGeneralFeedbackPlaceholder = NSLocalizedString("ppro.feedback-form.general-feedback.placeholder", value: "Please give us your feedback:", comment: "Placeholder for the General Feedback step in the Privacy Pro feedback form")

    static let pproFeedbackFormRequestFeaturePlaceholder = NSLocalizedString("ppro.feedback-form.request-feature.placeholder", value: "What feature would you like to see?", comment: "Placeholder for the Feature Request step in the Privacy Pro feedback form")

    static let pirFeedbackFormCategoryOther = NSLocalizedString("pir.feedback-form.category.other", value: "Something else", comment: "Description for the feedback form when the user has an issue not categorized in other options")

    static let vpnFeedbackFormText1 = NSLocalizedString("vpn.feedback-form.text-1", value: "Please describe what's happening, what you expected to happen, and the steps that led to the issue:", comment: "Text for the body of the VPN feedback form")

    static let vpnFeedbackFormText2 = NSLocalizedString("vpn.feedback-form.text-2", value: "In addition to the details entered into this form, your app issue report will contain:", comment: "Text for the body of the VPN feedback form")

    static let vpnFeedbackFormText3 = NSLocalizedString("vpn.feedback-form.text-3", value: "• Whether specific DuckDuckGo features are enabled", comment: "Bullet text for the body of the VPN feedback form")

    static let vpnFeedbackFormText4 = NSLocalizedString("vpn.feedback-form.text-4", value: "• Aggregate DuckDuckGo app diagnostics", comment: "Bullet text for the body of the VPN feedback form")

    static let vpnFeedbackFormText5 = NSLocalizedString("vpn.feedback-form.text-5", value: "By clicking \"Submit\" I agree that DuckDuckGo may use the information in this report for purposes of improving the app's features.", comment: "Text for the body of the VPN feedback form")

    static let vpnFeedbackFormSendingConfirmationTitle = NSLocalizedString("vpn.feedback-form.sending-confirmation.title", value: "Thank you!", comment: "Title for the feedback sent view title of the VPN feedback form")

    static let vpnFeedbackFormSendingConfirmationDescription = NSLocalizedString("vpn.feedback-form.sending-confirmation.description", value: "Your feedback will help us improve the DuckDuckGo VPN.", comment: "Title for the feedback sent view description of the VPN feedback form")

    static let vpnFeedbackFormSendingConfirmationError = NSLocalizedString("vpn.feedback-form.sending-confirmation.error", value: "We couldn't send your feedback right now, please try again.", comment: "Title for the feedback sending error text of the VPN feedback form")

    static let vpnFeedbackFormButtonDone = NSLocalizedString("vpn.feedback-form.button.done", value: "Done", comment: "Title for the Done button of the VPN feedback form")

    static let vpnFeedbackFormButtonCancel = NSLocalizedString("vpn.feedback-form.button.cancel", value: "Cancel", comment: "Title for the Cancel button of the VPN feedback form")

    static let vpnFeedbackFormButtonSubmit = NSLocalizedString("vpn.feedback-form.button.submit", value: "Submit", comment: "Title for the Submit button of the VPN feedback form")

    static let vpnFeedbackFormButtonSubmitting = NSLocalizedString("vpn.feedback-form.button.submitting", value: "Submitting…", comment: "Title for the Submitting state of the VPN feedback form")

    // MARK: - Setting Titles

    static let vpnLocationTitle = NSLocalizedString("vpn.location.title", value: "Location", comment: "Location section title in VPN settings")

    static let vpnExclusionsTitle = NSLocalizedString("vpn.exclusions.title", value: "VPN Exclusions", comment: "Exclusions section title in VPN settings")

    static let vpnExcludedSitesTitle = NSLocalizedString("vpn.excluded.sites.title", value: "Excluded Websites", comment: "Excluded Sites title in VPN settings")

    static let vpnGeneralTitle = NSLocalizedString("vpn.general.title", value: "General", comment: "General section title in VPN settings")

    static let vpnShortcutsSettingsTitle = NSLocalizedString("vpn.shortcuts.settings.title", value: "Shortcuts", comment: "Shortcuts section title in VPN settings")

    static let vpnNotificationsSettingsTitle = NSLocalizedString("vpn.notifications.settings.title", value: "Notifications", comment: "Notifications section title in VPN settings")

    static let vpnAdvancedSettingsTitle = NSLocalizedString("vpn.advanced.settings.title", value: "Advanced", comment: "VPN Advanced section title in VPN settings")

    static let vpnNotificationsConnectionDropsOrStatusChangesTitle = NSLocalizedString("vpn.notifications.connection.drops.or.status.changes.title", value: "VPN connection drops or status changes", comment: "Title of the VPN notification option")

    // MARK: - Excluded Apps

    static let vpnExcludedAppsTitle = NSLocalizedString("vpn.excluded.apps.title", value: "Excluded Apps", comment: "Excluded Apps title in VPN settings")

    static let vpnExcludedAppsDescription = NSLocalizedString("vpn.excluded.apps.description", value: "Add apps that aren’t compatible with VPNs to use them without turning off the VPN.", comment: "Excluded Apps description in VPN settings")

    // MARK: - Location

    static let vpnLocationChangeButtonTitle = NSLocalizedString("vpn.location.change.button.title", value: "Change...", comment: "Title of the VPN location preference change button")

    static let vpnLocationListTitle = NSLocalizedString("vpn.location.list.title", value: "VPN Location", comment: "Title of the VPN location list screen")

    static let vpnLocationRecommendedSectionTitle = NSLocalizedString("vpn.location.recommended.section.title", value: "Recommended", comment: "Title of the VPN location list recommended section")

    static let vpnLocationCustomSectionTitle = NSLocalizedString("vpn.location.custom.section.title", value: "Custom", comment: "Title of the VPN location list custom section")

    static let vpnLocationSubmitButtonTitle = NSLocalizedString("vpn.location.submit.button.title", value: "Submit", comment: "Title of the VPN location list submit button")

    static let vpnLocationCancelButtonTitle = NSLocalizedString("vpn.location.custom.section.title", value: "Cancel", comment: "Title of the VPN location list cancel button (Note: seems like a duplicate key with a different purpose, please check)")

    static let vpnLocationNearest = NSLocalizedString("vpn.location.description.nearest", value: "Nearest", comment: "Nearest city setting description")

    static let vpnLocationNearestAvailable = NSLocalizedString("vpn.location.description.nearest.available", value: "Nearest Location", comment: "Nearest available location setting description")

    static let vpnLocationNearestAvailableSubtitle = NSLocalizedString("vpn.location.nearest.available.title", value: "Automatically connect to the nearest server we can find.", comment: "Subtitle underneath the nearest available vpn location preference text.")

    static func vpnLocationCountryItemFormattedCitiesCount(_ count: Int) -> String {
        let message = NSLocalizedString("network.protection.vpn.location.country.item.formatted.cities.count", value: "%d cities", comment: "Subtitle of countries item when there are multiple cities, example: '5 cities'")
        return String(format: message, count)
    }

    // MARK: - Exclusions

    static let vpnSettingsExclusionsDescription = NSLocalizedString("vpn.setting.exclusions.description", value: "Some websites and apps are not compatible with VPNs. Exclude these sites and apps to use them while connected to the VPN.", comment: "The description shown for the exclusions section in VPN settings")

    static let vpnSettingsManageExclusionsButtonTitle = NSLocalizedString("vpn.setting.exclusions.manage.button.title", value: "Manage...", comment: "Title for the button to manage exclusions")

    static let vpnNoExclusionsFoundText = NSLocalizedString("vpn.no.exclusions.found.text", value: "None", comment: "Text shown in VPN settings when no exclusions are configured")

    // MARK: - Excluded Apps

    static let vpnExcludedAppsAddApp = NSLocalizedString("vpn.excluded.apps.add.app", value: "Browse Applications", comment: "Add Application button for the excluded apps view")

    // MARK: - Excluded Domains

    static let vpnExcludedDomainsDescription = NSLocalizedString("vpn.setting.excluded.domains.description", value: "Excluded websites will bypass the VPN.", comment: "Excluded Sites description")

    static let vpnExcludedDomainsManageButtonTitle = NSLocalizedString("vpn.setting.excluded.domains.manage.button.title", value: "Manage Excluded Websites…", comment: "Excluded Sites management button title")

    static let vpnExcludedDomainsAddDomain = NSLocalizedString("vpn.excluded.domains.add.domain", value: "Add Website", comment: "Add Domain button for the excluded sites view")

    static let vpnExcludedDomainsTitle = NSLocalizedString("vpn.excluded.domains.title", value: "Excluded Websites", comment: "Title for the excluded sites view")

    // MARK: - Add Excluded Domain

    static let vpnAddExcludedDomainTitle = NSLocalizedString("vpn.setting.add.excluded.domain.title", value: "Exclude Website From VPN", comment: "Add excluded domain title")

    static let vpnAddExcludedDomainActionButtonTitle = NSLocalizedString("vpn.setting.add.excluded.domain.action.button.title", value: "Exclude Website", comment: "Add excluded domain button title")

    static let vpnAddExcludedDomainCancelButtonTitle = NSLocalizedString("vpn.setting.add.excluded.domain.cancel.button.title", value: "Cancel", comment: "Add excluded domain cancel button title")

    // MARK: - DNS

    static let vpnDnsServerTitle = NSLocalizedString("vpn.dns.server.title", value: "DNS Server", comment: "Title of the DNS Server section")

    static let vpnDnsServerPickerDefaultTitle = NSLocalizedString("vpn.dns.server.picker.default.title", value: "DuckDuckGo (Recommended)", comment: "Title of the default DNS server option")

    static let vpnDnsServerBlockRiskyDomainsToggleTitle = NSLocalizedString("vpn.dns.server.block.risky.domains.toggle.title", value: "Block risky domains", comment: "Name of option the user can opt in where the VPN blocks risky domains")

    static let vpnDnsServerBlockRiskyDomainsToggleFooter = NSLocalizedString("vpn.dns.server.block.risky.domains.toggle.footer", value: "Block 150,000+ domains flagged for hosting malware, phishing attacks, and online scams with a DNS-level blocklist.", comment: "Explanation in a footer of option the user can opt in where the VPN blocks risky domains")

    static let vpnDnsServerPickerCustomTitle = NSLocalizedString("vpn.dns.server.picker.custom.title", value: "Custom", comment: "Title of the custom DNS server option")

    static let vpnDnsServerPickerCustomButtonTitle = NSLocalizedString("vpn.dns.server.picker.custom.button.title", value: "Change…", comment: "Button title of the custom DNS server option")

    static let vpnSecureDNSSettingDescription = NSLocalizedString("vpn.setting.description.secure.dns", value: "DuckDuckGo routes DNS queries through our DNS servers so your internet provider can't see what websites you visit.", comment: "Secure DNS description")

    static let vpnDnsServerSheetTitle = NSLocalizedString("vpn.dns.server.sheet.title", value: "Custom DNS Server", comment: "Title of the DNS Server sheet")

    static let vpnDnsServerIPv4Description = NSLocalizedString("vpn.dns.server.ipv4.description", value: "IPv4 Address:", comment: "Description of the IPv4 text field")

    static let vpnDnsServerIPv4Disclaimer = NSLocalizedString("vpn.dns.server.disclaimer", value: "Using a custom DNS server can impact browsing speeds and expose your activity to third parties if the server isn't secure or reliable.", comment: "Disclaimer for the custom DNS server option")

    static let vpnDnsServerApplyButtonTitle = NSLocalizedString("vpn.dns.server.apply.button.title", value: "Apply", comment: "Title for the Apply custom DNS server button")

    // MARK: - Settings

    static let vpnConnectOnLoginSettingTitle = NSLocalizedString("vpn.setting.title.connect.on.login", value: "Connect to VPN when logging in to your computer", comment: "Connect on Login setting title")

    static let vpnShowInMenuBarSettingTitle = NSLocalizedString("vpn.setting.title.show.in.menu.bar", value: "Show VPN in menu bar", comment: "Display VPN status in the menu bar")

    static let vpnShowInBrowserToolbarSettingTitle = NSLocalizedString("vpn.setting.title.show.in.browser.toolbar", value: "Show VPN in browser toolbar", comment: "Display VPN status in the browser toolbar")

    static let vpnAlwaysOnSettingDescription = NSLocalizedString("vpn.setting.description.always.on", value: "Automatically restores the VPN connection after interruption. For your security, this setting cannot be disabled.", comment: "Always ON setting description")

    static let vpnExcludeLocalNetworksSettingTitle = NSLocalizedString("vpn.setting.title.exclude.local.networks", value: "Exclude local networks", comment: "Exclude Local Networks setting title")

    static let vpnExcludeLocalNetworksSettingDescription = NSLocalizedString("vpn.setting.description.exclude.local.networks", value: "Bypass the VPN for local network connections, like to a printer.", comment: "Exclude Local Networks setting description")

    static let openVPNButtonTitle = NSLocalizedString("vpn.button.title.open.vpn", value: "Open VPN…", comment: "Uninstall VPN button title")

    static let uninstallVPNButtonTitle = NSLocalizedString("vpn.button.title.uninstall.vpn", value: "Uninstall DuckDuckGo VPN…", comment: "Open VPN button title")

    // MARK: - VPN Settings Alerts

    static let uninstallVPNAlertTitle = NSLocalizedString("vpn.uninstall.alert.title", value: "Are you sure you want to uninstall the VPN?", comment: "Alert title when the user selects to uninstall our VPN")

    static let uninstallVPNInformativeText = NSLocalizedString("vpn.uninstall.alert.informative.text", value: "Uninstalling the DuckDuckGo VPN will disconnect the VPN and remove it from your device.", comment: "Informative text for the alert that comes up when the user decides to uninstall our VPN")
}
