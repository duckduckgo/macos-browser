//
//  UserText.swift
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

import Foundation
import Subscription

enum UserText {
    // MARK: - Subscription preferences

    static let preferencesTitle = NSLocalizedString("subscription.preferences.title", value: "Privacy Pro", comment: "Title for the preferences pane for the subscription")

    static let vpnServiceTitle = NSLocalizedString("subscription.preferences.services.vpn.title", value: "VPN", comment: "Title for the VPN service listed in the subscription preferences pane")
    static let vpnServiceDescription = NSLocalizedString("subscription.preferences.services.vpn.description", value: "Full-device protection with the VPN built for speed and security.", comment: "Description for the VPN service listed in the subscription preferences pane")
    static let vpnServiceButtonTitle = NSLocalizedString("subscription.preferences.services.vpn.button.title", value: "Open", comment: "Title for the VPN service button to open its settings")

    static let personalInformationRemovalServiceTitle = NSLocalizedString("subscription.preferences.services.personal.information.removal.title", value: "Personal Information Removal", comment: "Title for the Personal Information Removal service listed in the subscription preferences pane")
    static let personalInformationRemovalServiceDescription = NSLocalizedString("subscription.preferences.services.personal.information.removal.description", value: "Find and remove your personal information from sites that store and sell it.", comment: "Description for the Personal Information Removal service listed in the subscription preferences pane")
    static let personalInformationRemovalServiceButtonTitle = NSLocalizedString("subscription.preferences.services.personal.information.removal.button.title", value: "Open", comment: "Title for the Personal Information Removal service button to open its settings")

    static let identityTheftRestorationServiceTitle = NSLocalizedString("subscription.preferences.services.identity.theft.restoration.title", value: "Identity Theft Restoration", comment: "Title for the Identity Theft Restoration service listed in the subscription preferences pane")
    static let identityTheftRestorationServiceDescription = NSLocalizedString("subscription.preferences.services.identity.theft.restoration.description", value: "Restore stolen accounts and financial losses in the event of identity theft.", comment: "Description for the Identity Theft Restoration service listed in the subscription preferences pane")
    static let identityTheftRestorationServiceButtonTitle = NSLocalizedString("subscription.preferences.services.identity.theft.restoration.button.title", value: "View", comment: "Title for the Identity Theft Restoration service button to open its settings")

    // MARK: Preferences footer
    static let preferencesSubscriptionFooterTitle = NSLocalizedString("subscription.preferences.subscription.footer.title", value: "Questions about Privacy Pro?", comment: "Title for the subscription preferences pane footer")
    static let preferencesSubscriptionFooterCaption = NSLocalizedString("subscription.preferences.subscription.footer.caption", value: "Get answers to frequently asked questions about Privacy Pro in our help pages.", comment: "Caption for the subscription preferences pane footer")
    static let viewFaqsButton = NSLocalizedString("subscription.preferences.view.faqs.button", value: "View FAQs", comment: "Button to open page for FAQs")

    // MARK: Preferences when subscription is active
    static let preferencesSubscriptionActiveHeader = NSLocalizedString("subscription.preferences.subscription.active.header", value: "Privacy Pro is active on this device", comment: "Header for the subscription preferences pane when the subscription is active")

    static func preferencesSubscriptionActiveRenewCaption(period: String, formattedDate: String) -> String {
        let localized = NSLocalizedString("subscription.preferences.subscription.active.renew.caption", value: "Your %@ Privacy Pro subscription renews on %@.", comment: "Caption for the subscription preferences pane when the subscription is active and will renew. First parameter is renewal period (monthly/yearly). Second parameter is date.")
        return String(format: localized, period, formattedDate)
    }

