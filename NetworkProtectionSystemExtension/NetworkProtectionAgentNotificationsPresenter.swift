//
//  NetworkProtectionAgentNotificationsPresenter.swift
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
import NetworkProtection

/// Notifications presenter for the system extension.  This really just asks for the running agent to present a notification using
/// the established IPC connection.
///
final class NetworkProtectionAgentNotificationsPresenter: NetworkProtectionNotificationsPresenter {

    private let notificationCenter: NetworkProtectionNotificationCenter

    init(notificationCenter: NetworkProtectionNotificationCenter) {
        self.notificationCenter = notificationCenter
    }

    // MARK: - Presenting user notifications

    func showConnectedNotification(serverLocation: String?, snoozeEnded: Bool) {
        notificationCenter.post(.showConnectedNotification, object: serverLocation)
    }

    func showReconnectingNotification() {
        notificationCenter.post(.showIssuesStartedNotification)
    }

    func showConnectionFailureNotification() {
        notificationCenter.post(.showIssuesNotResolvedNotification)
    }

    func showSupersededNotification() {
        notificationCenter.post(.showVPNSupersededNotification)
    }

    func showEntitlementNotification() {
        notificationCenter.post(.showExpiredEntitlementNotification)
    }

    func showTestNotification() {
        notificationCenter.post(.showTestNotification)
    }

    func showSnoozingNotification(duration: TimeInterval) {
        assertionFailure("macOS does not support VPN snooze")
    }

}
