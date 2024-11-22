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
    static let webViewDefault = ""
    static let brandedDefault = "\(Self.safari) \(ddgVersion)"
    static let `default` = UserAgent.brandedDefault

    static func `for`(_ url: URL?,
                      privacyConfig: PrivacyConfiguration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig) -> String {
        guard let url, privacyConfig.isEnabled(featureKey: .customUserAgent) else {
            return Self.default
        }

        if isURLPartOfWebviewDefaultList(url: url, privacyConfig: privacyConfig) {
            return Self.webViewDefault
        }
        if isURLPartOfDefaultSitesList(url: url, privacyConfig: privacyConfig) {
            return Self.safari
        }

        return Self.default
    }

    // MARK: - Remote user agent configuration

    static let defaultSitesKey = "defaultSites"
    static let webviewDefaultKey = "webViewDefault"
    static let domainKey = "domain"

    private static func isURLPartOfWebviewDefaultList(url: URL,
                                                      privacyConfig: PrivacyConfiguration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig) -> Bool {
        let settings = privacyConfig.settings(for: .customUserAgent)
        let webViewDefaultList = settings[webviewDefaultKey] as? [[String: String]] ?? []
        let domains = webViewDefaultList.map { $0[domainKey] ?? "" }

        return domains.contains(where: { domain in
            url.isPart(ofDomain: domain)
        })
    }

    private static func isURLPartOfDefaultSitesList(url: URL, privacyConfig: PrivacyConfiguration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig) -> Bool {

        let uaSettings = privacyConfig.settings(for: .customUserAgent)
        let defaultSitesObjs = uaSettings[defaultSitesKey] as? [[String: String]] ?? []
        let domains = defaultSitesObjs.map { $0[domainKey] ?? "" }

        return domains.contains(where: { domain in
            url.isPart(ofDomain: domain)
        })
    }
}