    static func preferencesSubscriptionActiveExpireCaption(period: String, formattedDate: String) -> String {
        let localized = NSLocalizedString("subscription.preferences.subscription.active.expire.caption", value: "Your %@ Privacy Pro subscription expires on %@.", comment: "Caption for the subscription preferences pane when the subscription is active but will expire. First parameter is renewal period (monthly/yearly). Second parameter is date.")
        return String(format: localized, period, formattedDate)
    }

    static func preferencesSubscriptionExpiredCaption(formattedDate: String) -> String {
        let localized = NSLocalizedString("subscription.preferences.subscription.expired.caption", value: "Your Privacy Pro subscription expired on %@.", comment: "Caption for the subscription preferences pane when the subscription has expired. The parameter is date of expiry.")
        return String(format: localized, formattedDate)
    }

    static let monthlySubscriptionBillingPeriod = NSLocalizedString("subscription.billing.period.monthly", value: "Monthly", comment: "Type of subscription billing period that lasts a month")
    static let yearlySubscriptionBillingPeriod = NSLocalizedString("subscription.billing.period.yearly", value: "Yearly", comment: "Type of subscription billing period that lasts a year")

    static let addToAnotherDeviceButton = NSLocalizedString("subscription.preferences.add.to.another.device.button", value: "Add to Another Device…", comment: "Button to add subscription to another device")
    static let manageSubscriptionButton = NSLocalizedString("subscription.preferences.manage.subscription.button", value: "Manage Subscription", comment: "Button to manage subscription")
    static let changePlanOrBillingButton = NSLocalizedString("subscription.preferences.change.plan.or.billing.button", value: "Change Plan or Billing…", comment: "Button to add subscription to another device")
    static let removeFromThisDeviceButton = NSLocalizedString("subscription.preferences.remove.from.this.device.button", value: "Remove From This Device…", comment: "Button to remove subscription from this device")

    // MARK: Preferences when subscription is inactive
    static let preferencesSubscriptionInactiveHeader = NSLocalizedString("subscription.preferences.subscription.inactive.header", value: "Subscribe to Privacy Pro", comment: "Header for the subscription preferences pane when the subscription is inactive")
    static let preferencesSubscriptionInactiveCaption = NSLocalizedString("subscription.preferences.subscription.inactive.caption", value: "More seamless privacy with three new protections.", comment: "Caption for the subscription preferences pane when the subscription is inactive")

    static let purchaseButton = NSLocalizedString("subscription.preferences.purchase.button", value: "Get Privacy Pro", comment: "Button to open a page where user can learn more and purchase the subscription")
    static let haveSubscriptionButton = NSLocalizedString("subscription.preferences.i.have.a.subscription.button", value: "I Have a Subscription", comment: "Button enabling user to activate a subscription user bought earlier or on another device")

    // MARK: Preferences when subscription activation is pending
    static let preferencesSubscriptionPendingHeader = NSLocalizedString("subscription.preferences.subscription.pending.header", value: "Your subscription is being activated", comment: "Header for the subscription preferences pane when the subscription activation is pending")
    static let preferencesSubscriptionPendingCaption = NSLocalizedString("subscription.preferences.subscription.pending.caption", value: "This is taking longer than usual, please check back later.", comment: "Caption for the subscription preferences pane when the subscription activation is pending")

    // MARK: Preferences when subscription is expired
    static let preferencesSubscriptionExpiredCaption = NSLocalizedString("subscription.preferences.subscription.expired.caption", value: "Subscribe again to continue using Privacy Pro.", comment: "Caption for the subscription preferences pane when the subscription activation is pending")

    static let manageDevicesButton = NSLocalizedString("subscription.preferences.manage.devices.button", value: "Manage Devices", comment: "Button to manage devices")

