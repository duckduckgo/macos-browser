//
//  UserText.swift
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

final class UserText {
    static let networkProtectionStatusViewFeatureDesc = NSLocalizedString("network.protection.status.view.feature.description", value: "Hide your location from websites and conceal your online activity from Internet providers and others on your network.", comment: "Feature description shown in NetworkProtection's status view.")
    static let networkProtectionStatusViewConnDetails = NSLocalizedString("network.protection.status.view.connection.details", value: "Connection Details", comment: "Connection details label shown in NetworkProtection's status view.")
    static let networkProtectionStatusViewConnLabel = NSLocalizedString("network.protection.status.view.connection.label", value: "Network Protection", comment: "Connection label shown in NetworkProtection's status view.")
    static let networkProtectionStatusViewLocation = NSLocalizedString("network.protection.status.view.location", value: "Location", comment: "Location label shown in NetworkProtection's status view.")
    static let networkProtectionStatusViewIPAddress = NSLocalizedString("network.protection.status.view.ip.address", value: "IP Address", comment: "IP Address label shown in NetworkProtection's status view.")
    static let networkProtectionStatusViewFeatureOff = NSLocalizedString("network.protection.status.view.feature.on", value: "Network Protection is OFF", comment: "Text shown in NetworkProtection's status view when NetP is OFF.")
    static let networkProtectionStatusViewFeatureOn = NSLocalizedString("network.protection.status.view.feature.on", value: "Network Protection is ON", comment: "Text shown in NetworkProtection's status view when NetP is ON.")
    static let networkProtectionStatusViewTimerZero = "00:00:00"

    // MARK: - Connection Status

    static let networkProtectionStatusDisconnected = NSLocalizedString("network.protection.status.disconnected", value: "Disconnected", comment: "The label for the NetP VPN when disconnected")
    static let networkProtectionStatusDisconnecting = NSLocalizedString("network.protection.status.disconnecting", value: "Disconnecting...", comment: "The label for the NetP VPN when disconnecting")
    static let networkProtectionStatusConnected = NSLocalizedString("network.protection.status.connected", value: "Connected", comment: "The label for the NetP VPN when connected")
    static let networkProtectionStatusConnecting = NSLocalizedString("network.protection.status.connected", value: "Connecting...", comment: "The label for the NetP VPN when connecting")

    // MARK: - Connection Issues

    static let networkProtectionInterruptedReconnecting = NSLocalizedString("network.protection.interrupted.reconnecting", value: "Your Network Protection connection was interrupted. Attempting to reconnect now...", comment: "The warning message shown in NetP's status view when the connection is interrupted and its attempting to reconnect.")
    static let networkProtectionInterrupted = NSLocalizedString("network.protection.interrupted", value: "Network Protection was unable to connect at this time. Please try again later.", comment: "The warning message shown in NetP's status view when the connection is interrupted.")

    // MARK: - Connection Information

    static let networkProtectionServerAddressUnknown = NSLocalizedString("network.protection.server.address.unknown", value: "Unknown", comment: "When we can't tell the user the IP of the NetP server is")
    static let networkProtectionServerLocationUnknown = NSLocalizedString("network.protection.server.location.unknown", value: "Unknown", comment: "When we can't tell the user the location of the NetP server")
}
