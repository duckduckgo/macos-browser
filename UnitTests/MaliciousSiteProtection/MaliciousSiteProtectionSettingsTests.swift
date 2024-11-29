//
//  MaliciousSiteProtectionSettingsTests.swift
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

import XCTest
import Combine
import BrowserServicesKit

@testable import DuckDuckGo_Privacy_Browser

private struct MockConfig: Encodable {
    var hashPrefixUpdateFrequency: Int? = 21
    var filterSetUpdateFrequency: Int? = 722
}
extension MockConfig? {

    private var maliciousSiteProtectionSettingsJson: String {
        self.map {
            """
            "maliciousSiteProtection": {
                "state": "enabled",
                "exceptions": [],
                "features": {},
                "settings": \(try! JSONEncoder().encode($0).utf8String()!),
                "hash": "9a9143022e6cc8976461b337abfa81a1"
            }
            """
        } ?? ""
    }

    var data: Data {
        """
        {
            "readme": "https://github.com/duckduckgo/privacy-configuration",
            "version": 1722602607085,
            "features": {
                \(maliciousSiteProtectionSettingsJson)
            }
        }
        """.utf8data
    }
}

class MaliciousSiteProtectionSettingsTests: XCTestCase {

    private func setupSettings(with config: MockConfig?) -> MaliciousSiteProtectionRemoteSettings {
        let embeddedDataProvider = MockEmbeddedDataProvider()
        embeddedDataProvider.embeddedDataEtag = "12345"
        embeddedDataProvider.embeddedData = config.data

        let manager = PrivacyConfigurationManager(fetchedETag: nil,
                                                  fetchedData: nil,
                                                  embeddedDataProvider: embeddedDataProvider,
                                                  localProtection: MockDomainsProtectionStore(),
                                                  internalUserDecider: DefaultInternalUserDecider())
        return MaliciousSiteProtectionRemoteSettings(privacyConfigurationManager: manager)
    }

    func testWhenValidRemoteSettings_settingsValuesReturned() {
        let config = MockConfig()
        let settings = setupSettings(with: config)
        XCTAssertEqual(settings[.hashPrefixUpdateFrequencyMinutes], TimeInterval(config.hashPrefixUpdateFrequency!))
        XCTAssertEqual(settings[.filterSetUpdateFrequencyMinutes], TimeInterval(config.filterSetUpdateFrequency!))
    }

    func testWhenPartlyValidRemoteSettings_defaultValuesReturnedForMissingKeys() {
        let config = MockConfig(hashPrefixUpdateFrequency: nil)
        let settings = setupSettings(with: config)
        XCTAssertEqual(settings[.hashPrefixUpdateFrequencyMinutes], TimeInterval(MaliciousSiteProtectionRemoteSettings.Key.hashPrefixUpdateFrequencyMinutes.defaultValue))
        XCTAssertEqual(settings[.filterSetUpdateFrequencyMinutes], TimeInterval(config.filterSetUpdateFrequency!))
    }

    func testInvalidRemoteSettings_defaultValuesReturned() {
        let settings = setupSettings(with: nil)
        XCTAssertEqual(settings[.hashPrefixUpdateFrequencyMinutes], TimeInterval(MaliciousSiteProtectionRemoteSettings.Key.hashPrefixUpdateFrequencyMinutes.defaultValue))
        XCTAssertGreaterThan(settings[.hashPrefixUpdateFrequencyMinutes], 0)
        XCTAssertEqual(settings[.filterSetUpdateFrequencyMinutes], TimeInterval(MaliciousSiteProtectionRemoteSettings.Key.filterSetUpdateFrequencyMinutes.defaultValue))
        XCTAssertGreaterThan(settings[.filterSetUpdateFrequencyMinutes], 0)
    }

}