    // MARK: - Change plan or billing dialogs
    static let changeSubscriptionDialogTitle = NSLocalizedString("subscription.dialog.change.title", value: "Change Plan or Billing", comment: "Change plan or billing dialog title")
    static let changeSubscriptionGoogleDialogDescription = NSLocalizedString("subscription.dialog.change.google.description", value: "Your subscription was purchased through the Google Play Store. To change your plan or billing settings, please open Google Play Store subscription settings on a device signed in to the same Google Account used to purchase your subscription.", comment: "Change plan or billing dialog subtitle description for subscription purchased via Google")
    static let changeSubscriptionAppleDialogDescription = NSLocalizedString("subscription.dialog.change.apple.description", value: "Your subscription was purchased through the Apple App Store. To change your plan or billing settings, please go to Settings > Apple ID > Subscriptions on a device signed in to the same Apple ID used to purchase your subscription.", comment: "Change plan or billing dialog subtitle description for subscription purchased via Apple")
    static let changeSubscriptionDialogDone = NSLocalizedString("subscription.dialog.change.done.button", value: "Done", comment: "Button to close the change subscription dialog")

    // MARK: - Remove from this device dialog
    static let removeSubscriptionDialogTitle = NSLocalizedString("subscription.dialog.remove.title", value: "Remove from this device?", comment: "Remove subscription from device dialog title")
    static let removeSubscriptionDialogDescription = NSLocalizedString("subscription.dialog.remove.description", value: "You will no longer be able to access your Privacy Pro subscription on this device. This will not cancel your subscription, and it will remain active on your other devices.", comment: "Remove subscription from device dialog subtitle description")
    static let removeSubscriptionDialogCancel = NSLocalizedString("subscription.dialog.remove.cancel.button", value: "Cancel", comment: "Button to cancel removing subscription from device")
    static let removeSubscriptionDialogConfirm = NSLocalizedString("subscription.dialog.remove.confirm", value: "Remove Subscription", comment: "Button to confirm removing subscription from device")

    // MARK: - Services for accessing the subscription
    static let email = NSLocalizedString("subscription.access.channel.email.name", value: "Email", comment: "Service name displayed when accessing subscription using email address")

    // MARK: - Activate subscription modal
    static let activateModalTitle = NSLocalizedString("subscription.activate.modal.title", value: "Activate your subscription on this device", comment: "Activate subscription modal view title")
    static func activateModalDescription(platform: SubscriptionPurchaseEnvironment.Environment) -> String {
        switch platform {
        case .appStore:
            NSLocalizedString("subscription.appstore.activate.modal.description", value: "Access your Privacy Pro subscription on this device via Apple ID or an email address.", comment: "Activate subscription modal view subtitle description")
        case .stripe:
            NSLocalizedString("subscription.activate.modal.description", value: "Access your Privacy Pro subscription via an email address.", comment: "Activate subscription modal view subtitle description")
        }
    }

    static let activateModalEmailDescription = NSLocalizedString("subscription.activate.modal.email.description", value: "Use your email to activate your subscription on this device.", comment: "Activate subscription modal description for email address channel")
    static let restorePurchaseDescription = NSLocalizedString("subscription.activate.modal.restore.purchase.description", value: "Your subscription is automatically available in DuckDuckGo on any device signed in to your Apple ID.", comment: "Activate subscription modal description via restore purchase from Apple ID")

    // MARK: - Share subscription modal
    static let shareModalTitle = NSLocalizedString("subscription.share.modal.title", value: "Use your subscription on other devices", comment: "Share subscription modal view title")
    static func shareModalDescription(platform: SubscriptionPurchaseEnvironment.Environment) -> String {
        switch platform {
        case .appStore:
            NSLocalizedString("subscription.appstore.share.modal.description", value: "Access your subscription via Apple ID or by adding an email address.", comment: "Share subscription modal view subtitle description")
        case .stripe:
            NSLocalizedString("subscription.share.modal.description", value: "Activate your Privacy Pro subscription via an email address.", comment: "Share subscription modal view subtitle description")
        }
    }

