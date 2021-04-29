//
//  EmailUrlExtensions.swift
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

extension EmailUrls {

    private struct Url {
        static let emailLandingPage = "https://quack.duckduckgo.com/email-protection"
        static let emailDashboardPage = "https://quack.duckduckgo.com/email/dashboard"
        static let emailGenerateTokenPage = "https://quack.duckduckgo.com/email/new-address"
        static let emailAuthenticationHosts = ["quack.duckduckgo.com", "quackdev.duckduckgo.com"]
    }

    var emailLandingPage: URL {
        return URL(string: Url.emailLandingPage)!
    }

    var emailDashboardPage: URL {
        return URL(string: Url.emailDashboardPage)!
    }

    func shouldAuthenticateWithEmailCredentials(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return Url.emailAuthenticationHosts.contains(host)
    }

}

extension EmailManager {

    private struct Url {
        static let emailGenerateTokenPage = "https://quack.duckduckgo.com/email/new-address"
    }

    private func emailGenerateTokenPage(with token: String) -> URL {
        var urlComponents = URLComponents(string: Url.emailGenerateTokenPage)!
        urlComponents.queryItems = [URLQueryItem(name: "t", value: token)]
        return urlComponents.url!
    }

    public var generateTokenPageURL: URL? {
        guard let token = EmailKeychainManager().getToken() else { return nil }
        return emailGenerateTokenPage(with: token)
    }

}
