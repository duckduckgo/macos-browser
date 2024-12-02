//
//  NetworkProtectionAssetTests.swift
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
import SwiftUI
import XCTest
@testable import NetworkProtectionUI

final class NetworkProtectionAssetTests: XCTestCase {

    /// This test validates that the asset names aren't changed by mistake, and that the assets
    /// exist in the bundle.
    ///
    func testAssetEnumValuesAreUnchanged() {
        let assetsAndExpectedRawValues: [NetworkProtectionAsset: String] = [
            .vpnDisabledImage: "VPNDisabled",
            .vpnEnabledImage: "VPN",
            .vpnIcon: "VPN-16",
            .nearestAvailable: "VPNLocation",
            .dataReceived: "VPNDownload",
            .dataSent: "VPNUpload",
            .appleVaultIcon: "apple-vault-icon",
            .appleVPNIcon: "apple-vpn-icon",
            .appleSystemSettingsIcon: "apple-system-settings-icon",
            .appleApplicationsIcon: "apple-applications-icon",
            .appVPNOnIcon: "app-vpn-on",
            .appVPNOffIcon: "app-vpn-off",
            .appVPNIssueIcon: "app-vpn-issue",
            .statusbarVPNOnIcon: "statusbar-vpn-on",
            .statusbarVPNOffIcon: "statusbar-vpn-off",
            .statusbarVPNIssueIcon: "statusbar-vpn-issue",
            .statusbarReviewVPNOnIcon: "statusbar-review-vpn-on",
            .statusbarDebugVPNOnIcon: "statusbar-debug-vpn-on",
            .statusbarBrandedVPNOffIcon: "statusbar-branded-vpn-off",
            .statusbarBrandedVPNIssueIcon: "statusbar-branded-vpn-issue",
            .enableSysexImage: "enable-sysex-bottom",
            .allowSysexScreenshot: "allow-sysex-screenshot",
            .allowSysexScreenshotBigSur: "allow-sysex-screenshot-bigsur",
            .accordionViewCheckmark: "Check-16D"
        ]

        XCTAssertEqual(assetsAndExpectedRawValues.count, NetworkProtectionAsset.allCases.count)

        for (asset, rawValue) in assetsAndExpectedRawValues {
            XCTAssertEqual(asset.rawValue, rawValue)
            XCTAssertNotNil(Image(rawValue, bundle: .module))
        }
    }
}
