//
//  UserAgent.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import BrowserServicesKit
import Common

enum UserAgent {

    // MARK: - Fallback versions

    static let fallbackSafariVersion = "14.1.2"
    static let fallbackWebKitVersion = "605.1.15"
    static let fallbackWebViewDefault = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)"

    // MARK: - Loaded versions

    static let safariVersion: String = {
        guard let version = SafariVersionReader.getVersion() else {
            assertionFailure("Couldn't get version of Safari")
            return fallbackSafariVersion
        }
        return version
    }()

    static let webKitVersion: String = {
        guard let version = WebKitVersionProvider.getVersion() else {
            assertionFailure("Couldn't get version of WebKit")
            return fallbackWebKitVersion
        }
        return version
    }()

    // MARK: - User Agents

    static let safari = "Mozilla/5.0 " +
        "(Macintosh; Intel Mac OS X 10_15_7) " +
        "AppleWebKit/\(webKitVersion) (KHTML, like Gecko) " +
        "Version/\(safariVersion) " +
        "Safari/\(webKitVersion)"
    static let chrome = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
        "AppleWebKit/537.36 (KHTML, like Gecko) " +
        "Chrome/91.0.4472.101 " +
        "Safari/537.36"
    static let `default` = UserAgent.safari
    static let webViewDefault = ""

    static let localUserAgentConfiguration: KeyValuePairs<RegEx, String> = [
        // Use safari agent or else nginx gets a truncated user agent and ends it ends up blank
        regex("https://duckduckgo\\.com/.*"): UserAgent.safari
    ]

    static func duckDuckGoUserAgent(appVersion: String = AppVersion.shared.versionNumber,
                                    appID: String = AppVersion.shared.identifier,
                                    systemVersion: String = ProcessInfo.processInfo.operatingSystemVersionString) -> String {
        return "ddg_mac/\(appVersion) (\(appID); macOS \(systemVersion))"
    }

    static func `for`(_ url: URL?,
                      privacyConfig: PrivacyConfiguration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig) -> String {
        guard let absoluteString = url?.absoluteString else {
            return Self.default
        }

        // 1) Apply remote user agent configuration
        if privacyConfig.isEnabled(featureKey: .customUserAgent) &&
            isURLPartOfWebviewDefaultList(url: url, privacyConfig: privacyConfig) {
            return UserAgent.webViewDefault
        }

        // 2) Apply local user agent configuration
        if let userAgent = localUserAgentConfiguration.first(where: { (regex, _) in absoluteString.matches(regex) })?.value {
            return userAgent
        }

        return Self.default
    }

    // MARK: - Remote user agent configuration

    static let webviewDefaultKey = "webViewDefault"
    static let domainKey = "domain"

    static func isURLPartOfWebviewDefaultList(url: URL?,
                                              privacyConfig: PrivacyConfiguration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig) -> Bool {
        let settings = privacyConfig.settings(for: .customUserAgent)
        let webViewDefaultList = settings[webviewDefaultKey] as? [[String: String]] ?? []
        let domains = webViewDefaultList.map { $0[domainKey] ?? "" }

        return domains.contains(where: { domain in
            url?.isPart(ofDomain: domain) ?? false
        })
    }

}
