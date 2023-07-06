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

final class AppConfigurationURLProvider: ConfigurationURLProviding {

    func url(for configuration: Configuration) -> URL {
        if let overriddenURL = overrides[configuration] {
            return overriddenURL
        }
        return urls[configuration]!
    }

    func setURL(_ url: URL?, for configuration: Configuration) {
        if let url {
            overrides[configuration] = url
        } else {
            overrides.removeValue(forKey: configuration)
        }
    }

    private var overrides: [Configuration: URL] = [:]

    private let urls: [Configuration: URL] = [
        .bloomFilterBinary: URL(string: "https://staticcdn.duckduckgo.com/https/https-mobile-v2-bloom.bin")!,
        .bloomFilterSpec: URL(string: "https://staticcdn.duckduckgo.com/https/https-mobile-v2-bloom-spec.json")!,
        .bloomFilterExcludedDomains: URL(string: "https://staticcdn.duckduckgo.com/https/https-mobile-v2-false-positives.json")!,
        .privacyConfiguration: URL(string: "https://staticcdn.duckduckgo.com/trackerblocking/config/v3/macos-config.json")!,
        .surrogates: URL(string: "https://duckduckgo.com/contentblocking.js?l=surrogates")!,
        .trackerDataSet: URL(string: "https://staticcdn.duckduckgo.com/trackerblocking/v5/current/macos-tds.json")!,
        // In archived repo, to be refactored shortly (https://staticcdn.duckduckgo.com/useragents/social_ctp_configuration.json)
        .FBConfig: return URL(string: "https://staticcdn.duckduckgo.com/useragents/")!
    ]
}
