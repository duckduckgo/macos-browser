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

/// This struct serves as a wrapper for PrivacyConfigurationManaging, enabling the retrieval of data relevant to AIChat.
/// It also fire pixels when necessary data is missing.
struct AIChatRemoteSettings {
    enum SettingsValue: String {
        case cookieName
        case cookieDomain
        case aiChatURL
        case aiChatURLIdentifiableQuery
        case aiChatURLIdentifiableQueryValue

        var settingsKey: String {
            switch self {
            case .cookieName: "onboardingCookieName"
            case .cookieDomain: "onboardingCookieDomain"
            case .aiChatURL: "aiChatURL"
            case .aiChatURLIdentifiableQuery: "aiChatURLIdentifiableQuery"
            case .aiChatURLIdentifiableQueryValue: "aiChatURLIdentifiableQueryValue"
            }
        }

        var defaultValue: String {
            switch self {
            case .cookieName: "dcm"
            case .cookieDomain: "duckduckgo.com"
            case .aiChatURL: "https://duck.ai"
            case .aiChatURLIdentifiableQuery: "ia"
            case .aiChatURLIdentifiableQueryValue: "chat"
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

    var onboardingCookieName: String {
        getSettingsData(.cookieName)
    }

    var onboardingCookieDomain: String {
        getSettingsData(.cookieDomain)
    }

    var aiChatURLIdentifiableQuery: String {
        getSettingsData(.aiChatURLIdentifiableQuery)
    }

    var aiChatURLIdentifiableQueryValue: String {
        getSettingsData(.aiChatURLIdentifiableQueryValue)
    }

    var aiChatURL: URL {
        let urlString = getSettingsData(.aiChatURL)
        if let url = URL(string: urlString) {
            return url
        } else {
            return URL(string: SettingsValue.aiChatURL.defaultValue)!
        }
    }

    private func getSettingsData(_ value: SettingsValue) -> String {
        if let value = settings[value.settingsKey] as? String {
            return value
        } else {
            //fire pixel value.rawValue
            return value.defaultValue
        }
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
}