    static let shareModalHasEmailDescription = NSLocalizedString("subscription.share.modal.has.email.description", value: "Use this email to activate your subscription on other devices. Open the DuckDuckGo app on another device and find Privacy Pro in browser settings.", comment: "Share subscription modal description for email address channel")
    static let shareModalNoEmailDescription = NSLocalizedString("subscription.share.modal.no.email.description", value: "Add an email address to access your subscription in DuckDuckGo on other devices. We’ll only use this address to verify your subscription.", comment: "Share subscription modal description for email address channel")

    static let restorePurchasesDescription = NSLocalizedString("subscription.share.modal.restore.purchases.description", value: "Your subscription is automatically available in DuckDuckGo on any device signed in to your Apple ID.", comment: "Share subscription modal description for restoring Apple ID purchases")

    // MARK: - Activate/share modal buttons
    static let restorePurchaseButton = NSLocalizedString("subscription.modal.restore.purchase.button", value: "Restore Purchase", comment: "Button for restoring past subscription purchase")
    static let manageEmailButton = NSLocalizedString("subscription.modal.manage.email.button", value: "Manage Email", comment: "Button for opening manage email address page")
    static let enterEmailButton = NSLocalizedString("subscription.modal.enter.email.button", value: "Enter Email", comment: "Button for opening page to enter email address")
    static let addEmailButton = NSLocalizedString("subscription.modal.add.email.button", value: "Add Email", comment: "Button for opening page to add email address")

    // MARK: - Alerts
    static let okButtonTitle = NSLocalizedString("subscription.alert.button.ok", value: "OK", comment: "Alert button for confirming it")
    static let cancelButtonTitle = NSLocalizedString("subscription.alert.button.cancel", value: "Cancel", comment: "Alert button for dismissing it")
    static let continueButtonTitle = NSLocalizedString("subscription.alert.button.retry", value: "Continue", comment: "Alert button for continue action")
    static let viewPlansButtonTitle = NSLocalizedString("subscription.alert.button.view.plans", value: "View Plans", comment: "Alert button for viewing subscription plans")
    static let restoreButtonTitle = NSLocalizedString("subscription.alert.button.restore", value: "Restore", comment: "Alert button for restoring past subscription purchases")

    static let somethingWentWrongAlertTitle = NSLocalizedString("subscription.alert.something.went.wrong.title", value: "Something Went Wrong", comment: "Alert title when unknown error has occurred")
    static let somethingWentWrongAlertDescription = NSLocalizedString("subscription.alert.something.went.wrong.description", value: "We’re having trouble connecting. Please try again later.", comment: "Alert message when unknown error has occurred")

    static let subscriptionNotFoundAlertTitle = NSLocalizedString("subscription.alert.subscription.not.found.title", value: "Subscription Not Found", comment: "Alert title when subscription was not found")
    static let subscriptionNotFoundAlertDescription = NSLocalizedString("subscription.alert.subscription.not.found.description", value: "We couldn’t find a subscription associated with this Apple ID.", comment: "Alert message when subscription was not found")

    static let subscriptionInactiveAlertTitle = NSLocalizedString("subscription.alert.subscription.inactive.title", value: "Subscription Not Found", comment: "Alert title when subscription was inactive")
    static let subscriptionInactiveAlertDescription = NSLocalizedString("subscription.alert.subscription.inactive.description", value: "The subscription associated with this Apple ID is no longer active.", comment: "Alert message when subscription was inactive")

    static let subscriptionFoundAlertTitle = NSLocalizedString("subscription.alert.subscription.found.title", value: "Subscription Found", comment: "Alert title when subscription was found")
    static let subscriptionFoundAlertDescription = NSLocalizedString("subscription.alert.subscription.found.description", value: "We found a subscription associated with this Apple ID.", comment: "Alert message when subscription was found")

    static let subscriptionAppleIDSyncFailedAlertTitle = NSLocalizedString("subscription.alert.subscription.apple-id.sync-failed.title", value: "Something Went Wrong When Syncing Your Apple ID", comment: "Alert message when the subscription failed to restore")
}
