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
    // MARK: - VPN Status View submenu (legacy)

    static let networkProtectionStatusMenuVPNSettings = NSLocalizedString("network.protection.status.menu.vpn.settings", value: "VPN Settings…", comment: "The status menu 'VPN Settings' menu item")
    static let networkProtectionStatusMenuFAQ = NSLocalizedString("network.protection.status.menu.faq", value: "FAQs and Support…", comment: "The status menu 'FAQ' menu item")
    static let networkProtectionStatusMenuOpenDuckDuckGo = NSLocalizedString("network.protection.status.menu.vpn.open-duckduckgo", value: "Open DuckDuckGo…", comment: "The status menu 'Open DuckDuckGo' menu item")
    static let networkProtectionStatusMenuSendFeedback = NSLocalizedString("network.protection.status.menu.send.feedback", value: "Send Feedback…", comment: "The status menu 'Send Feedback' menu item")

    // MARK: - VPN Status View submenu

    static let vpnStatusViewVPNSettingsMenuItemTitle = NSLocalizedString(
        "vpn.status-view.vpn-settings.menu-item.title",
        value: "VPN Settings",
        comment: "The VPN status view's 'VPN Settings' menu item for our status menu app. The number shown is how many Apps are excluded.")

    static func vpnStatusViewExcludedAppsMenuItemTitle(_ count: Int) -> String {
        let message = NSLocalizedString(
            "vpn.status-view.excluded-apps.menu-item.title",
            value: "Excluded Apps (%d)",
            comment: "The VPN status view's 'Excluded Apps' menu item for our status menu app. The number shown is how many Apps are excluded.")

        return String(format: message, count)
    }

    static func vpnStatusViewExcludedDomainsMenuItemTitle(_ count: Int) -> String {
        let message = NSLocalizedString(
            "vpn.status-view.excluded-domains.menu-item.title",
            value: "Excluded Websites (%d)",
            comment: "The VPN status view's 'Excluded Websites' menu item for our status menu app. The number shown is how many websites are excluded.")

        return String(format: message, count)
    }

    static let vpnStatusViewFAQMenuItemTitle = NSLocalizedString(
        "vpn.status-view.faq.menu-item.title",
        value: "FAQs and Support",
        comment: "The VPN status view's 'FAQ' menu item for our status menu app")

    static let vpnStatusViewSendFeedbackMenuItemTitle = NSLocalizedString(
        "vpn.status-view.send-feedback.menu-item.title",
        value: "Send Feedback",
        comment: "The VPN status view's 'Send Feedback' menu item for our status menu app")
}
