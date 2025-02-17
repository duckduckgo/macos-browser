//
//  VPNPreferencesModelTests.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

import XCTest
import NetworkProtection
import NetworkProtectionIPC
import NetworkProtectionProxy
@testable import DuckDuckGo_Privacy_Browser
import Combine

final class VPNPreferencesModelTests: XCTestCase {

    var model: VPNPreferencesModel!
    let userDefaults = UserDefaults(suiteName: "\(Bundle.main.bundleIdentifier!).\(NSApplication.runType)")!
    var vpnSettings: VPNSettings!
    var xpsClient: VPNControllerXPCClient!
    var proxySettings: TransparentProxySettings!

    override func setUpWithError() throws {
        vpnSettings = VPNSettings(defaults: userDefaults)
        xpsClient = VPNControllerXPCClient()
        proxySettings = TransparentProxySettings(defaults: userDefaults)
        model = VPNPreferencesModel(vpnXPCClient: xpsClient, settings: vpnSettings, proxySettings: proxySettings, pinningManager: MockPinningManager(), defaults: userDefaults, featureFlagger: MockFeatureFlagger())
    }

    override func tearDownWithError() throws {
        vpnSettings = nil
        xpsClient = nil
        proxySettings = nil
        model = nil
    }

    func test_WhenUpdateDNSSettingsToCustomThenPropagatesToVpnSettings() {
        // WHEN
        model.isCustomDNSSelected = true
        model.customDNSServers = "1.1.1.1"

        // THEN
        switch vpnSettings.dnsSettings {
        case .custom(let servers):
            XCTAssertEqual(servers, ["1.1.1.1"], "Custom DNS servers should be updated correctly.")
        default:
            XCTFail("Expected dnsSettings to be .custom, but got \(vpnSettings.dnsSettings)")
        }
    }

    func test_WhenUpdateDNSSettingsToDefaultWithThenPropagatesToVpnSettings() {
        // WHEN
        model.isCustomDNSSelected = false
        model.isBlockRiskyDomainsOn = true

        // THEN
        switch vpnSettings.dnsSettings {
        case .ddg(let blockRiskyDomains):
            XCTAssertTrue(blockRiskyDomains, "Expected blockRiskyDomains to be false.")
        default:
            XCTFail("Expected dnsSettings to be .ddg, but got \(vpnSettings.dnsSettings)")
        }
    }

    func test_WhenUpdateDNSSettingsToDefaultWithBlockOffThenPropagatesToVpnSettings() {
        // WHEN
        model.isCustomDNSSelected = false
        model.isBlockRiskyDomainsOn = false

        // THEN
        switch vpnSettings.dnsSettings {
        case .ddg(let blockRiskyDomains):
            XCTAssertFalse(blockRiskyDomains, "Expected blockRiskyDomains to be false.")
        default:
            XCTFail("Expected dnsSettings to be .ddg, but got \(vpnSettings.dnsSettings)")
        }
    }

    func test_WhenMovingFromDefaultToCustomAndBackToDefaultThenBlockSettingRetainedToFalse() {
        // GIVEN
        model.isCustomDNSSelected = false
        model.isBlockRiskyDomainsOn = false

        // WHEN
        model.isCustomDNSSelected = true
        model.customDNSServers = "1.1.1.1"
        model.isCustomDNSSelected = false

        // THEN
        switch vpnSettings.dnsSettings {
        case .ddg(let blockRiskyDomains):
            XCTAssertFalse(blockRiskyDomains, "Expected blockRiskyDomains to be false.")
        default:
            XCTFail("Expected dnsSettings to be .ddg, but got \(vpnSettings.dnsSettings)")
        }
    }

    func test_WhenMovingFromDefaultToCustomAndBackToDefaultThenBlockSettingRetainedToTrue() {
        // GIVEN
        model.isCustomDNSSelected = false
        model.isBlockRiskyDomainsOn = true

        // WHEN
        model.isCustomDNSSelected = true
        model.customDNSServers = "1.1.1.1"
        model.isCustomDNSSelected = false

        // THEN
        switch vpnSettings.dnsSettings {
        case .ddg(let blockRiskyDomains):
            XCTAssertTrue(blockRiskyDomains, "Expected blockRiskyDomains to be true.")
        default:
            XCTFail("Expected dnsSettings to be .ddg, but got \(vpnSettings.dnsSettings)")
        }
    }

    func test_WhenMovingFromCustomToDefaultAndBackToCustomThenPreviouslySelectedServerRetained() {
        // GIVEN
        model.isCustomDNSSelected = true
        model.customDNSServers = "1.1.1.1"

        // WHEN
        model.isCustomDNSSelected = false
        model.isCustomDNSSelected = true

        // THEN
        switch vpnSettings.dnsSettings {
        case .custom(let servers):
            XCTAssertEqual(servers, ["1.1.1.1"], "Custom DNS servers should be updated correctly.")
        default:
            XCTFail("Expected dnsSettings to be .custom, but got \(vpnSettings.dnsSettings)")
        }
    }

    func testWhenUpdateDNSSettingsToCustomAndNoServerProvidedPreviousDnsSettingApplies() {
        // GIVEN
        model.isCustomDNSSelected = false
        let previousDNS = vpnSettings.dnsSettings

        // WHEN
        model.customDNSServers = nil
        model.isCustomDNSSelected = true

        // THEN
        XCTAssertEqual(vpnSettings.dnsSettings, previousDNS, "DNS settings should remain unchanged when no custom DNS is provided.")
    }

}

final class MockPinningManager: PinningManager {
    func togglePinning(for view: PinnableView) {
    }

    func isPinned(_ view: PinnableView) -> Bool {
        return false
    }

    func wasManuallyToggled(_ view: DuckDuckGo_Privacy_Browser.PinnableView) -> Bool {
        return false
    }

    func pin(_ view: PinnableView) {
    }

    func unpin(_ view: PinnableView) {
    }

    func shortcutTitle(for view: PinnableView) -> String {
        return ""
    }
}
