//
//  AIChatRemoteSettingsTests.swift
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

class AIChatRemoteSettingsTests: XCTestCase {
    var mockPrivacyConfigurationManager: MockPrivacyConfigurationManager!
    var aiChatRemoteSettings: AIChatRemoteSettings!

    private func setupAIChatRemoteSettings(with config: MockConfig) -> AIChatRemoteSettings {
        let embeddedDataProvider = MockEmbeddedDataProvider()
        embeddedDataProvider.embeddedDataEtag = "12345"
        embeddedDataProvider.embeddedData = config.embeddedData

        let manager = PrivacyConfigurationManager(fetchedETag: nil,
                                                  fetchedData: nil,
                                                  embeddedDataProvider: embeddedDataProvider,
                                                  localProtection: MockDomainsProtectionStore(),
                                                  internalUserDecider: DefaultInternalUserDecider())
        return AIChatRemoteSettings(privacyConfigurationManager: manager)
    }

    func testValidRemoteURL_ThenConfigUsesRemoteURL() {
        var config = MockConfig()
        config.embeddedData = config.configWithSettings
        aiChatRemoteSettings = setupAIChatRemoteSettings(with: config)
        XCTAssertEqual(config.aiChatURL, aiChatRemoteSettings.aiChatURL.absoluteString)
    }

    func testInvalidRemoteURL_ThenConfigUsesDefaultURL() {
        var config = MockConfig()
        config.embeddedData = config.configWithoutSettings
        aiChatRemoteSettings = setupAIChatRemoteSettings(with: config)
        XCTAssertEqual(AIChatRemoteSettings.SettingsValue.aiChatURL.defaultValue, aiChatRemoteSettings.aiChatURL.absoluteString)
    }

    func testOnboardingCookieName_WhenSettingExists_ThenReturnsCorrectValue() {
        var config = MockConfig()
        config.embeddedData = config.configWithSettings
        aiChatRemoteSettings = setupAIChatRemoteSettings(with: config)
        XCTAssertEqual(config.cookieName, aiChatRemoteSettings.onboardingCookieName)
    }

    func testOnboardingCookieDomain_WhenSettingExists_ThenReturnsCorrectValue() {
        var config = MockConfig()
        config.embeddedData = config.configWithSettings
        aiChatRemoteSettings = setupAIChatRemoteSettings(with: config)
        XCTAssertEqual(config.cookieDomain, aiChatRemoteSettings.onboardingCookieDomain)
    }

    func testAIChatURLIdentifiableQuery_WhenSettingExists_ThenReturnsCorrectValue() {
        var config = MockConfig()
        config.embeddedData = config.configWithSettings
        aiChatRemoteSettings = setupAIChatRemoteSettings(with: config)
        XCTAssertEqual(config.aiChatURLIdentifiableQuery, aiChatRemoteSettings.aiChatURLIdentifiableQuery)
    }

    func testAIChatURLIdentifiableQueryValue_WhenSettingExists_ThenReturnsCorrectValue() {
        var config = MockConfig()
        config.embeddedData = config.configWithSettings
        aiChatRemoteSettings = setupAIChatRemoteSettings(with: config)
        XCTAssertEqual(config.aiChatURLIdentifiableQueryValue, aiChatRemoteSettings.aiChatURLIdentifiableQueryValue)
    }

    func testOnboardingCookieName_WhenSettingDoesNotExist_ThenReturnsDefaultValue() {
        var config = MockConfig()
        config.embeddedData = config.configWithoutSettings
        aiChatRemoteSettings = setupAIChatRemoteSettings(with: config)
        XCTAssertEqual(AIChatRemoteSettings.SettingsValue.cookieName.defaultValue, aiChatRemoteSettings.onboardingCookieName)
    }

    func testIsAIChatEnabled_WhenFeatureIsEnabled_ThenReturnsTrue() {
        var config = MockConfig()
        config.embeddedData = config.configWithSettings
        aiChatRemoteSettings = setupAIChatRemoteSettings(with: config)
        XCTAssertTrue(aiChatRemoteSettings.isAIChatEnabled)
    }

