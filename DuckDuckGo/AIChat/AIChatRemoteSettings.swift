//
//  AIChatRemoteSettings.swift
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

import BrowserServicesKit
import PixelKit

protocol AIChatRemoteSettingsProvider {
    var onboardingCookieName: String { get }
    var onboardingCookieDomain: String { get }
    var aiChatURLIdentifiableQuery: String { get }
    var aiChatURLIdentifiableQueryValue: String { get }
    var aiChatURL: URL { get }
    var isAIChatEnabled: Bool { get }
    var isToolbarShortcutEnabled: Bool { get }
    var isApplicationMenuShortcutEnabled: Bool { get }
}

/// This struct serves as a wrapper for PrivacyConfigurationManaging, enabling the retrieval of data relevant to AIChat.
/// It also fire pixels when necessary data is missing.
struct AIChatRemoteSettings: AIChatRemoteSettingsProvider {
    enum SettingsValue: String {
        case cookieName = "onboardingCookieName"
        case cookieDomain = "onboardingCookieDomain"
        case aiChatURL = "aiChatURL"
        case aiChatURLIdentifiableQuery = "aiChatURLIdentifiableQuery"
        case aiChatURLIdentifiableQueryValue = "aiChatURLIdentifiableQueryValue"

        var defaultValue: String {
            switch self {
            case .cookieName: return "dcm"
            case .cookieDomain: return "duckduckgo.com"
            case .aiChatURL: return "https://duck.ai"
            case .aiChatURLIdentifiableQuery: return "ia"
            case .aiChatURLIdentifiableQueryValue: return "chat"
            }
        }
    }

    private let privacyConfigurationManager: PrivacyConfigurationManaging
    private var settings: PrivacyConfigurationData.PrivacyFeature.FeatureSettings {
        privacyConfigurationManager.privacyConfig.settings(for: .aiChat)
    }

    init(privacyConfigurationManager: PrivacyConfigurationManaging = AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager) {
        self.privacyConfigurationManager = privacyConfigurationManager
    }

    // MARK: - Public

    var onboardingCookieName: String { getSettingsData(.cookieName) }
    var onboardingCookieDomain: String { getSettingsData(.cookieDomain) }
    var aiChatURLIdentifiableQuery: String { getSettingsData(.aiChatURLIdentifiableQuery) }
    var aiChatURLIdentifiableQueryValue: String { getSettingsData(.aiChatURLIdentifiableQueryValue) }

    var aiChatURL: URL {
        guard let url = URL(string: getSettingsData(.aiChatURL)) else {
            return URL(string: SettingsValue.aiChatURL.defaultValue)!
        }
        return url
    }

    var isAIChatEnabled: Bool {
        privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .aiChat)
    }

    var isToolbarShortcutEnabled: Bool {
        privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(AIChatSubfeature.toolbarShortcut)
    }

    var isApplicationMenuShortcutEnabled: Bool {
        privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(AIChatSubfeature.applicationMenuShortcut)
    }

    // MARK: - Private

    private func getSettingsData(_ value: SettingsValue) -> String {
        if let value = settings[value.rawValue] as? String {
            return value
        } else {
            PixelKit.fire(GeneralPixel.aichatNoRemoteSettingsFound(value), includeAppVersionParameter: true)
            return value.defaultValue
        }
    }
}
