//
//  UserText+NetworkProtection+Shared.swift
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

///
/// Copy related to VPN used by both main app targets and both VPN targets
///
extension UserText {

    // MARK: Location formatter

    static let locationFormatterNearestLocation = NSLocalizedString("network.protection.vpn.location.formatter.nearest.location", value: "Nearest Location", comment: "Nearest available location setting description")

    static let locationFormatterNearestLocationDescriptor = NSLocalizedString("network.protection.vpn.location.formatter.nearest.location.descriptor", value: "(Nearest)", comment: "Description added after the nearest location in the VPN status view")

    // "network.protection.vpn.location.subtitle.formatted.city.and.country" - Subtitle for the preferred location item that formats a city and country. E.g Chicago, United States
    static func locationFormatterLocationFormattedCityAndCountry(city: String, country: String) -> String {
        return "\(city), \(country)"
    }

    // MARK: -

    static let networkProtectionTunnelName = NSLocalizedString("network.protection.tunnel.name", value: "DuckDuckGo VPN", comment: "The name of the NetP VPN that will be visible in the system to the user")

    // MARK: - System Extension Installation Messages

    // Dynamically selected based on macOS version, not directly convertible to static string
    static var networkProtectionSystemSettings: String {
        if #available(macOS 13.0, *) {
            return networkProtectionSystemSettingsModern
        } else {
            return networkProtectionSystemSettingsLegacy
        }
    }

    private static let networkProtectionSystemSettingsLegacy = NSLocalizedString("network.protection.configuration.system-settings.legacy", value: "Go to Security & Privacy in System Preferences to allow DuckDuckGo VPN to activate", comment: "Text for a label in the VPN popover, displayed after attempting to enable the VPN for the first time while using macOS 12 and below")
    private static let networkProtectionSystemSettingsModern = NSLocalizedString("network.protection.configuration.system-settings.modern", value: "Go to Privacy & Security in System Settings to allow DuckDuckGo VPN to activate", comment: "Text for a label in the VPN popover, displayed after attempting to enable the VPN for the first time while using macOS 13 and above")

    static let networkProtectionUnknownActivationError = NSLocalizedString("network.protection.system.extension.unknown.activation.error", value: "There was an unexpected error. Please try again.", comment: "Message shown to users when they try to enable NetP and there is an unexpected activation error.")

    static let networkProtectionPleaseReboot = NSLocalizedString("network.protection.system.extension.please.reboot", value: "VPN update available. Restart your Mac to reconnect.", comment: "Message shown to users when they try to enable NetP and they need to reboot the computer to complete the installation")
}
