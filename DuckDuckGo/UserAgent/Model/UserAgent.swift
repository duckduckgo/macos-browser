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

extension UserAgent {

    // MARK: - Fallback versions

    static let fallbackSafariVersion = "14.1.2"
    static let fallbackWebKitVersion = "605.1.15"
    static let fallbackWebViewDefault = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)"

    static let defaultPolicyConfigKey = "defaultPolicy"
    static let defaultSitesConfigKey = "defaultSites"
    static let ddgDefaultSitesConfigKey = "ddgDefaultSites"
    static let webviewDefaultKey = "webViewDefault"

    static let brandPolicy = "brand"

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

    static let ddgVersion: String = "Ddg/\(safariVersion)"

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
    static let brandedDefault = "\(Self.default) \(ddgVersion)"

    static let localUserAgentConfiguration: KeyValuePairs<RegEx, String> = [
        // use safari when serving up PDFs from duckduckgo directly
        regex("https://duckduckgo\\.com/[^?]*\\.pdf"): UserAgent.safari
    ]

    static func `for`(_ url: URL?,
                      privacyConfig: PrivacyConfiguration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig) -> String {
        guard let absoluteString = url?.absoluteString else {
            return Self.default
        }

        if let userAgent = localUserAgentConfiguration.first(where: { (regex, _) in absoluteString.matches(regex) })?.value {
            return userAgent
        }

        guard privacyConfig.isEnabled(featureKey: .customUserAgent) else { return Self.default }

        if isURLPartOfDDGDefaultSitesList(url: url, privacyConfig: privacyConfig) {
            return UserAgent.webViewDefault
        }
        if isURLPartOfWebviewDefaultList(url: url, privacyConfig: privacyConfig) {
            return UserAgent.webViewDefault
        }
        if isURLPartOfDefaultSitesList(url: url) {
            return Self.default
        }

        if isBrandPolicy(forConfig: privacyConfig) {
            return Self.brandedDefault
        } else {
            return Self.default
        }
    }

    // MARK: - Remote user agent configuration

    static let domainKey = "domain"

    private static func isURL(_ url: URL?, partOfDomainsList listKey: String, of privacyConfig: PrivacyConfiguration) -> Bool {
        let uaSettings = privacyConfig.settings(for: .customUserAgent)
        let domainsList = uaSettings[listKey] as? [[String: String]] ?? []
        let domains = domainsList.map { $0[domainKey] ?? "" }

        return domains.contains(where: { domain in
            url?.isPart(ofDomain: domain) ?? false
        })
    }

    private static func isURLPartOfWebviewDefaultList(url: URL?, privacyConfig: PrivacyConfiguration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig) -> Bool {
        isURL(url, partOfDomainsList: webviewDefaultKey, of: privacyConfig)
    }

    private static func isURLPartOfDefaultSitesList(url: URL?, privacyConfig: PrivacyConfiguration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig) -> Bool {
        isURL(url, partOfDomainsList: defaultSitesConfigKey, of: privacyConfig)
    }

    private static func isURLPartOfDDGDefaultSitesList(url: URL?, privacyConfig: PrivacyConfiguration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig) -> Bool {
        isURL(url, partOfDomainsList: ddgDefaultSitesConfigKey, of: privacyConfig)
    }

    private static func isBrandPolicy(forConfig config: PrivacyConfiguration) -> Bool {
        let uaSettings = config.settings(for: .customUserAgent)
        guard let policy = uaSettings[defaultPolicyConfigKey] as? String else { return false }
        return policy == brandPolicy
    }

}
