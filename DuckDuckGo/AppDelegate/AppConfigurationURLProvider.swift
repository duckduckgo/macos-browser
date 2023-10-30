//
//  AppConfigurationURLProvider.swift
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
import Configuration

struct AppConfigurationURLProvider: ConfigurationURLProviding {

    // MARK: - Debug

    internal init(customPrivacyConfiguration: URL? = nil) {
        if let customPrivacyConfiguration {
            // Overwrite custom privacy configuration if provided
            self.customPrivacyConfiguration = customPrivacyConfiguration.absoluteString
        }
        // Otherwise use the default or already stored custom configuration
    }

    @UserDefaultsWrapper(key: .customConfigurationUrl, defaultValue: nil)
    private var customPrivacyConfiguration: String?

    private var customPrivacyConfigurationUrl: URL? {
        if let customPrivacyConfiguration {
            return URL(string: customPrivacyConfiguration)
        }
        return nil
    }

    mutating func resetToDefaultConfigurationUrl() {
        self.customPrivacyConfiguration = nil
    }

    // MARK: - Main

    func url(for configuration: Configuration) -> URL {
        // URLs for privacyConfiguration and trackerDataSet shall match the ones in update_embedded.sh. 
        // Danger checks that the URLs match on every PR. If the code changes, the regex that Danger uses may need an update.
        switch configuration {
        case .bloomFilterBinary: return URL(string: "https://staticcdn.duckduckgo.com/https/https-mobile-v2-bloom.bin")!
        case .bloomFilterSpec: return URL(string: "https://staticcdn.duckduckgo.com/https/https-mobile-v2-bloom-spec.json")!
        case .bloomFilterExcludedDomains: return URL(string: "https://staticcdn.duckduckgo.com/https/https-mobile-v2-false-positives.json")!
        case .privacyConfiguration: return customPrivacyConfigurationUrl ?? URL(string: "https://staticcdn.duckduckgo.com/trackerblocking/config/v3/macos-config.json")!
        case .surrogates: return URL(string: "https://staticcdn.duckduckgo.com/surrogates.txt")!
        case .trackerDataSet: return URL(string: "https://staticcdn.duckduckgo.com/trackerblocking/v5/current/macos-tds.json")!
        // In archived repo, to be refactored shortly (https://staticcdn.duckduckgo.com/useragents/social_ctp_configuration.json)
        case .FBConfig: return URL(string: "https://staticcdn.duckduckgo.com/useragents/")!
        }
    }

}
