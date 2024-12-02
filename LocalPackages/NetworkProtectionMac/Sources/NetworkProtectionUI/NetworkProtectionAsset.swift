//
//  NetworkProtectionAsset.swift
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

public enum NetworkProtectionAsset: String, CaseIterable {
    case vpnDisabledImage = "VPNDisabled"
    case vpnEnabledImage = "VPN"
    case vpnIcon = "VPN-16"
    case nearestAvailable = "VPNLocation"
    case dataReceived = "VPNDownload"
    case dataSent = "VPNUpload"

    // Apple Icons
    case appleVaultIcon = "apple-vault-icon"
    case appleVPNIcon = "apple-vpn-icon"
    case appleSystemSettingsIcon = "apple-system-settings-icon"
    case appleApplicationsIcon = "apple-applications-icon"

    // App Specific
    case appVPNOnIcon = "app-vpn-on"
    case appVPNOffIcon = "app-vpn-off"
    case appVPNIssueIcon = "app-vpn-issue"

    // Status Bar Icons: Release builds
    case statusbarVPNOnIcon = "statusbar-vpn-on"
    case statusbarVPNOffIcon = "statusbar-vpn-off"
    case statusbarVPNIssueIcon = "statusbar-vpn-issue"

    // Status Bar Icons: Debug & Review builds
    case statusbarReviewVPNOnIcon = "statusbar-review-vpn-on"
    case statusbarDebugVPNOnIcon = "statusbar-debug-vpn-on"
    case statusbarBrandedVPNOffIcon = "statusbar-branded-vpn-off"
    case statusbarBrandedVPNIssueIcon = "statusbar-branded-vpn-issue"

    // Images
    case enableSysexImage = "enable-sysex-bottom"
    case allowSysexScreenshot = "allow-sysex-screenshot"
    case allowSysexScreenshotBigSur = "allow-sysex-screenshot-bigsur"

    // Accordion View
    case accordionViewCheckmark = "Check-16D"
}
