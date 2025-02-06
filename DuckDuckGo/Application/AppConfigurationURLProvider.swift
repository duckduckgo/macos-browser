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

import Configuration
import Foundation
import BrowserServicesKit
import os.log

struct AppConfigurationURLProvider: ConfigurationURLProviding {

    // MARK: - Debug
    internal init(privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager,
                  featureFlagger: FeatureFlagger = Application.appDelegate.featureFlagger,
                  customPrivacyConfiguration: URL? = nil) {
        let trackerDataUrlProvider = TrackerDataURLOverrider(privacyConfigurationManager: privacyConfigurationManager, featureFlagger: featureFlagger)
        self.init(trackerDataUrlProvider: trackerDataUrlProvider)
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

    private var trackerDataUrlProvider: TrackerDataURLProviding

    public enum Constants {
        public static let baseTdsURLString = "https://staticcdn.duckduckgo.com/trackerblocking/"
        public static let defaultTrackerDataURL = URL(string: "https://staticcdn.duckduckgo.com/trackerblocking/v6/current/macos-tds.json")!
        public static let defaultPrivacyConfigurationURL = URL(string: "https://staticcdn.duckduckgo.com/trackerblocking/config/v4/macos-config.json")!
    }

    init(privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager,
         featureFlagger: FeatureFlagger = Application.appDelegate.featureFlagger) {
        self.trackerDataUrlProvider = TrackerDataURLOverrider(privacyConfigurationManager: privacyConfigurationManager, featureFlagger: featureFlagger)
    }

    init(trackerDataUrlProvider: TrackerDataURLProviding) {
        self.trackerDataUrlProvider = trackerDataUrlProvider
    }

    func url(for configuration: Configuration) -> URL {
        // URLs for privacyConfiguration and trackerDataSet shall match the ones in update_embedded.sh. 
        // Danger checks that the URLs match on every PR. If the code changes, the regex that Danger uses may need an update.
        switch configuration {
        case .bloomFilterBinary: return URL(string: "https://staticcdn.duckduckgo.com/https/https-mobile-v2-bloom.bin")!
        case .bloomFilterSpec: return URL(string: "https://staticcdn.duckduckgo.com/https/https-mobile-v2-bloom-spec.json")!
        case .bloomFilterExcludedDomains: return URL(string: "https://staticcdn.duckduckgo.com/https/https-mobile-v2-false-positives.json")!
        case .privacyConfiguration: return customPrivacyConfigurationUrl ?? Constants.defaultPrivacyConfigurationURL
        case .surrogates: return URL(string: "https://staticcdn.duckduckgo.com/surrogates.txt")!
        case .trackerDataSet:
            return trackerDataUrlProvider.trackerDataURL ?? Constants.defaultTrackerDataURL
        // In archived repo, to be refactored shortly (https://staticcdn.duckduckgo.com/useragents/social_ctp_configuration.json)
        case .remoteMessagingConfig: return RemoteMessagingClient.Constants.endpoint
        }
    }

}
