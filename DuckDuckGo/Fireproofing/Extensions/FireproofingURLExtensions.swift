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
import Common

private typealias URLPatterns = [String: [NSRegularExpression]]

extension URL {

    static let duckduckgoDomain = "duckduckgo.com"

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

    var canFireproof: Bool {
        guard let host = self.host, self.navigationalScheme?.isHypertextScheme == true else { return false }
        return (host != Self.duckduckgoDomain)
    }

    var showFireproofStatus: Bool {
        guard let host = self.host else { return false }
        return canFireproof && FireproofDomains.shared.isFireproof(fireproofDomain: host)
    }

}
