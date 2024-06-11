//
//  VPNRedditSessionWorkaround.swift
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

import Foundation
import NetworkProtection
import NetworkProtectionIPC
import Subscription
import WebKit
import Common

final class VPNRedditSessionWorkaround {

    private let accountManager: AccountManaging
    private let ipcClient: TunnelControllerIPCClient
    private let statusReporter: NetworkProtectionStatusReporter

    init(accountManager: AccountManaging,
         ipcClient: TunnelControllerIPCClient,
         statusReporter: NetworkProtectionStatusReporter) {
        self.accountManager = accountManager
        self.ipcClient = ipcClient
        self.statusReporter = statusReporter
        self.statusReporter.forceRefresh()
    }

    @MainActor
    func installRedditSessionWorkaround() async {
        let configuration = WKWebViewConfiguration()
        await installRedditSessionWorkaround(to: configuration.websiteDataStore.httpCookieStore)
    }

    @MainActor
    func removeRedditSessionWorkaround() async {
        let configuration = WKWebViewConfiguration()
        await removeRedditSessionWorkaround(from: configuration.websiteDataStore.httpCookieStore)
    }

    @MainActor
    func installRedditSessionWorkaround(to cookieStore: WKHTTPCookieStore) async {
        guard accountManager.isUserAuthenticated,
              statusReporter.statusObserver.recentValue.isConnected,
            let redditSessionCookie = HTTPCookie.emptyRedditSession else {
            return
        }

        let cookies = await cookieStore.allCookies()
        var requiresRedditSessionCookie = true
        for cookie in cookies {
            if cookie.domain == redditSessionCookie.domain,
               cookie.name == redditSessionCookie.name {
                // Avoid adding the cookie if one already exists
                requiresRedditSessionCookie = false
                break
            }
        }

        if requiresRedditSessionCookie {
            os_log(.error, log: .networkProtection, "Installing VPN cookie workaround...")
            await cookieStore.setCookie(redditSessionCookie)
            os_log(.error, log: .networkProtection, "Installed VPN cookie workaround")
        }
    }

    func removeRedditSessionWorkaround(from cookieStore: WKHTTPCookieStore) async {
        guard let redditSessionCookie = HTTPCookie.emptyRedditSession else {
            return
        }

        let cookies = await cookieStore.allCookies()
        for cookie in cookies {
            if cookie.domain == redditSessionCookie.domain, cookie.name == redditSessionCookie.name {
                if cookie.value == redditSessionCookie.value {
                    os_log(.error, log: .networkProtection, "Removing VPN cookie workaround")
                    await cookieStore.deleteCookie(cookie)
                    os_log(.error, log: .networkProtection, "Removed VPN cookie workaround")
                }

                break
            }
        }
    }

}

private extension HTTPCookie {

    static var emptyRedditSession: HTTPCookie? {
        return HTTPCookie(properties: [
            .domain: ".reddit.com",
            .path: "/",
            .name: "reddit_session",
            .value: "",
            .secure: "TRUE"
        ])
    }

}

private extension ConnectionStatus {

    var isConnected: Bool {
        switch self {
        case .connected: return true
        default: return false
        }
    }

}
