//
//  UserText+DBP.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Common

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

// MARK: - DBP Error pages
extension UserText {
    static let dbpErrorPageBadPathTitle = NotLocalizedString("dbp.errorpage.bad.path.title", value: "Move DuckDuckGo App to Applications", comment: "Title for Personal Information Removal bad path error screen")
    static let dbpErrorPageBadPathMessage = NotLocalizedString("dbp.errorpage.bad.path.message", value: "To use Personal Information Removal, the DuckDuckGo app needs to be in the Applications folder on your Mac. You can move the app yourself and restart the browser, or we can do it for you.", comment: "Message for Personal Information Removal bad path error screen")
    static let dbpErrorPageBadPathCTA = NotLocalizedString("dbp.errorpage.bad.path.cta", value: "Move App for Me...", comment: "Call to action for moving the app to the Applications folder")

    static let dbpErrorPageNoPermissionTitle = NotLocalizedString("dbp.errorpage.no.permission.title", value: "Change System Setting", comment: "Title for error screen when there is no permission")
    static let dbpErrorPageNoPermissionMessage = NotLocalizedString("dbp.errorpage.no.permission.message", value: "Open System Settings and allow DuckDuckGo Personal Information Removal to run in the background.", comment: "Message for error screen when there is no permission")
    static let dbpErrorPageNoPermissionCTA = NotLocalizedString("dbp.errorpage.no.permission.cta", value: "Open System Settings...", comment: "Call to action for opening system settings")
}

#endif
