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

final class UserText {

    // MARK: - Network Protection Notifications

    static let networkProtectionConnectionSuccessNotificationTitle = NSLocalizedString("network.protection.success.notification.title", value: "Network Protection is On", comment: "The title of the notification shown when Network Protection connects successfully")
    static let networkProtectionConnectionSuccessNotificationSubtitle = NSLocalizedString("network.protection.success.notification.subtitle", value: "Your location and online activity are protected.", comment: "The subtitle of the notification shown when Network Protection reconnects successfully")

    static let networkProtectionConnectionInterruptedNotificationTitle = NSLocalizedString("network.protection.interrupted.notification.title", value: "Network Protection was interrupted", comment: "The title of the notification shown when Network Protection's connection is interrupted")
    static let networkProtectionConnectionInterruptedNotificationSubtitle = NSLocalizedString("network.protection.interrupted.notification.subtitle", value: "Attempting to reconnect now...", comment: "The subtitle of the notification shown when Network Protection's connection is interrupted")

    static let networkProtectionConnectionFailureNotificationTitle = NSLocalizedString("network.protection.failure.notification.title", value: "Network Protection failed to connect", comment: "The title of the notification shown when Network Protection fails to reconnect")
    static let networkProtectionConnectionFailureNotificationSubtitle = NSLocalizedString("network.protection.failure.notification.subtitle", value: "Unable to connect at this time. Please try again later.", comment: "The subtitle of the notification shown when Network Protection fails to reconnect")

    static let networkProtectionSupersededNotificationTitle = NSLocalizedString("network.protection.superceded.notification.title", value: "Network Protection is disabled", comment: "The title of the notification shown when VPN connection is replaced by another app VPN connection taking over")
    static let networkProtectionSupersededNotificationSubtitle = NSLocalizedString("network.protection.superceded.notification.subtitle", value: "A VPN app on your device may have disabled it. Click to re-enable.", comment: "The subtitle of the notification shown when VPN connection is replaced by another app VPN connection taking over")
    static let networkProtectionSupersededReconnectActionTitle = NSLocalizedString("network.protection.superceded.action.reconnect.title", value: "Re-enable", comment: "The title of the `Reconnect` notification action button shown when VPN connection is replaced by another app VPN connection taking over")

}
