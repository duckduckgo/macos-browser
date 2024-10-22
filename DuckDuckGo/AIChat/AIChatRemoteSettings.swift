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
    private let privacyConfigurationManager: PrivacyConfigurationManaging
    private var settings: PrivacyConfigurationData.PrivacyFeature.FeatureSettings {
        privacyConfigurationManager.privacyConfig.settings(for: .aiChat)
    }

    init(privacyConfigurationManager: PrivacyConfigurationManaging = AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager) {
        self.privacyConfigurationManager = privacyConfigurationManager
    }

    var onboardingCookieName: String {
        if let cookieName = settings["onboardingCookieName"] as? String {
            return cookieName
        } else {
            // AICHAT-TODO: sendDebugPixel for no name in settings
            return "dcm"
        }
    }

    var onboardingCookieDomain: String {
        if let cookieDomain = settings["onboardingCookieDomain"] as? String {
            return cookieDomain
        } else {
            // AICHAT-TODO: sendDebugPixel for no domain in settings
            return "duckduckgo.com"
        }
    }

    var aiChatURL: URL {
        if let aiChatURLString = settings["aiChatURL"] as? String,
           let aiChatURL = URL(string: aiChatURLString) {
            return aiChatURL
        } else {
            let defaultURL = URL(string: "https://duck.ai")!
            // AICHAT-TODO: sendDebugPixel for no URL in settings
            return defaultURL
        }
    }

    var isAIChatEnabled: Bool {
        true
    }

    var isToolbarShortcutEnabled: Bool {
        true
    }

    var isApplicationMenuShortcutEnabled: Bool {
        true
    }
}
