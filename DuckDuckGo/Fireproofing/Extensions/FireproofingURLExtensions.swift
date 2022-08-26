//
//  FireproofingURLExtensions.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

private typealias URLPatterns = [String: [NSRegularExpression]]

extension URL {

    static let cookieDomain = "duckduckgo.com"

    private static let loginPattern = regex("login|sign-in|signin|session")

    private static let twoFactorAuthPatterns: URLPatterns = [
        "accounts.google.com": [regex("signin/v\\d.*/challenge")],
        "sso": [regex("duosecurity/getduo")],
        "amazon.com": [regex("ap/challenge"), regex("ap/cvf/approval")]
    ]

    private static let ssoPatterns: URLPatterns = [
        "sso": [regex("saml2/idp/SSOService")]
    ]

    private static let oAuthUrlPatterns: URLPatterns = [
        "accounts.google.com": [regex("o/oauth2/auth"), regex("o/oauth2/v\\d.*/auth")],
        "appleid.apple.com": [regex("auth/authorize")],
        "amazon.com": [regex("ap/oa")],
        "auth.atlassian.com": [regex("authorize")],
        "facebook.com": [regex("/v\\d.*/dialog/oauth"), regex("dialog/oauth")],
        "login.microsoftonline.com": [regex("common/oauth2/authorize"), regex("common/oauth2/v2.0/authorize")],
        "linkedin.com": [regex("oauth/v\\d.*/authorization")],
        "github.com": [regex("login/oauth/authorize")],
        "api.twitter.com": [regex("oauth/authenticate"), regex("oauth/authorize")],
        "duosecurity.com": [regex("oauth/v\\d.*/authorize"), regex("frame/prompt")]
    ]

    var isLoginURL: Bool {
        if isOAuthURL {
            return true
        }

        let range = NSRange(location: 0, length: absoluteString.utf16.count)
        let matches = Self.loginPattern.matches(in: self.absoluteString, options: [], range: range)
        return matches.count > 0
    }

    var isTwoFactorURL: Bool {
        matches(any: Self.twoFactorAuthPatterns)
    }

    var isSingleSignOnURL: Bool {
        matches(any: Self.ssoPatterns)
    }

    var isOAuthURL: Bool {
        matches(any: Self.oAuthUrlPatterns)
    }

    var canFireproof: Bool {
        guard let host = self.host else { return false }
        return (host != Self.cookieDomain)
    }

    var showFireproofStatus: Bool {
        guard let host = self.host else { return false }
        return canFireproof && FireproofDomains.shared.isFireproof(fireproofDomain: host)
    }

    private func matches(any patterns: URLPatterns) -> Bool {
        guard let host = self.host?.droppingWwwPrefix(),
              let matchingKey = patterns.keys.first(where: { host.contains($0) }),
              let pattern = patterns[matchingKey] else { return false }

        let range = NSRange(location: 0, length: absoluteString.utf16.count)

        return pattern.contains { regex in
            let matches = regex.matches(in: self.absoluteString, options: [], range: range)
            return !matches.isEmpty
        }
    }

}