    func testIsAIChatEnabled_WhenFeatureIsDisabled_ThenReturnsFalse() {
        var config = MockConfig()
        config.featureStatus = "disabled"
        config.embeddedData = config.configWithSettings
        aiChatRemoteSettings = setupAIChatRemoteSettings(with: config)
        XCTAssertFalse(aiChatRemoteSettings.isAIChatEnabled)
    }

    func testIsToolbarShortcutEnabled_WhenShortcutIsEnabled_ThenReturnsTrue() {
        var config = MockConfig()
        config.embeddedData = config.configWithSettings
        aiChatRemoteSettings = setupAIChatRemoteSettings(with: config)
        XCTAssertTrue(aiChatRemoteSettings.isToolbarShortcutEnabled)
    }

    func testIsToolbarShortcutEnabled_WhenShortcutIsDisabled_ThenReturnsFalse() {
        var config = MockConfig()
        config.toolbarShortcutStatus = "disabled"
        config.embeddedData = config.configWithSettings
        aiChatRemoteSettings = setupAIChatRemoteSettings(with: config)
        XCTAssertFalse(aiChatRemoteSettings.isToolbarShortcutEnabled)
    }

    func testIsApplicationMenuShortcutEnabled_WhenShortcutIsEnabled_ThenReturnsTrue() {
        var config = MockConfig()
        config.embeddedData = config.configWithSettings
        aiChatRemoteSettings = setupAIChatRemoteSettings(with: config)
        XCTAssertTrue(aiChatRemoteSettings.isApplicationMenuShortcutEnabled)
    }

    func testIsApplicationMenuShortcutEnabled_WhenShortcutIsDisabled_ThenReturnsFalse() {
        var config = MockConfig()
        config.applicationMenuShortcutStatus = "disabled"
        config.embeddedData = config.configWithSettings
        aiChatRemoteSettings = setupAIChatRemoteSettings(with: config)
        XCTAssertFalse(aiChatRemoteSettings.isApplicationMenuShortcutEnabled)
    }
}

private struct MockConfig {
    var featureStatus = "enabled"
    var toolbarShortcutStatus = "enabled"
    var applicationMenuShortcutStatus = "enabled"
    var aiChatURL = "https://potato.com"
    var cookieName = "test0"
    var cookieDomain = "duck.com"
    var aiChatURLIdentifiableQuery = "test1"
    var aiChatURLIdentifiableQueryValue = "test2"

    var embeddedData = Data()

    var configWithSettings: Data {
        let jsonString =
        """
        {
            "readme": "https://github.com/duckduckgo/privacy-configuration",
            "version": 1722602607085,
            "features": {
                "aiChat": {
                    "state": "\(featureStatus)",
                    "exceptions": [],
                    "features": {
                        "toolbarShortcut": {
                            "state": "\(toolbarShortcutStatus)"
                        },
                        "applicationMenuShortcut": {
                            "state": "\(applicationMenuShortcutStatus)"
                        }
                    },
                    "settings": {
                        "aiChatURL": "\(aiChatURL)",
                        "onboardingCookieName": "\(cookieName)",
                        "onboardingCookieDomain": "\(cookieDomain)",
                        "aiChatURLIdentifiableQuery": "\(aiChatURLIdentifiableQuery)",
                        "aiChatURLIdentifiableQueryValue": "\(aiChatURLIdentifiableQueryValue)"
                    },
                    "hash": "64a9f318c4cfd9fc702e641d2a69347b"
                }
            }
        }
        """
        return jsonString.data(using: .utf8)!
    }

    var configWithoutSettings: Data {
        let jsonString =
        """
        {
            "readme": "https://github.com/duckduckgo/privacy-configuration",
            "version": 1722602607085,
            "features": {
                "aiChat": {
                    "state": "\(featureStatus)",
                    "exceptions": [],
                    "features": {
                        "toolbarShortcut": {
                            "state": "\(toolbarShortcutStatus)"
                        },
                        "applicationMenuShortcut": {
                            "state": "\(applicationMenuShortcutStatus)"
                        }
                    },
                    "settings": {
                    },
                    "hash": "64a9f318c4cfd9fc702e641d2a69347b"
                }
            }
        }
        """
        return jsonString.data(using: .utf8)!
    }
}
