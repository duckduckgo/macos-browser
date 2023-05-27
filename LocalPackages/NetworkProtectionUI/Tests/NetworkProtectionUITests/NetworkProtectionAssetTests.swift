//
//  NetworkProtectionAssetsTests.swift
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
import XCTest
@testable import NetworkProtectionUI

final class NetworkProtectionAssetTests: XCTestCase {
    func testAssetEnumValuesAreUnchanged() {
        XCTAssertEqual(NetworkProtectionAsset.ipAddressIcon.rawValue, "IP-16")
        XCTAssertEqual(NetworkProtectionAsset.serverLocationIcon.rawValue, "Server-Location-16")
        XCTAssertEqual(NetworkProtectionAsset.vpnDisabledImage.rawValue, "VPN-Disabled-128")
        XCTAssertEqual(NetworkProtectionAsset.vpnEnabledImage.rawValue, "VPN-128")
        XCTAssertEqual(NetworkProtectionAsset.vpnIcon.rawValue, "VPN-16")
        XCTAssertEqual(NetworkProtectionAsset.appVPNOnIcon.rawValue, "app-vpn-on")
        XCTAssertEqual(NetworkProtectionAsset.appVPNOffIcon.rawValue, "app-vpn-off")
        XCTAssertEqual(NetworkProtectionAsset.appVPNIssueIcon.rawValue, "app-vpn-issue")
        XCTAssertEqual(NetworkProtectionAsset.statusbarVPNOnIcon.rawValue, "statusbar-vpn-on")
        XCTAssertEqual(NetworkProtectionAsset.statusbarVPNOffIcon.rawValue, "statusbar-vpn-off")
        XCTAssertEqual(NetworkProtectionAsset.statusbarVPNIssueIcon.rawValue, "statusbar-vpn-issue")
    }
}
