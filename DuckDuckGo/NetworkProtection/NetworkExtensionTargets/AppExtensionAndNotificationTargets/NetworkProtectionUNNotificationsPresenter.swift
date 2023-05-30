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

import Foundation
import UserNotifications
import NetworkProtection

extension UNNotificationAction {

    enum Identifier: String {
        case reconnect = "action.reconnect"
    }

    /// "Reconnect" notification action button
    static let reconnectAction = UNNotificationAction(identifier: Identifier.reconnect.rawValue,
                                                      title: UserText.networkProtectionSupercededReconnectActionTitle,
                                                      options: [.authenticationRequired])

}

extension UNNotificationCategory {

    /// Actions for `superceded` (by another app) notification category
    static let superceded = UNNotificationCategory(identifier: "supercededActionCategory",
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
        userNotificationCenter.setNotificationCategories([.superceded])
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

    func showReconnectedNotification() {
        let content = notificationContent(title: UserText.networkProtectionConnectionSuccessNotificationTitle,
                                          subtitle: UserText.networkProtectionConnectionSuccessNotificationSubtitle)
        showNotification(content)
    }

    func showReconnectingNotification() {
        let content = notificationContent(title: UserText.networkProtectionConnectionInterruptedNotificationTitle,
                                          subtitle: UserText.networkProtectionConnectionInterruptedNotificationSubtitle)
        showNotification(content)
    }

    func showConnectionFailureNotification() {
        let content = notificationContent(title: UserText.networkProtectionConnectionFailureNotificationTitle,
                                          subtitle: UserText.networkProtectionConnectionFailureNotificationSubtitle)
        showNotification(content)
    }

    func showSupercededNotification() {
        let content = notificationContent(title: UserText.networkProtectioSupercededNotificationTitle,
                                          subtitle: UserText.networkProtectionSupercededNotificationSubtitle,
                                          category: .superceded)
        showNotification(content)
    }

    private func showNotification(_ content: UNNotificationContent) {
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: .none)

        requestAlertAuthorization { authorized in
            guard authorized else {
                return
            }

            _=self.registerNotificationCategoriesOnce
            self.userNotificationCenter.add(request)
        }
    }

}

extension NetworkProtectionUNNotificationsPresenter: UNUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {

        if #available(macOS 11, *) {
            return .banner
        } else {
            return .alert
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        switch UNNotificationAction.Identifier(rawValue: response.actionIdentifier) {
        case .reconnect:
            await appLauncher.launchApp(withCommand: .startVPN)

        case .none:
            await appLauncher.launchApp(withCommand: .showStatus)
        }
    }

}
