//
//  NetworkProtectionUNNotificationsPresenter.swift
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

import AppLauncher
import Foundation
import UserNotifications
import NetworkProtection
import NetworkProtectionUI
import VPNAppLauncher

extension UNNotificationAction {

    enum Identifier: String {
        case reconnect = "action.reconnect"
    }

    /// "Reconnect" notification action button
    static let reconnectAction = UNNotificationAction(identifier: Identifier.reconnect.rawValue,
                                                      title: UserText.networkProtectionSupersededReconnectActionTitle,
                                                      options: [.authenticationRequired])

}

extension UNNotificationCategory {

    /// Actions for `superseded` (by another app) notification category
    static let superseded = UNNotificationCategory(identifier: "supersededActionCategory",
                                                   actions: [.reconnectAction],
                                                   intentIdentifiers: [],
                                                   options: [])

}

/// This class takes care of requesting the presentation of notifications using UNNotificationCenter
///
final class NetworkProtectionUNNotificationsPresenter: NSObject, NetworkProtectionNotificationsPresenter {

    private static let threadIdentifier = "com.duckduckgo.NetworkProtectionNotificationsManager.threadIdentifier"

    private let appLauncher: AppLauncher
    private let userNotificationCenter: UNUserNotificationCenter

    init(appLauncher: AppLauncher, userNotificationCenter: UNUserNotificationCenter = .current()) {
        self.appLauncher = appLauncher
        self.userNotificationCenter = userNotificationCenter

        super.init()
    }

    // MARK: - Setup

    func requestAuthorization() {
        userNotificationCenter.delegate = self
        requestAlertAuthorization()
    }

    private lazy var registerNotificationCategoriesOnce: Void = {
        userNotificationCenter.setNotificationCategories([.superseded])
    }()

    // MARK: - Notification Utility methods

    private func requestAlertAuthorization(completionHandler: ((Bool) -> Void)? = nil) {
        let options: UNAuthorizationOptions = .alert

        userNotificationCenter.requestAuthorization(options: options) { authorized, _ in
            completionHandler?(authorized)
        }
    }

    private func notificationContent(title: String, subtitle: String, category: UNNotificationCategory? = nil) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.threadIdentifier = Self.threadIdentifier
        content.title = title
        content.subtitle = subtitle
        if let category {
            content.categoryIdentifier = category.identifier
            // take maximum possible number of lines so the button doesn‘t overlap the text
            content.subtitle += "\n\n\n"
        }

        if #available(macOS 12, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 0
        }

        return content
    }

    // MARK: - Presenting user notifications

    func showConnectedNotification(serverLocation: String?, snoozeEnded: Bool) {
        // Should include the serverLocation in the subtitle, but due to a bug with the current server in the PacketTunnelProvider
        // this is not currently working on macOS. Add the necessary copy as on iOS when this is fixed.
        let subtitle: String
        if let serverLocation {
            subtitle = UserText.networkProtectionConnectionSuccessNotificationSubtitle(serverLocation: serverLocation)
        } else {
            subtitle = UserText.networkProtectionConnectionSuccessNotificationSubtitle
        }
        let content = notificationContent(title: UserText.networkProtectionConnectionSuccessNotificationTitle,
                                          subtitle: subtitle)
        showNotification(.connected, content)
    }

    func showReconnectingNotification() {
        let content = notificationContent(title: UserText.networkProtectionConnectionInterruptedNotificationTitle,
                                          subtitle: UserText.networkProtectionConnectionInterruptedNotificationSubtitle)
        showNotification(.reconnecting, content)
    }

    func showConnectionFailureNotification() {
        let content = notificationContent(title: UserText.networkProtectionConnectionFailureNotificationTitle,
                                          subtitle: UserText.networkProtectionConnectionFailureNotificationSubtitle)
        showNotification(.disconnected, content)
    }

    func showSupersededNotification() {
        let content = notificationContent(title: UserText.networkProtectionSupersededNotificationTitle,
                                          subtitle: UserText.networkProtectionSupersededNotificationSubtitle,
                                          category: .superseded)
        showNotification(.superseded, content)
    }

    func showEntitlementNotification() {
        let content = notificationContent(title: UserText.networkProtectionEntitlementExpiredNotificationTitle,
                                          subtitle: UserText.networkProtectionEntitlementExpiredNotificationBody)
        showNotification(.expiredEntitlement, content)
    }

    func showSnoozingNotification(duration: TimeInterval) {
        assertionFailure("macOS does not support VPN snooze")
    }

    func showTestNotification() {
        // These strings are deliberately hardcoded as we don't want them localized, they're only for debugging:
        let content = notificationContent(title: "Test notification",
                                          subtitle: "Test notification")
        showNotification(.test, content)
    }

    private func showNotification(_ identifier: NetworkProtectionNotificationIdentifier, _ content: UNNotificationContent) {
        let request = UNNotificationRequest(identifier: identifier.rawValue, content: content, trigger: .none)

        requestAlertAuthorization { authorized in
            guard authorized else {
                return
            }

            _=self.registerNotificationCategoriesOnce
            self.userNotificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier.rawValue])
            self.userNotificationCenter.add(request)
        }
    }

}

public enum NetworkProtectionNotificationIdentifier: String {
    case disconnected = "network-protection.notification.disconnected"
    case reconnecting = "network-protection.notification.reconnecting"
    case connected = "network-protection.notification.connected"
    case superseded = "network-protection.notification.superseded"
    case expiredEntitlement = "network-protection.notification.expired-entitlement"
    case test = "network-protection.notification.test"
}

extension NetworkProtectionUNNotificationsPresenter: UNUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return .banner
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {

        try? await appLauncher.launchApp(withCommand: VPNAppLaunchCommand.showStatus)
    }

}
